# Nuzlocke Tracker Python Application - Summary

## What I Created

A Python application that monitors your Lua script output and sends events to your .NET backend API (no Python database - your .NET backend handles all data storage).

## Files Created

### 1. **nuzlocke_tracker.py** (Main Application)
The core application with three main components:

- **BackendAPIClient**: Sends HTTP requests to your .NET backend
  - Handles authentication (optional API key)
  - Sends events as JSON
  - Includes health check functionality
  
- **LuaOutputParser**: Parses Lua script console output
  - Detects 6 event types: CATCH, DEATH, EVOLUTION, LEVEL_UP, LOCATION_CHANGE, REMOVED
  - Uses regex patterns to extract event data
  
- **NuzlockeTracker**: Main coordinator
  - Monitors log files (tail -f style)
  - Can read from stdin (piped input)
  - Processes existing log files
  - Sends parsed events to backend API

### 2. **test_simulator.py** (Testing Tool)
Simulates Lua output for testing:
- `--mode continuous`: Outputs test events to stdout (pipe to tracker)
- `--mode file`: Generates a test log file

### 3. **config_loader.py** (Configuration Manager)
Optional config file support for easier deployment

### 4. **requirements.txt**
Python dependencies (just `requests`)

### 5. **config.example.json**
Template configuration file

### 6. **DOTNET_API_SPEC.md**
Complete specification for your .NET backend:
- API endpoints to implement
- Request/response formats
- C# model classes example
- Example controller code
- Database schema suggestions
- CORS configuration

### 7. **README_PYTHON.md**
Complete documentation for the Python app

### 8. **QUICKSTART.md**
Step-by-step guide to get everything running

## How It Works

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐         ┌──────────┐
│  Emulator   │ ──Lua──→│ monitor.lua  │ ──Log──→│   Python    │ ──HTTP─→│  .NET    │
│   (mGBA)    │  Script │  (Your file) │  Output │   Tracker   │  POST  │ Backend  │
└─────────────┘         └──────────────┘         └─────────────┘         └──────────┘
                                                                                 │
                                                                                 ↓
                                                                           ┌──────────┐
                                                                           │ Database │
                                                                           │ (Your DB)│
                                                                           └──────────┘
```

### Event Flow:

1. **Lua script** (`monitor.lua`) detects game events
2. **Emulator** outputs to console/log file
3. **Python app** parses the output
4. **Python app** sends JSON to your .NET API
5. **.NET backend** stores in database

## Usage Examples

### Basic monitoring:
```bash
python nuzlocke_tracker.py --log-file /path/to/emulator.log --api-url http://localhost:5000/api
```

### With API key:
```bash
python nuzlocke_tracker.py --log-file /path/to/emulator.log --api-url http://localhost:5000/api --api-key YOUR_KEY
```

### Process existing log:
```bash
python nuzlocke_tracker.py --log-file old.log --process-existing --api-url http://localhost:5000/api
```

### Read from stdin:
```bash
emulator-output | python nuzlocke_tracker.py --stdin --api-url http://localhost:5000/api
```

### Test backend:
```bash
python nuzlocke_tracker.py --test --api-url http://localhost:5000/api
```

## Event Format

All events are sent as JSON POST requests to `/api/events`:

```json
{
  "type": "CATCH",
  "pid": "0x12345678",
  "species": 25,
  "location": "party",
  "timestamp": "2025-11-18T12:00:00Z"
}
```

See `DOTNET_API_SPEC.md` for all event types and formats.

## What You Need to Implement (.NET Backend)

### Required Endpoint:
```csharp
POST /api/events
- Accept JSON event data
- Validate the event
- Store in your database
- Return success/error response
```

### Optional Endpoint:
```csharp
GET /api/health
- Return 200 OK if service is running
- Used by Python app to verify connectivity
```

### Example C# Models:
```csharp
public class NuzlockeEvent
{
    public string Type { get; set; }
    public string Pid { get; set; }
    public int? Species { get; set; }
    public int? OldSpecies { get; set; }
    public int? NewSpecies { get; set; }
    public int? OldLevel { get; set; }
    public int? NewLevel { get; set; }
    public string Location { get; set; }
    public string FromLocation { get; set; }
    public string ToLocation { get; set; }
    public DateTime Timestamp { get; set; }
}
```

## Testing Without .NET Backend

You can test the parser and client logic:

```bash
# Test parsing
python test_simulator.py --mode file
python nuzlocke_tracker.py --log-file test_output.log --process-existing

# The app will attempt to send events and log failures (expected without backend)
```

## Key Features

✅ **No database in Python** - All data handling in your .NET backend  
✅ **Real-time monitoring** - Tail-f style log watching  
✅ **Multiple input modes** - Log file, stdin, or batch processing  
✅ **Robust parsing** - Regex-based event detection  
✅ **Error handling** - Connection errors, timeouts, retries  
✅ **Configurable** - Command line args or config file  
✅ **Testing tools** - Simulator and health checks  
✅ **Well documented** - Complete API spec and guides  

## Next Steps

1. **Install Python dependencies**: `pip install -r requirements.txt`
2. **Implement .NET backend** following `DOTNET_API_SPEC.md`
3. **Test with simulator**: `python test_simulator.py`
4. **Connect to emulator**: Configure log output path
5. **Start monitoring**: Run the tracker pointing to your API

## Questions?

- **Lua script issues**: Check memory addresses for your game version
- **Parsing issues**: Verify log output format matches patterns
- **.NET backend**: Follow the API spec exactly
- **Connection issues**: Test with `--test` flag and check backend logs

Good luck with your Nuzlocke tracker! 🎮
