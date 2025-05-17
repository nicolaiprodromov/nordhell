# LLUSTR Proxy

A Docker-based proxy system that uses NordVPN configurations for maintaining multiple proxy connections.

## Project Structure

- `Dockerfile` - Container configuration
- `docker-compose.yml` - Multi-container setup
- `download_nordvpn_configs.py` - Script for downloading NordVPN configuration files
- `sockd.conf` - Dante SOCKS proxy configuration
- `start.sh` - Container startup script
- `tests/` - Test files for the proxy functionality

## Usage

1. Clone this repository
2. Set up authentication information in auth.txt (not included in the repository)
3. Run `docker compose up` to start the proxy service

## Notes

VPN configuration files are stored in the vpn-configs directory but are excluded from the repository for security reasons.
