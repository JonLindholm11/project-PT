-- ===================================
-- NUZLOCKE TRACKER - POKEMON RUN AND BUN
-- Auto-Detecting Trainer ID Version
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

-- Memory addresses for Pokemon Run and Bun
TRAINER_ID_ADDR = 0x02000020    -- Auto-detected Trainer ID location
PARTY_COUNT_ADDR = 0x02024EF0   -- Party count
PARTY_BASE = 0x02024EF4         -- Party data start
BOX_BASE = 0x02028000           -- PC boxes

-- Auto-detected Trainer ID (will be read from memory)
DETECTED_TRAINER_ID = nil

-- Read Trainer ID from memory
function get_trainer_id()
    if not DETECTED_TRAINER_ID then
        local tid = emu:read16(TRAINER_ID_ADDR)
        
        -- Validate: Trainer ID should be between 0-65535 (but rarely 0)
        if tid and tid > 0 and tid <= 65535 then
            DETECTED_TRAINER_ID = tid
            print(string.format("✓ Trainer ID auto-detected: %d (0x%04X)", tid, tid))
            return tid
        else
            -- If not found, try extracting from first Pokemon's OTID
            local party_count = emu:read8(PARTY_COUNT_ADDR)
            if party_count and party_count >= 1 and party_count <= 6 then
                local first_pokemon = PARTY_BASE
                local otid = emu:read32(first_pokemon + 4)
                if otid and otid > 0 then
                    -- Extract Trainer ID from OTID (lower 16 bits)
                    tid = otid % 65536
                    if tid > 0 then
                        DETECTED_TRAINER_ID = tid
                        print(string.format("✓ Trainer ID extracted from Pokemon: %d (0x%04X)", tid, tid))
                        return tid
                    end
                end
            end
        end
        
        return nil
    end
    
    return DETECTED_TRAINER_ID
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
    
    -- Sanity check: species should be reasonable (ROM hacks may have more than 386)
    if species < 1 or species > 2000 then
        return nil
    end
    
    local pokemon = {
        pid = pid,
        species = species
    }
    
    if is_party then
        pokemon.level = emu:read8(addr + 84)
        pokemon.hp = emu:read16(addr + 86)
        pokemon.max_hp = emu:read16(addr + 88)
        pokemon.status = emu:read32(addr + 80)
        
        -- Validation
        if pokemon.level < 1 or pokemon.level > 100 then
            return nil
        end
        if pokemon.hp > pokemon.max_hp or pokemon.max_hp > 999 then
            return nil
        end
    end
    
    return pokemon
end

-- Read entire party
function read_party()
    local party = {}
    
    -- Get party count
    local count = emu:read8(PARTY_COUNT_ADDR)
    if not count or count > 6 then
        return party
    end
    
    -- Ensure Trainer ID is detected
    if not DETECTED_TRAINER_ID then
        get_trainer_id()
    end
    
    for slot = 0, count - 1 do
        local pokemon = read_pokemon(PARTY_BASE + (slot * 100), true)
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
    
    -- Run and Bun may have different box structure
    -- Standard Gen 3: 14 boxes, 30 slots each, 80 bytes per Pokemon
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
print("╔════════════════════════════════════════════════╗")
print("║  NUZLOCKE TRACKER - POKEMON RUN AND BUN       ║")
print("║  Auto-Detecting Trainer ID                    ║")
print("╚════════════════════════════════════════════════╝")
print("")

-- Try to detect Trainer ID on startup
print("Attempting to auto-detect Trainer ID...")
local tid = get_trainer_id()

if tid then
    print(string.format("Using Trainer ID: %d (0x%04X)", tid, tid))
else
    print("Trainer ID will be detected when you have Pokemon in your party")
end

print("Monitoring party and PC boxes...")
print("Memory addresses configured for Pokemon Run and Bun")
print("")

-- Initial state
previous_state = read_all_pokemon()

-- Monitor every 2 seconds (120 frames at 60fps)
local frame_counter = 0
callbacks:add("frame", function()
    frame_counter = frame_counter + 1
    if frame_counter >= 120 then
        frame_counter = 0
        
        -- Try to detect Trainer ID if not yet found
        if not DETECTED_TRAINER_ID then
            get_trainer_id()
        end
        
        local changes = detect_changes()
        log_changes(changes)
    end
end)