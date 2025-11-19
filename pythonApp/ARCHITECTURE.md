# System Architecture Diagram

## Overall System Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          NUZLOCKE TRACKER SYSTEM                         │
└─────────────────────────────────────────────────────────────────────────┘

┌───────────────────┐
│   Game Emulator   │
│     (mGBA)        │
│                   │
│  ┌─────────────┐  │
│  │ Pokemon ROM │  │
│  │  Emerald/   │  │
│  │  FireRed    │  │
│  └─────────────┘  │
└────────┬──────────┘
         │
         │ Loads
         ▼
┌───────────────────┐
│   monitor.lua     │◄─────────────────┐
│                   │                  │
│ • Reads memory    │                  │
│ • Detects events  │                  │
│ • Outputs logs    │                  │
└────────┬──────────┘                  │
         │                             │
         │ Console Output              │
         ▼                             │
                                       │
   ┌─────────────┐                    │
   │  Log File   │                    │
   │  or stdout  │                    │
   └──────┬──────┘                    │
          │                           │
          │ Reads                     │
          ▼                           │
┌──────────────────────┐              │
│  Python Application  │              │
│ nuzlocke_tracker.py  │              │
│                      │              │
│ ┌──────────────────┐ │              │
│ │ LuaOutputParser  │ │  Parses:     │
│ │                  │ │  • CATCH     │
│ │ Regex patterns   │ │  • DEATH     │
│ │ for 6 event      │ │  • EVOLUTION │
│ │ types            │ │  • LEVEL_UP  │
│ └────────┬─────────┘ │  • LOCATION  │
│          │           │  • REMOVED   │
│          ▼           │              │
│ ┌──────────────────┐ │              │
│ │ BackendAPIClient │ │              │
│ │                  │ │              │
│ │ • HTTP POST      │ │              │
│ │ • JSON format    │ │              │
│ │ • Auth headers   │ │              │
│ └────────┬─────────┘ │              │
└──────────┼───────────┘              │
           │                          │
           │ HTTP POST                │
           │ /api/events              │
           ▼                          │
┌─────────────────────┐               │
│  .NET Backend API   │               │
│   (Your Code)       │               │
│                     │               │
│ ┌─────────────────┐ │               │
│ │EventsController │ │               │
│ │                 │ │               │
│ │ POST /api/events│ │               │
│ │ GET  /api/health│ │               │
│ └────────┬────────┘ │               │
│          │          │               │
│          ▼          │               │
│ ┌─────────────────┐ │               │
│ │ Business Logic  │ │               │
│ │                 │ │               │
│ │ • Validate      │ │               │
│ │ • Process       │ │               │
│ │ • Store         │ │               │
│ └────────┬────────┘ │               │
└──────────┼──────────┘               │
           │                          │
           │ SQL Queries              │
           ▼                          │
┌─────────────────────┐               │
│   Database          │               │
│   (SQL Server,      │               │
│    PostgreSQL,      │               │
│    MySQL, etc.)     │               │
│                     │               │
│ ┌─────────────────┐ │               │
│ │ Pokemon Table   │ │               │
│ │ Events Table    │ │               │
│ │ (Your Schema)   │ │               │
│ └─────────────────┘ │               │
└─────────────────────┘               │
                                      │
                                      │
┌─────────────────────┐               │
│  Optional:          │               │
│  Web Frontend       │───────────────┘
│                     │
│ • View Pokemon      │
│ • View Events       │
│ • Statistics        │
│ • Live updates      │
└─────────────────────┘
```

## Event Types and Data Flow

```
┌──────────────────────────────────────────────────────────────┐
│                        EVENT TYPES                            │
└──────────────────────────────────────────────────────────────┘

1. CATCH
   Lua Output: "NEW: Species 25 caught! (PID: 0x12345678, Location: party)"
   ──────────────────────────────────────────────────────────────────────
   Python Parses: { type: "CATCH", pid: "0x12345678", species: 25, location: "party" }
   ──────────────────────────────────────────────────────────────────────
   .NET Receives: JSON via POST /api/events
   ──────────────────────────────────────────────────────────────────────
   Database: INSERT new Pokemon record

2. DEATH
   Lua Output: "DEATH: Species 25 fainted! (PID: 0x12345678)"
   ──────────────────────────────────────────────────────────────────────
   Python Parses: { type: "DEATH", pid: "0x12345678", species: 25 }
   ──────────────────────────────────────────────────────────────────────
   .NET Receives: JSON via POST /api/events
   ──────────────────────────────────────────────────────────────────────
   Database: UPDATE Pokemon SET IsAlive = false

3. EVOLUTION
   Lua Output: "EVOLUTION: Species 25 evolved to 26 (PID: 0x12345678)"
   ──────────────────────────────────────────────────────────────────────
   Python Parses: { type: "EVOLUTION", old_species: 25, new_species: 26, pid: "0x12345678" }
   ──────────────────────────────────────────────────────────────────────
   .NET Receives: JSON via POST /api/events
   ──────────────────────────────────────────────────────────────────────
   Database: UPDATE Pokemon SET Species = 26

4. LEVEL_UP
   Lua Output: "LEVEL UP: Species 25 leveled up 5 -> 6 (PID: 0x12345678)"
   ──────────────────────────────────────────────────────────────────────
   Python Parses: { type: "LEVEL_UP", species: 25, old_level: 5, new_level: 6, pid: "0x12345678" }
   ──────────────────────────────────────────────────────────────────────
   .NET Receives: JSON via POST /api/events
   ──────────────────────────────────────────────────────────────────────
   Database: UPDATE Pokemon SET Level = 6

5. LOCATION_CHANGE
   Lua Output: "MOVED: Species 25 moved from party to box (PID: 0x12345678)"
   ──────────────────────────────────────────────────────────────────────
   Python Parses: { type: "LOCATION_CHANGE", species: 25, from_location: "party", to_location: "box", pid: "0x12345678" }
   ──────────────────────────────────────────────────────────────────────
   .NET Receives: JSON via POST /api/events
   ──────────────────────────────────────────────────────────────────────
   Database: UPDATE Pokemon SET Location = 'box'

6. REMOVED
   Lua Output: "REMOVED: Species 25 no longer in save (PID: 0x12345678)"
   ──────────────────────────────────────────────────────────────────────
   Python Parses: { type: "REMOVED", species: 25, pid: "0x12345678" }
   ──────────────────────────────────────────────────────────────────────
   .NET Receives: JSON via POST /api/events
   ──────────────────────────────────────────────────────────────────────
   Database: UPDATE Pokemon SET IsActive = false
```

## Deployment Scenarios

### Scenario 1: All Local (Development)
```
┌──────────────────┐
│  Your Computer   │
│                  │
│  ┌────────────┐  │
│  │  Emulator  │  │
│  │  + Lua     │  │
│  └─────┬──────┘  │
│        │         │
│        ▼         │
│  ┌────────────┐  │
│  │  Python    │  │
│  │  Tracker   │  │
│  └─────┬──────┘  │
│        │         │
│        ▼         │
│  ┌────────────┐  │
│  │  .NET API  │  │
│  │  :5000     │  │
│  └─────┬──────┘  │
│        │         │
│        ▼         │
│  ┌────────────┐  │
│  │  Database  │  │
│  └────────────┘  │
└──────────────────┘
```

### Scenario 2: Remote Backend (Production)
```
┌──────────────────┐            ┌──────────────────┐
│  Your Computer   │            │  Cloud Server    │
│                  │            │                  │
│  ┌────────────┐  │            │  ┌────────────┐  │
│  │  Emulator  │  │            │  │  .NET API  │  │
│  │  + Lua     │  │            │  │  :443      │  │
│  └─────┬──────┘  │            │  └─────┬──────┘  │
│        │         │            │        │         │
│        ▼         │   HTTPS    │        ▼         │
│  ┌────────────┐  │◄──────────►│  ┌────────────┐  │
│  │  Python    │  │            │  │  Database  │  │
│  │  Tracker   │  │            │  └────────────┘  │
│  └────────────┘  │            │                  │
└──────────────────┘            └──────────────────┘
```

### Scenario 3: Shared Hosting
```
┌──────────────────┐            ┌──────────────────┐
│  Computer A      │            │  Cloud Server    │
│  ┌────────────┐  │            │                  │
│  │  Emulator  │  │            │  ┌────────────┐  │
│  │  + Lua     │  │            │  │  .NET API  │  │
│  └─────┬──────┘  │            │  │  :443      │  │
│        │         │            │  └─────┬──────┘  │
│        ▼         │   HTTPS    │        │         │
│  ┌────────────┐  │◄──────────►│        ▼         │
│  │  Python    │  │            │  ┌────────────┐  │
│  │  Tracker   │  │            │  │  Database  │  │
│  └────────────┘  │            │  └────────────┘  │
└──────────────────┘            │        ▲         │
                                │        │         │
┌──────────────────┐            │        │         │
│  Computer B      │   HTTPS    │        │         │
│  ┌────────────┐  │◄──────────►┤        │         │
│  │  Emulator  │  │            │        │         │
│  │  + Lua     │  │            │        │         │
│  └─────┬──────┘  │            │        │         │
│        │         │            │        │         │
│        ▼         │            │        │         │
│  ┌────────────┐  │            │        │         │
│  │  Python    │  │────────────┼────────┘         │
│  │  Tracker   │  │            │                  │
│  └────────────┘  │            └──────────────────┘
└──────────────────┘
     Multiple users can track different Nuzlockes
```

## Technology Stack

```
┌─────────────────────────────────────────────────────────┐
│                    COMPONENT LAYERS                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Layer 1: Game Layer                                    │
│  ├── Pokemon ROM (Emerald/FireRed/etc.)                 │
│  └── Emulator (mGBA/BizHawk)                            │
│                                                          │
│  Layer 2: Monitoring Layer                              │
│  ├── Lua 5.x                                            │
│  ├── monitor.lua script                                 │
│  └── Memory reading                                     │
│                                                          │
│  Layer 3: Bridge Layer (Your Python App)                │
│  ├── Python 3.7+                                        │
│  ├── requests library                                   │
│  ├── Regex parsing                                      │
│  └── HTTP client                                        │
│                                                          │
│  Layer 4: Backend Layer (Your .NET App)                 │
│  ├── ASP.NET Core                                       │
│  ├── Web API Controllers                                │
│  ├── Entity Framework (optional)                        │
│  └── Business Logic                                     │
│                                                          │
│  Layer 5: Data Layer                                    │
│  ├── SQL Server / PostgreSQL / MySQL                    │
│  ├── Tables: Pokemon, Events                            │
│  └── Your custom schema                                 │
│                                                          │
│  Layer 6: Presentation Layer (Optional)                 │
│  ├── Web Frontend (React/Vue/Blazor)                    │
│  ├── Mobile App                                         │
│  └── Discord Bot / Webhooks                             │
│                                                          │
└─────────────────────────────────────────────────────────┘
```
