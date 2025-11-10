```
██████████████████████████████████████████████████████████████████████████████
█                                                                            █
█   ███╗   ██╗ ██████╗ ██████╗ ██████╗     ██╗  ██╗███████╗██╗     ██╗       █
█   ████╗  ██║██╔═══██╗██╔══██╗██╔══██╗    ██║  ██║██╔════╝██║     ██║       █
█   ██╔██╗ ██║██║   ██║██████╔╝██║  ██║    ███████║█████╗  ██║     ██║       █
█   ██║╚██╗██║██║   ██║██╔══██╗██║  ██║    ██╔══██║██╔══╝  ██║     ██║       █
█   ██║ ╚████║╚██████╔╝██║  ██║██████╔╝    ██║  ██║███████╗███████╗███████╗  █
█   ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝  █
█                                                                            █   
██████████████████████████████████████████████████████████████████████████████
```

a scalable system for managing multiple concurrent vpn tunnel/passages with socks5 proxies using docker containers

## setup

1. download your nordvpn configuration files into `vpn-configs/` directory. You can get them from [nordvpn.com](https://nordvpn.com/servers/tools/) or use the provided script:

   ```bash
   mkdir -p vpn-configs
   wget -O - https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip | unzip -j - 'ovpn_udp/*.ovpn' -d vpn-configs/
   ```

2. make `docker-compose.yml`:

   ```yaml
   name: nordhell
   services:
   nordhell-passage:
      build:
         context: .
         args:
         - VPN_CONFIG_NUM=${VPN_CONFIG_NUM:-0}
      image: nicolaiprodromov/nordhell-passage:latest
      container_name: nordhell-passage-${VPN_CONFIG_NUM:-0}
      networks:
         - nordhell-network
      env_file:
         - .env
      environment:
         - VPN_CONFIG_NUM=${VPN_CONFIG_NUM:-0}
      tmpfs:
         - /run/vpn-credentials:size=1M,mode=700,noexec,nosuid
      security_opt:
         - no-new-privileges:true
         - seccomp:unconfined
      cap_add:
         - NET_ADMIN
         - SYS_MODULE
      devices:
         - /dev/net/tun:/dev/net/tun
      ports:
         - "${SOCKS_PORT:-1080}:1080"
      restart: unless-stopped
      init: true
      dns:
         - 1.1.1.1
         - 8.8.8.8
      healthcheck:
         test: ["CMD", "sh", "-c", "nc -z 127.0.0.1 1080 && ip link show tun0"]
         interval: 30s
         timeout: 5s
         retries: 3
         start_period: 10s

   networks:
   nordhell-network:
      name: nordhell-network
   ```

3. copy your service credentials into a `.env` file:
   ```
   VPN_USERNAME=your_nordvpn_username
   VPN_PASSWORD=your_nordvpn_password
   ```
   
4. run these two commands:

   ```bash
   export VPN_CONFIG_NUM=0
   docker compose build --build-arg VPN_CONFIG_NUM=${VPN_CONFIG_NUM}
   docker compose up -d
   ```

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

### using the SOCKS5 Proxy

each VPN tunnel exposes a SOCKS5 proxy on a different port, starting from 1080. to use with curl:

```bash
export http_proxy=socks5h://localhost:1080
export https_proxy=socks5h://localhost:1080
curl https://ipinfo.io
```


