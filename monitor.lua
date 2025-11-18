-- ===================================
-- NUZLOCKE TRACKER - MONITORING SCRIPT (DMA-Safe)
-- ===================================

function xor32(a, b)
    local result = 0
    local bit_val = 1
    for i = 0, 31 do
        local a_bit = math.floor(a / bit_val) % 2
        local b_bit = math.floor(b / bit_val) % 2
        if a_bit ~= b_bit then result = result + bit_val end
        bit_val = bit_val * 2
    end
    return result
end

-- Constants
YOUR_TRAINER_ID = 28810  -- Your specific Trainer ID
BOX_BASE = 0x0202884C    -- PC boxes seem more stable

-- Find party location dynamically
function find_party_base()
    -- Search memory for Trainer ID in party range
    for addr = 0x02024000, 0x02025FFF, 4 do
        local value = emu:read16(addr)
        if value == YOUR_TRAINER_ID then
            -- Check if this looks like party data (has valid HP/level nearby)
            local potential_base = addr - 4
            local hp = emu:read16(potential_base + 86)
            local level = emu:read8(potential_base + 84)
            
            -- Valid party Pokemon should have reasonable HP (1-999) and level (1-100)
            if hp > 0 and hp < 1000 and level > 0 and level <= 100 then
                return potential_base
            end
        end
    end
    return nil
end

-- Read a single Pokemon
function read_pokemon(addr, is_party)
    local pid = emu:read32(addr)
    if pid == 0 then return nil end
    
    local otid = emu:read32(addr + 4)
    local key = xor32(pid, otid)
    local chunk0 = emu:read32(addr + 32)
    local decrypted = xor32(chunk0, key)
    local species = decrypted % 65536
    
    local pokemon = {
        pid = pid,
        species = species
    }
    
    if is_party then
        pokemon.level = emu:read8(addr + 84)
        pokemon.hp = emu:read16(addr + 86)
        pokemon.max_hp = emu:read16(addr + 88)
        pokemon.status = emu:read32(addr + 80)
    end
    
    return pokemon
end

-- Read entire party (dynamically finds location)
function read_party()
    local party = {}
    local party_base = find_party_base()
    
    if not party_base then
        print("WARNING: Could not find party data!")
        return party
    end
    
    -- Party count is 4 bytes before party base
    local count = emu:read8(party_base - 4)
    if count > 6 then count = 6 end  -- Sanity check
    
    for slot = 0, count - 1 do
        local pokemon = read_pokemon(party_base + (slot * 100), true)
        if pokemon then
            pokemon.location = "party"
            pokemon.slot = slot + 1
            party[string.format("0x%08X", pokemon.pid)] = pokemon
        end
    end
    
    return party
end

-- Read all PC boxes
function read_boxes()
    local boxes = {}
    
    for box_num = 0, 13 do
        for slot = 0, 29 do
            local addr = BOX_BASE + (box_num * 30 * 80) + (slot * 80)
            local pokemon = read_pokemon(addr, false)
            
            if pokemon then
                pokemon.location = "box"
                pokemon.box = box_num + 1
                pokemon.slot = slot + 1
                boxes[string.format("0x%08X", pokemon.pid)] = pokemon
            end
        end
    end
    
    return boxes
end

-- Read all Pokemon
function read_all_pokemon()
    local all = read_party()
    local boxes = read_boxes()
    
    for pid, pokemon in pairs(boxes) do
        all[pid] = pokemon
    end
    
    return all
end

-- Storage for previous state
previous_state = {}

-- Detect changes
function detect_changes()
    local current_state = read_all_pokemon()
    local changes = {}
    
    -- Check for new Pokemon or changes
    for pid, current in pairs(current_state) do
        local prev = previous_state[pid]
        
        if not prev then
            -- NEW CATCH
            table.insert(changes, {
                type = "CATCH",
                pid = pid,
                species = current.species,
                location = current.location,
                slot = current.slot,
                box = current.box,
                level = current.level
            })
        else
            -- Check for changes in existing Pokemon
            
            if current.location == "party" and prev.location == "party" then
                -- DEATH
                if prev.hp and current.hp and prev.hp > 0 and current.hp == 0 then
                    table.insert(changes, {
                        type = "DEATH",
                        pid = pid,
                        species = current.species
                    })
                end
                
                -- EVOLUTION
                if prev.species ~= current.species then
                    table.insert(changes, {
                        type = "EVOLUTION",
                        pid = pid,
                        old_species = prev.species,
                        new_species = current.species
                    })
                end
                
                -- LEVEL UP
                if prev.level and current.level and prev.level ~= current.level then
                    table.insert(changes, {
                        type = "LEVEL_UP",
                        pid = pid,
                        species = current.species,
                        old_level = prev.level,
                        new_level = current.level
                    })
                end
            end
            
            -- LOCATION CHANGE
            if prev.location ~= current.location then
                table.insert(changes, {
                    type = "LOCATION_CHANGE",
                    pid = pid,
                    species = current.species,
                    from = prev.location,
                    to = current.location
                })
            end
        end
    end
    
    -- Check for removed Pokemon
    for pid, prev in pairs(previous_state) do
        if not current_state[pid] then
            table.insert(changes, {
                type = "REMOVED",
                pid = pid,
                species = prev.species
            })
        end
    end
    
    previous_state = current_state
    return changes
end

-- Log changes
function log_changes(changes)
    if #changes == 0 then return end
    
    print("\n=== CHANGES DETECTED ===")
    for _, change in ipairs(changes) do
        if change.type == "CATCH" then
            print(string.format("NEW: Species %d caught! (PID: %s, Location: %s)", 
                change.species, change.pid, change.location))
                
        elseif change.type == "DEATH" then
            print(string.format("DEATH: Species %d fainted! (PID: %s)", 
                change.species, change.pid))
                
        elseif change.type == "EVOLUTION" then
            print(string.format("EVOLUTION: Species %d evolved to %d (PID: %s)", 
                change.old_species, change.new_species, change.pid))
                
        elseif change.type == "LEVEL_UP" then
            print(string.format("LEVEL UP: Species %d leveled up %d -> %d (PID: %s)", 
                change.species, change.old_level, change.new_level, change.pid))
                
        elseif change.type == "LOCATION_CHANGE" then
            print(string.format("MOVED: Species %d moved from %s to %s (PID: %s)", 
                change.species, change.from, change.to, change.pid))
                
        elseif change.type == "REMOVED" then
            print(string.format("REMOVED: Species %d no longer in save (PID: %s)", 
                change.species, change.pid))
        end
    end
    print("========================\n")
end

-- Initialize
print("Nuzlocke Tracker initialized!")
print("Monitoring party and PC boxes (DMA-safe)...")
previous_state = read_all_pokemon()

-- Monitor every 2 seconds
local frame_counter = 0
callbacks:add("frame", function()
    frame_counter = frame_counter + 1
    if frame_counter >= 120 then
        frame_counter = 0
        local changes = detect_changes()
        log_changes(changes)
    end
end)
