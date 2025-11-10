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
just help

Quick Start:
  just check          - Validate setup
  just start 0        - Start passage 0
  just status         - Show all passages
  just stop 0         - Stop passage 0

Starting passages:
  just start 5              - Start passage 5
  just start 0-4            - Start passages 0 through 4
  just rebuild 5            - Force rebuild and start
  just fresh 5              - Download fresh configs and start
  just fresh-rebuild 5      - Fresh configs + rebuild + start

Monitoring:
  just status               - Show all passage status
  just logs 0               - View logs for passage 0
  just follow 0             - Follow logs in real-time
  just info 0               - Detailed info about passage 0
  just exit-ips             - Show exit IPs for all passages

Testing:
  just test                 - Run automated tests
  just test-port 1080       - Test specific proxy port
  just exit-ip 0            - Get exit IP for passage 0

Maintenance:
  just clean                - Clean up stopped containers
  just restart 0            - Restart passage 0
  just update-configs       - Download fresh VPN configs

For more commands: just --list
```

### using the SOCKS5 proxies

```bash
export http_proxy=socks5h://localhost:2000
export https_proxy=socks5h://localhost:2000
curl https://ipinfo.io
```


