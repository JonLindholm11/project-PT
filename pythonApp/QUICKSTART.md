# Quick Start Guide

## Setup Steps

### 1. Install Python Dependencies

```bash
pip install -r requirements.txt
```

### 2. Set Up Your .NET Backend

Follow the `DOTNET_API_SPEC.md` to implement the required endpoints:
- `POST /api/events` - Receive events
- `GET /api/health` - Health check (optional)

Start your .NET backend on port 5000 (or your preferred port).

### 3. Test Backend Connection

```bash
python nuzlocke_tracker.py --test --api-url http://localhost:5000/api
```

You should see: `✓ Backend is accessible`

### 4. Test with Simulated Data

Generate a test log file:
```bash
python test_simulator.py --mode file --output test.log
```

Process the test file:
```bash
python nuzlocke_tracker.py --log-file test.log --process-existing --api-url http://localhost:5000/api
```

### 5. Set Up Lua Script in Emulator

#### For mGBA:

1. Open mGBA
2. Load your Pokémon ROM
3. Go to **Tools → Scripting**
4. Click **Load Script** and select `monitor.lua`
5. Enable **File → Log to File**
6. Note the log file location (usually `~/.config/mgba/scripting.log`)

#### For VBA:

VBA has limited Lua support. Consider using mGBA or BizHawk instead.

#### For BizHawk:

1. Open BizHawk
2. Load your Pokémon ROM
3. Go to **Tools → Lua Console**
4. Click **Script → Open Script** and select `monitor.lua`
5. Check console output location

### 6. Start Monitoring

#### Monitor log file:
```bash
python nuzlocke_tracker.py --log-file /path/to/emulator.log --api-url http://localhost:5000/api
```

#### Or pipe directly (if supported):
```bash
emulator-with-lua-output | python nuzlocke_tracker.py --stdin --api-url http://localhost:5000/api
```

## Testing End-to-End

### Terminal 1: Start .NET Backend
```bash
cd your-dotnet-project
dotnet run
```

### Terminal 2: Simulate Lua Output
```bash
python test_simulator.py --mode continuous | python nuzlocke_tracker.py --stdin --api-url http://localhost:5000/api
```

You should see events being parsed and sent to your backend!

## Common Workflows

### Development Testing
```bash
# Generate test data
python test_simulator.py --mode file

# Process test data
python nuzlocke_tracker.py --log-file test_output.log --process-existing
```

### Live Monitoring (Production)
```bash
# Start with your emulator's log file
python nuzlocke_tracker.py --log-file ~/.config/mgba/scripting.log --api-url http://your-server.com/api --api-key YOUR_KEY
```

### Recover Lost Data
```bash
# Process old log file
python nuzlocke_tracker.py --log-file old_playthrough.log --process-existing --api-url http://localhost:5000/api
```

## Troubleshooting

### "Cannot connect to backend"
- Verify .NET backend is running: `curl http://localhost:5000/api/health`
- Check firewall settings
- Verify API URL is correct

### "Log file not found"
- Check emulator logging settings
- Verify file path is correct
- App will wait for file to be created

### "No events detected"
- Verify Lua script is loaded in emulator
- Check log file manually to see if events are being written
- Try test simulator to verify parsing works

### Events not appearing in database
- Check .NET backend logs for errors
- Verify database connection in backend
- Test API endpoint directly with curl

## File Structure

```
project-PT/
├── lua/
│   └── monitor.lua              # Lua script for emulator
├── python/
│   ├── nuzlocke_tracker.py      # Main Python app
│   ├── test_simulator.py        # Testing tool
│   ├── requirements.txt         # Python dependencies
│   └── config.example.json      # Config template
├── docs/
│   ├── README_PYTHON.md         # Python app documentation
│   ├── DOTNET_API_SPEC.md       # .NET API specification
│   └── QUICKSTART.md            # This file
└── backend/
    └── your-dotnet-project/     # Your .NET backend
```

## Next Steps

1. **Customize the Lua script** if you need different memory addresses
2. **Implement your .NET backend** following the API spec
3. **Add more features** like webhooks, Discord notifications, etc.
4. **Build a frontend** to visualize your Nuzlocke data

## Support

For issues or questions about:
- **Lua script**: Check memory addresses for your specific game/emulator
- **Python app**: Review logs and verify event parsing
- **.NET backend**: Check API endpoint implementation and database
- **Overall system**: Test each component individually first

Happy Nuzlocking! 🎮
