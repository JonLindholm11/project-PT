# Nuzlocke Tracker - Python Client

Python application that monitors the Lua script output from your emulator and sends events to your .NET backend API.

## Features

- Parses Lua script output in real-time
- Detects 6 event types: CATCH, DEATH, EVOLUTION, LEVEL_UP, LOCATION_CHANGE, REMOVED
- Sends events to .NET backend via REST API
- Multiple monitoring modes: log file, stdin, or existing file processing
- Configurable polling intervals
- Built-in health check for backend connectivity

## Installation

1. Install Python 3.7 or higher
2. Install dependencies:

```bash
pip install -r requirements.txt
```

## Usage

### Monitor a log file (real-time)

```bash
python nuzlocke_tracker.py --log-file /path/to/emulator.log --api-url http://localhost:5000/api
```

### Process existing log file then monitor

```bash
python nuzlocke_tracker.py --log-file /path/to/emulator.log --process-existing
```

### Read from stdin (pipe from emulator)

```bash
emulator-command | python nuzlocke_tracker.py --stdin
```

### Test backend connection

```bash
python nuzlocke_tracker.py --test --api-url http://localhost:5000/api
```

## Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--api-url` | Backend API base URL | `http://localhost:5000/api` |
| `--api-key` | API key for authentication | None |
| `--log-file` | Path to log file to monitor | Required (unless --stdin) |
| `--process-existing` | Process existing log content first | False |
| `--stdin` | Read from standard input | False |
| `--interval` | Polling interval in seconds | 1.0 |
| `--test` | Test backend connection | False |

## Event Format

Events are sent to your .NET backend as JSON:

### CATCH Event
```json
{
  "type": "CATCH",
  "pid": "0x12345678",
  "species": 25,
  "location": "party",
  "timestamp": "2025-11-18T12:00:00"
}
```

### DEATH Event
```json
{
  "type": "DEATH",
  "pid": "0x12345678",
  "species": 25,
  "timestamp": "2025-11-18T12:00:00"
}
```

### EVOLUTION Event
```json
{
  "type": "EVOLUTION",
  "pid": "0x12345678",
  "old_species": 25,
  "new_species": 26,
  "timestamp": "2025-11-18T12:00:00"
}
```

### LEVEL_UP Event
```json
{
  "type": "LEVEL_UP",
  "pid": "0x12345678",
  "species": 25,
  "old_level": 15,
  "new_level": 16,
  "timestamp": "2025-11-18T12:00:00"
}
```

### LOCATION_CHANGE Event
```json
{
  "type": "LOCATION_CHANGE",
  "pid": "0x12345678",
  "species": 25,
  "from_location": "party",
  "to_location": "box",
  "timestamp": "2025-11-18T12:00:00"
}
```

### REMOVED Event
```json
{
  "type": "REMOVED",
  "pid": "0x12345678",
  "species": 25,
  "timestamp": "2025-11-18T12:00:00"
}
```

## .NET Backend API Endpoints

Your .NET backend should implement these endpoints:

- `POST /api/events` - Receive new events
- `GET /api/health` - Health check endpoint (optional)

### Expected API Response

**Success (200/201):**
```json
{
  "success": true,
  "eventId": "some-id"
}
```

**Error (4xx/5xx):**
```json
{
  "success": false,
  "error": "Error message"
}
```

## Integration with Lua Script

Your Lua script (`monitor.lua`) outputs events like:
```
NEW: Species 25 caught! (PID: 0x12345678, Location: party)
DEATH: Species 25 fainted! (PID: 0x12345678)
EVOLUTION: Species 25 evolved to 26 (PID: 0x12345678)
```

This Python app parses these and sends them to your backend.

## Workflow

1. Start your .NET backend
2. Load Lua script in your emulator (mGBA, VBA, etc.)
3. Configure emulator to log output to a file OR pipe to this script
4. Run this Python app to monitor and forward events

## Example Setup

### With mGBA:

1. Load game in mGBA
2. Tools → Scripting → Load script (`monitor.lua`)
3. Tools → Scripting → Enable logging to file
4. Run Python app:
```bash
python nuzlocke_tracker.py --log-file ~/.config/mgba/scripting.log
```

### With piped output:

If your emulator supports stdout:
```bash
emulator --script monitor.lua | python nuzlocke_tracker.py --stdin
```

## Troubleshooting

### "Connection error - is the backend running?"
- Verify your .NET backend is running
- Check the API URL is correct
- Test with: `python nuzlocke_tracker.py --test`

### "Log file not found"
- Check the log file path
- Ensure emulator is configured to output to that file
- The app will wait for the file to be created

### Events not detected
- Verify Lua script is running in emulator
- Check log file contains expected output format
- Try `--process-existing` to test with existing log data

## License

Part of the project-PT Nuzlocke tracking system.
