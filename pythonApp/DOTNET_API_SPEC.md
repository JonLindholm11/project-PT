# .NET Backend API Specification

This document outlines the API endpoints your .NET backend should implement to receive events from the Python client.

## Base URL

```
http://localhost:5000/api
```

(Configurable in Python client)

## Authentication (Optional)

If you want to secure your API, implement Bearer token authentication:

```
Authorization: Bearer YOUR_API_KEY
```

The Python client will send this header if you provide `--api-key` parameter.

## Endpoints

### 1. POST /api/events

Receive a new Nuzlocke event from the Python client.

#### Request Headers
```
Content-Type: application/json
Authorization: Bearer YOUR_API_KEY (if enabled)
```

#### Request Body Examples

**CATCH Event:**
```json
{
  "type": "CATCH",
  "pid": "0x12345678",
  "species": 25,
  "location": "party",
  "timestamp": "2025-11-18T12:00:00.000Z"
}
```

**DEATH Event:**
```json
{
  "type": "DEATH",
  "pid": "0x12345678",
  "species": 25,
  "timestamp": "2025-11-18T12:00:00.000Z"
}
```

**EVOLUTION Event:**
```json
{
  "type": "EVOLUTION",
  "pid": "0x12345678",
  "old_species": 25,
  "new_species": 26,
  "timestamp": "2025-11-18T12:00:00.000Z"
}
```

**LEVEL_UP Event:**
```json
{
  "type": "LEVEL_UP",
  "pid": "0x12345678",
  "species": 25,
  "old_level": 15,
  "new_level": 16,
  "timestamp": "2025-11-18T12:00:00.000Z"
}
```

**LOCATION_CHANGE Event:**
```json
{
  "type": "LOCATION_CHANGE",
  "pid": "0x12345678",
  "species": 25,
  "from_location": "party",
  "to_location": "box",
  "timestamp": "2025-11-18T12:00:00.000Z"
}
```

**REMOVED Event:**
```json
{
  "type": "REMOVED",
  "pid": "0x12345678",
  "species": 25,
  "timestamp": "2025-11-18T12:00:00.000Z"
}
```

#### Response

**Success (200 OK or 201 Created):**
```json
{
  "success": true,
  "eventId": "123",
  "message": "Event received successfully"
}
```

**Error (400 Bad Request):**
```json
{
  "success": false,
  "error": "Invalid event format",
  "details": "Missing required field: pid"
}
```

**Error (401 Unauthorized):**
```json
{
  "success": false,
  "error": "Invalid or missing API key"
}
```

**Error (500 Internal Server Error):**
```json
{
  "success": false,
  "error": "Database error",
  "details": "Connection timeout"
}
```

### 2. GET /api/health (Optional)

Health check endpoint to verify the API is running.

#### Response

**Success (200 OK):**
```json
{
  "status": "healthy",
  "timestamp": "2025-11-18T12:00:00.000Z"
}
```

## C# Model Classes Example

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

public class ApiResponse
{
    public bool Success { get; set; }
    public string EventId { get; set; }
    public string Message { get; set; }
    public string Error { get; set; }
    public string Details { get; set; }
}
```

## Example Controller (C#)

```csharp
using Microsoft.AspNetCore.Mvc;

[ApiController]
[Route("api")]
public class NuzlockeController : ControllerBase
{
    private readonly INuzlockeService _nuzlockeService;
    
    public NuzlockeController(INuzlockeService nuzlockeService)
    {
        _nuzlockeService = nuzlockeService;
    }
    
    [HttpPost("events")]
    public async Task<IActionResult> ReceiveEvent([FromBody] NuzlockeEvent eventData)
    {
        if (eventData == null || string.IsNullOrEmpty(eventData.Type) || string.IsNullOrEmpty(eventData.Pid))
        {
            return BadRequest(new ApiResponse 
            { 
                Success = false, 
                Error = "Invalid event format",
                Details = "Type and PID are required"
            });
        }
        
        try
        {
            var eventId = await _nuzlockeService.ProcessEventAsync(eventData);
            
            return Ok(new ApiResponse 
            { 
                Success = true, 
                EventId = eventId.ToString(),
                Message = "Event received successfully"
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new ApiResponse 
            { 
                Success = false, 
                Error = "Internal server error",
                Details = ex.Message
            });
        }
    }
    
    [HttpGet("health")]
    public IActionResult HealthCheck()
    {
        return Ok(new 
        { 
            Status = "healthy", 
            Timestamp = DateTime.UtcNow 
        });
    }
}
```

## Database Schema Suggestions

Your .NET backend should handle database operations. Here's a suggested schema:

### Pokemon Table
```sql
CREATE TABLE Pokemon (
    PID VARCHAR(20) PRIMARY KEY,
    Species INT NOT NULL,
    FirstSeen DATETIME DEFAULT GETUTCDATE(),
    LastUpdated DATETIME DEFAULT GETUTCDATE(),
    CurrentLocation VARCHAR(50),
    CurrentLevel INT,
    IsAlive BIT DEFAULT 1,
    IsActive BIT DEFAULT 1
);
```

### Events Table
```sql
CREATE TABLE Events (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Timestamp DATETIME DEFAULT GETUTCDATE(),
    EventType VARCHAR(50) NOT NULL,
    PID VARCHAR(20) NOT NULL,
    Species INT,
    OldSpecies INT NULL,
    NewSpecies INT NULL,
    OldLevel INT NULL,
    NewLevel INT NULL,
    Location VARCHAR(50) NULL,
    FromLocation VARCHAR(50) NULL,
    ToLocation VARCHAR(50) NULL,
    FOREIGN KEY (PID) REFERENCES Pokemon(PID)
);
```

## Testing the API

You can test your API with curl:

```bash
# Test health check
curl http://localhost:5000/api/health

# Test event posting
curl -X POST http://localhost:5000/api/events \
  -H "Content-Type: application/json" \
  -d '{
    "type": "CATCH",
    "pid": "0x12345678",
    "species": 25,
    "location": "party",
    "timestamp": "2025-11-18T12:00:00.000Z"
  }'

# With API key
curl -X POST http://localhost:5000/api/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "type": "CATCH",
    "pid": "0x12345678",
    "species": 25,
    "location": "party",
    "timestamp": "2025-11-18T12:00:00.000Z"
  }'
```

## CORS Configuration (If needed)

If your frontend is on a different domain, enable CORS in your .NET app:

```csharp
// In Program.cs or Startup.cs
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowPythonClient", builder =>
    {
        builder.AllowAnyOrigin()
               .AllowAnyMethod()
               .AllowAnyHeader();
    });
});

app.UseCors("AllowPythonClient");
```
