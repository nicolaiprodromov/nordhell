 ```
███╗   ██╗ ██████╗ ██████╗ ██████╗ ██╗  ██╗███████╗██╗     ██╗     
████╗  ██║██╔═══██╗██╔══██╗██╔══██╗██║  ██║██╔════╝██║     ██║     
██╔██╗ ██║██║   ██║██████╔╝██║  ██║███████║█████╗  ██║     ██║     
██║╚██╗██║██║   ██║██╔══██╗██║  ██║██╔══██║██╔══╝  ██║     ██║     
██║ ╚████║╚██████╔╝██║  ██║██████╔╝██║  ██║███████╗███████╗███████╗
╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝ 
a scalable vpn tunnel proxy orchestartor ══════════════════════════
```
## prerequisites

- docker running
- [just](https://github.com/casey/just)

## setup

1. clone this repository:

   ```bash
   git clone https://github.com/nicolaiprodromov/nordhell.git
   cd nordhell
   ```
2. download your nordvpn configuration files into `vpn-configs/`:

   ```bash
   python3 scripts/download_nordvpn_configs.py
   ```

3. copy your service credentials into a `.env` file:
   ```
   VPN_USERNAME=your_nordvpn_username
   VPN_PASSWORD=your_nordvpn_password
   SOCKS_BASE_PORT=2000
   SOCKS_MAX_PORT=2100
   ```
   
4. run `just start 0` to start the first passage.

## usage

```bash
Quick Start:
  just check          - Validate setup
  just start 0        - Start passage 0
  just status         - Show all passages
  just stop 0         - Stop passage 0

check                              # Validate full setup
check-configs                      # Check if VPN configs exist
check-env                          # Check for .env file and validate setup
clean                              # Clean up stopped containers and unused images
count                              # Count running tunnels
deep-clean                         # Deep clean - remove all llustr containers and images (WARNING: stops everything)
default                            # Default recipe - show available commands
exec tunnel *cmd                   # Execute a command in a running tunnel container
exit-ip tunnel                     # Get exit IP for a specific tunnel
exit-ips                           # Show all exit IPs for running tunnels
export tunnel='0'                  # Export proxy settings for current shell (prints commands to eval)
follow tunnel                      # Follow logs for a specific tunnel (e.g., just follow 0)
fresh config='0' *flags=''         # Start with fresh VPN configs download
fresh-rebuild config='0' *flags='' # Start with fresh configs AND rebuild
health tunnel                      # Health check for a specific tunnel
help                               # Show help with detailed examples
info tunnel                        # Show detailed info about a specific tunnel
inspect tunnel                     # Inspect a specific tunnel container
list-configs                       # List available VPN configs with details
logs tunnel *flags=''              # View logs for a specific tunnel (e.g., just logs 0)
mem                                # Show memory usage for all tunnels
net                                # Show network stats for all tunnels
ps                                 # Check Docker containers (raw docker ps output)
quick                              # Quick start - check setup and start tunnel 0
range start end *flags=''          # Start multiple tunnels in range (e.g., just range 0 4 starts 0-4)
rebuild config='0' *flags=''       # Start with forced rebuild
resources                          # Show resource usage summary
restart tunnel                     # Restart a specific tunnel
restart-rebuild tunnel             # Restart a tunnel with rebuild
server                             # Start the web server (if implemented)
shell tunnel                       # Get a shell in a running tunnel container
show-config tunnel                 # Show docker-compose config for a tunnel
st                                 # Alias for status
start config='0' *flags=''         # Start a single VPN tunnel or range (e.g., just start 0 or just start 0-4)
status                             # Show status of all running tunnels
stop target=''                     # Stop a specific tunnel or all tunnels (e.g., just stop 0 or just stop all)
tail tunnel                        # Show last 50 lines of logs for a tunnel
test                               # Run proxy tests on all active tunnels
test-port port                     # Test a specific proxy port
update-configs                     # Download/update NordVPN configuration files
validate                           # Validate docker-compose configuration
watch-status                       # Watch status in real-time (requires watch command)

```

### using the SOCKS5 proxies

```bash
export http_proxy=socks5h://localhost:2000
export https_proxy=socks5h://localhost:2000
curl https://ipinfo.io
```


