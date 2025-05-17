# LLUSTR Proxy

A Docker-based proxy system that uses NordVPN configurations for maintaining multiple SOCKS5 proxy connections through different VPN servers.

## Project Structure

- `Dockerfile` - Container configuration for the VPN proxy
- `docker-compose.yml` - Multi-container setup
- `download_nordvpn_configs.py` - Script for downloading NordVPN configuration files
- `sockd.conf` - Dante SOCKS proxy configuration
- `start.sh` - Container startup script
- `llustr.sh` - Script to start VPN tunnels with specific configs
- `llustr-list.sh` - Script to list all active VPN tunnels
- `llustr-stop.sh` - Script to stop specific or all VPN tunnels
- `tests/` - Test files for the proxy functionality

## Setup

1. Clone this repository
2. Set up authentication information in auth.txt (not included in the repository)
3. Make sure you have VPN configuration files in the vpn-configs directory

## Usage

### Starting VPN Tunnels

Start a VPN tunnel using a specific configuration:
```bash
./llustr.sh 29  # Start a tunnel with config #29 (numbered by filename prefix)
```

Start multiple VPN tunnels using a range:
```bash
./llustr.sh 0-4  # Start tunnels for configs 0, 1, 2, 3, and 4
```

### Managing VPN Tunnels

List all active VPN tunnels:
```bash
./llustr-list.sh
```

Stop a specific VPN tunnel:
```bash
./llustr-stop.sh 29  # Stop the tunnel using config #29
```

Stop all VPN tunnels:
```bash
./llustr-stop.sh all
```

### Using the SOCKS5 Proxy

Each VPN tunnel exposes a SOCKS5 proxy on a different port, starting from 1080. To use with curl:

```bash
export http_proxy=socks5h://localhost:1080
export https_proxy=socks5h://localhost:1080
curl https://ipinfo.io
```

## Notes

VPN configuration files are stored in the vpn-configs directory but are excluded from the repository for security reasons.

The system automatically assigns sequential ports starting from 1080 for each VPN tunnel.
