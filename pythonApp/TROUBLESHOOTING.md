# Troubleshooting Guide

## Common Issues and Solutions

### 1. "Cannot connect to backend" / Connection Error

**Problem:** Python app cannot reach your .NET backend.

**Solutions:**

```bash
# Test 1: Is backend running?
curl http://localhost:5000/api/health

# Test 2: Check if port is open
netstat -an | grep 5000

# Test 3: Test with Python app
python nuzlocke_tracker.py --test --api-url http://localhost:5000/api
```

**Common causes:**
- ❌ Backend not started
- ❌ Wrong port number
- ❌ Firewall blocking connection
- ❌ Backend crashed/errored

**Fixes:**
- ✅ Start your .NET app: `dotnet run`
- ✅ Check firewall settings
- ✅ Verify API URL is correct
- ✅ Check backend logs for errors

---

### 2. "Log file not found"

**Problem:** Python app can't find the emulator log file.

**Solution:**
```bash
# Find where your emulator logs
# For mGBA, typically:
ls -la ~/.config/mgba/

# Check if logging is enabled in emulator
# mGBA: Tools → Scripting → File → Log to File
```

**Fixes:**
- ✅ Enable logging in emulator settings
- ✅ Use absolute path to log file
- ✅ Check file permissions
- ✅ The app will wait for file creation if it doesn't exist

---

### 3. No events detected in log

**Problem:** Log file exists but no events are being parsed.

**Diagnosis:**
```bash
# Check log file content manually
cat /path/to/emulator.log

# Test with simulator
python test_simulator.py --mode file
python nuzlocke_tracker.py --log-file test_output.log --process-existing
```

**Common causes:**
- ❌ Lua script not loaded in emulator
- ❌ Log format doesn't match parser patterns
- ❌ Game not generating events yet

**Fixes:**
- ✅ Verify Lua script is loaded: Check emulator script console
- ✅ Compare log output with expected format
- ✅ Actually play the game to generate events

**Expected log format:**
```
NEW: Species 25 caught! (PID: 0x12345678, Location: party)
DEATH: Species 25 fainted! (PID: 0x12345678)
```

---

### 4. Events parsed but not appearing in database

**Problem:** Python app shows events but they're not in your database.

**Diagnosis:**
```bash
# Check if API returns success
# Enable verbose logging by checking Python output

# Test API directly
curl -X POST http://localhost:5000/api/events \
  -H "Content-Type: application/json" \
  -d '{"type":"CATCH","pid":"0xTEST","species":25,"location":"party","timestamp":"2025-11-18T12:00:00Z"}'
```

**Common causes:**
- ❌ .NET endpoint not implemented correctly
- ❌ Database connection failed
- ❌ Validation errors in backend
- ❌ API returns success but doesn't save

**Fixes:**
- ✅ Check .NET backend logs
- ✅ Verify database connection string
- ✅ Test endpoint with curl/Postman
- ✅ Add logging to your .NET controller
- ✅ Check database permissions

---

### 5. "401 Unauthorized" or "403 Forbidden"

**Problem:** API rejects requests due to authentication.

**Solution:**
```bash
# If you implemented API key auth, provide it:
python nuzlocke_tracker.py \
  --log-file /path/to/log \
  --api-url http://localhost:5000/api \
  --api-key YOUR_API_KEY_HERE
```

**Fixes:**
- ✅ Provide correct API key
- ✅ Disable auth in backend for testing
- ✅ Check API key format matches backend expectations

---

### 6. Python crashes or exits unexpectedly

**Problem:** Python app terminates without clear error.

**Diagnosis:**
```bash
# Run with Python directly to see full errors
python -u nuzlocke_tracker.py --log-file /path/to/log

# Check Python version
python --version  # Should be 3.7+

# Verify dependencies
pip list | grep requests
```

**Common causes:**
- ❌ Missing dependencies
- ❌ Python version too old
- ❌ Syntax error (unlikely with provided code)
- ❌ Permissions issue

**Fixes:**
- ✅ Install dependencies: `pip install -r requirements.txt`
- ✅ Use Python 3.7 or higher
- ✅ Check file/directory permissions
- ✅ Run with `-u` flag for unbuffered output

---

### 7. Events are duplicated

**Problem:** Same event appears multiple times in database.

**Common causes:**
- ❌ Running multiple instances of Python app
- ❌ Backend not deduplicating events
- ❌ Log file rotated/replayed

**Fixes:**
- ✅ Stop all Python tracker instances
- ✅ Implement event deduplication in .NET backend (check PID + timestamp)
- ✅ Use `--process-existing` only once per log file

**Backend deduplication example:**
```csharp
// Check if event already exists
var exists = await _db.Events.AnyAsync(e => 
    e.Pid == eventData.Pid && 
    e.Type == eventData.Type &&
    e.Timestamp == eventData.Timestamp
);

if (exists)
{
    return Ok(new { Success = true, Message = "Duplicate ignored" });
}
```

---

### 8. Lua script errors in emulator

**Problem:** Lua script crashes or shows errors in emulator console.

**Common causes:**
- ❌ Wrong memory addresses for your game version
- ❌ Emulator doesn't support certain Lua functions
- ❌ Script path issues

**Fixes:**
- ✅ Verify game version matches script
- ✅ Update memory addresses (BOX_BASE, YOUR_TRAINER_ID)
- ✅ Test with minimal Lua script first
- ✅ Check emulator Lua documentation

**Minimal test script:**
```lua
print("Lua is working!")
callbacks:add("frame", function()
    -- Simple test
end)
```

---

### 9. High CPU usage

**Problem:** Python app using too much CPU.

**Common causes:**
- ❌ Polling interval too fast
- ❌ Large log file being processed repeatedly

**Fixes:**
- ✅ Increase polling interval:
  ```bash
  python nuzlocke_tracker.py --log-file /path/to/log --interval 2.0
  ```
- ✅ Use `--process-existing` only once
- ✅ Rotate log files periodically

---

### 10. Timestamps are wrong

**Problem:** Events have incorrect timestamps.

**Explanation:** Python app adds timestamp when it parses the event, not when it occurred.

**Impact:** Usually acceptable (few seconds delay)

**If critical:**
- Modify Lua script to include timestamps
- Update Python parser to extract timestamps
- Adjust in .NET backend if needed

---

## Debugging Tips

### Enable verbose logging (Python)

Modify `nuzlocke_tracker.py`:
```python
logging.basicConfig(
    level=logging.DEBUG,  # Change from INFO to DEBUG
    format='%(asctime)s [%(levelname)s] %(message)s'
)
```

### Test individual components

**Test 1: Lua script**
- Load in emulator
- Check console for output
- Play game, catch a Pokémon

**Test 2: Python parser**
```bash
echo "NEW: Species 25 caught! (PID: 0x12345678, Location: party)" | python nuzlocke_tracker.py --stdin
```

**Test 3: API endpoint**
```bash
curl -X POST http://localhost:5000/api/events \
  -H "Content-Type: application/json" \
  -d '{"type":"CATCH","pid":"0xTEST","species":1,"location":"party","timestamp":"2025-11-18T12:00:00Z"}'
```

**Test 4: End-to-end**
```bash
python test_simulator.py --mode continuous | python nuzlocke_tracker.py --stdin
```

### Check logs

**Python app output:**
- Shows parsed events
- Shows API responses
- Shows connection errors

**Backend logs:**
- Request received
- Validation errors
- Database operations
- Exceptions

**Emulator console:**
- Lua script output
- Lua errors

---

## Performance Optimization

### For large log files

```bash
# Process only new entries, skip existing
python nuzlocke_tracker.py --log-file /path/to/log
# (Don't use --process-existing)

# Or rotate logs periodically
mv emulator.log emulator.log.old
touch emulator.log
```

### For slow API

```python
# In BackendAPIClient, increase timeout
def send_event(self, event: Dict) -> bool:
    response = self.session.post(
        f"{self.base_url}/events",
        json=event,
        timeout=30  # Increase from 10
    )
```

### For many events

Consider batching in future versions:
- Queue events in Python
- Send in batches every N seconds
- Backend processes batch

---

## Getting Help

### Diagnostic Information to Collect

When asking for help, provide:

1. **Python version**: `python --version`
2. **Dependencies**: `pip list`
3. **OS**: `uname -a` (Linux/Mac) or Windows version
4. **Emulator**: Name and version
5. **Game**: ROM version
6. **Error messages**: Full stack trace
7. **Sample log file**: First 50 lines
8. **Backend info**: .NET version, framework

### Test checklist

Before reporting issue:
- [ ] Tested with simulator: `python test_simulator.py`
- [ ] Backend health check passes
- [ ] Lua script loads without errors
- [ ] Log file exists and is readable
- [ ] Manual curl to API works
- [ ] Checked all logs for errors

---

## Known Limitations

1. **Memory addresses**: May need adjustment for different game versions
2. **Emulator support**: Works best with mGBA
3. **Timing**: Small delay between game event and database entry
4. **No retroactive data**: Can't detect events before script was loaded
5. **Network dependent**: Requires backend connectivity

---

## Emergency Reset

If everything is broken:

```bash
# 1. Stop all processes
pkill -f nuzlocke_tracker.py

# 2. Test with fresh simulator data
python test_simulator.py --mode file --output test.log

# 3. Process test file only
python nuzlocke_tracker.py --log-file test.log --process-existing --test

# 4. If that works, problem is with:
#    - Lua script
#    - Emulator configuration
#    - Log file format

# 5. If that doesn't work, problem is with:
#    - Python dependencies
#    - Backend API
#    - Network connectivity
```
