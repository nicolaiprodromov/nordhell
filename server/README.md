# VPN Orchestrator Server

A FastAPI-based web application for managing VPN tunnels with an interactive dashboard.

## Project Structure

```
server/
├── main.py              # Application entry point (imports from app/)
├── app/                 # Main application package
│   ├── __init__.py      # Package initialization
│   ├── main.py          # FastAPI application factory
│   ├── api/             # API routes and endpoints
│   │   ├── __init__.py
│   │   └── routes.py    # FastAPI route handlers
│   ├── core/            # Core application configuration
│   │   ├── __init__.py
│   │   └── config.py    # Configuration settings
│   ├── models/          # Data models and schemas
│   │   ├── __init__.py
│   │   └── schemas.py   # Pydantic data models
│   ├── services/        # Business logic layer
│   │   ├── __init__.py
│   │   └── tunnel_service.py  # Tunnel management logic
│   └── utils/           # Utility functions
│       ├── __init__.py
│       └── helpers.py   # Helper functions and utilities
├── requirements.txt     # Python dependencies
├── start.sh            # Server startup script
├── templates/          # Jinja2 templates
│   └── dashboard.html  # HTML dashboard template
└── static/            # Static web assets
    ├── css/           # CSS stylesheets
    └── js/            # JavaScript files
```
        └── dashboard.js # Dashboard JavaScript
```

## Features

- **Interactive Web Dashboard**: Modern, responsive UI built with Tailwind CSS
- **RESTful API**: Full REST API for tunnel management
- **Real-time Status**: Live tunnel status monitoring with auto-refresh
- **Tunnel Operations**: Start, stop, and replace VPN tunnels
- **Memory Monitoring**: Track container memory usage
- **Geographic Info**: Display entry and exit point locations
```json
{
  "message": "VPN Orchestrator API",
  "version": "1.0.0"
}
```

### `POST /start`
**Description**: Start VPN tunnel(s) with optional build and config update flags  
**Request Body**:
```json
{
  "tunnel_id": "0",          // String: single ID or range like "0-4" (default: "0")
  "build": false,            // Boolean: force rebuild containers (default: false)
  "update_configs": false    // Boolean: download fresh configs (default: false)
}
```
**Returns**:
```json
{
  "status": "success",
  "tunnel_id": "0",
  "output": "Script execution output..."
}
```

### `POST /stop`
**Description**: Stop VPN tunnel(s)  
**Request Body**:
```json
{
  "tunnel_id": "0"    // String: tunnel ID or "all" to stop all tunnels
}
```
**Returns**:
```json
{
  "status": "success",
  "tunnel_id": "0",
  "output": "Script execution output..."
}
```

### `GET /status`
**Description**: Get detailed status of VPN tunnels  
**Query Parameters**:
- `tunnel_ids` (optional): List of tunnel IDs to filter by
- Example: `/status?tunnel_ids=0&tunnel_ids=1&tunnel_ids=2`

**Returns**:
```json
{
  "tunnels": [
    {
      "tunnel_id": 0,
      "tunnel": "LLUSTR[0]",
      "port": "1080",
      "status": "up",
      "time_alive": "01:23:45",
      "entrypoint_ip": "45.137.77.1",
      "entrypoint": "United States",
      "exitpoint_ip": "192.168.1.100",
      "exitpoint": "US",
      "memory": "45.67MB"
    }
  ],
  "total_memory_mb": 45.67,
  "count": 1
}
```

### `POST /replace`
**Description**: Replace one tunnel with another (atomic stop/start operation)  
**Request Body**:
```json
{
  "stop_tunnel": 0,     // Integer: tunnel ID to stop
  "start_tunnel": 5     // Integer: tunnel ID to start
}
```
**Returns**:
```json
{
  "status": "success",
  "stopped_tunnel": 0,
  "started_tunnel": 5,
  "stop_output": "Stop script output...",
  "start_output": "Start script output..."
}
```

### `GET /docs`
**Description**: Get this API documentation as markdown  
**Returns**: Raw markdown content of this documentation file

## Status Field Explanations

- **tunnel_id**: Numeric identifier for the tunnel
- **tunnel**: Display name in format "LLUSTR[ID]"
- **port**: SOCKS5 proxy port (starting from 1080)
- **status**: "up" or "down"
- **time_alive**: Uptime in "HH:MM:SS" or "Xd HH:MM:SS" format
- **entrypoint_ip**: VPN server IP address from config file
- **entrypoint**: VPN server country
- **exitpoint_ip**: Public IP visible to websites
- **exitpoint**: Country code where traffic exits
- **memory**: Container memory usage with "MB" suffix

## Example Usage

```bash
# Start tunnel 0 with fresh configs
curl -X POST http://localhost:8000/start \
  -H "Content-Type: application/json" \
  -d '{"tunnel_id": "0", "update_configs": true}'

# Get status of specific tunnels
curl "http://localhost:8000/status?tunnel_ids=0&tunnel_ids=1"

# Replace tunnel 0 with tunnel 5
curl -X POST http://localhost:8000/replace \
  -H "Content-Type: application/json" \
  -d '{"stop_tunnel": 0, "start_tunnel": 5}'

# Stop all tunnels
curl -X POST http://localhost:8000/stop \
  -H "Content-Type: application/json" \
  -d '{"tunnel_id": "all"}'
```
