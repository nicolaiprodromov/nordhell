# ██████████████████████████████████████████████████████████████████████████████
# █                                                                            █
# █   ███╗   ██╗ ██████╗ ██████╗ ██████╗     ██╗  ██╗███████╗██╗     ██╗       █
# █   ████╗  ██║██╔═══██╗██╔══██╗██╔══██╗    ██║  ██║██╔════╝██║     ██║       █
# █   ██╔██╗ ██║██║   ██║██████╔╝██║  ██║    ███████║█████╗  ██║     ██║       █
# █   ██║╚██╗██║██║   ██║██╔══██╗██║  ██║    ██╔══██║██╔══╝  ██║     ██║       █
# █   ██║ ╚████║╚██████╔╝██║  ██║██████╔╝    ██║  ██║███████╗███████╗███████╗  █
# █   ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝  █
# █                                                                            █   
# ██████████████████████████████████████████████████████████████████████████████
# Default recipe - show available commands
default:
    @just --list

# Start a single VPN tunnel or range (e.g., just start 0 or just start 0-4)
start config='0' *flags='':
    @echo "Starting VPN tunnel(s) for config: {{config}}"
    ./scripts/start.sh {{flags}} {{config}}

# Start with forced rebuild
rebuild config='0' *flags='':
    @echo "Starting VPN tunnel(s) with forced rebuild: {{config}}"
    ./scripts/start.sh --build {{flags}} {{config}}

# Start with fresh VPN configs download
fresh config='0' *flags='':
    @echo "Downloading fresh VPN configs and starting: {{config}}"
    ./scripts/start.sh --update-configs {{flags}} {{config}}

# Start with fresh configs AND rebuild
fresh-rebuild config='0' *flags='':
    @echo "Downloading fresh configs, rebuilding, and starting: {{config}}"
    ./scripts/start.sh --update-configs --build {{flags}} {{config}}

# Stop a specific tunnel or all tunnels (e.g., just stop 0 or just stop all)
stop target='':
    #!/usr/bin/env bash
    if [ -z "{{target}}" ]; then
        echo "Usage: just stop <ID|all>"
        echo "Examples:"
        echo "  just stop 0     # Stop tunnel [0]"
        echo "  just stop all   # Stop all tunnels"
        ./scripts/stop.sh
    else
        ./scripts/stop.sh {{target}}
    fi

# Show status of all running tunnels
status:
    @./scripts/status.sh

# Alias for status
st: status

# Download/update NordVPN configuration files
update-configs:
    @echo "Downloading NordVPN configurations..."
    python3 utils/download_nordvpn_configs.py --output ./vpn-configs

# Run proxy tests on all active tunnels
test:
    @./scripts/test_proxies.sh

# Check Docker containers (raw docker ps output)
ps:
    @docker ps --filter "name=passage-" --format "table {{{{.Names}}\t{{{{.Status}}\t{{{{.Ports}}"

# View logs for a specific tunnel (e.g., just logs 0)
logs tunnel *flags='':
    @docker logs {{flags}} passage-{{tunnel}}

# Follow logs for a specific tunnel (e.g., just follow 0)
follow tunnel:
    @docker logs -f passage-{{tunnel}}

# Show last 50 lines of logs for a tunnel
tail tunnel:
    @docker logs --tail 50 passage-{{tunnel}}

# Inspect a specific tunnel container
inspect tunnel:
    @docker inspect passage-{{tunnel}}

# Execute a command in a running tunnel container
exec tunnel *cmd:
    @docker exec -it passage-{{tunnel}} {{cmd}}

# Get a shell in a running tunnel container
shell tunnel:
    @docker exec -it passage-{{tunnel}} /bin/bash

# Show memory usage for all tunnels
mem:
    @docker stats --no-stream --format "table {{{{.Name}}}}\t{{{{.MemUsage}}}}\t{{{{.CPUPerc}}}}" $(docker ps -q --filter "name=passage-")

# Show network stats for all tunnels
net:
    @docker stats --no-stream --format "table {{{{.Name}}}}\t{{{{.NetIO}}}}" $(docker ps -q --filter "name=passage-")

# Clean up stopped containers and unused images
clean:
    @echo "Cleaning up stopped containers..."
    @docker container prune -f --filter "label=com.docker.compose.project=nordhell*"
    @echo "Cleaning up unused images..."
    @docker image prune -f

# Deep clean - remove all llustr containers and images (WARNING: stops everything)
deep-clean:
    @echo "WARNING: This will stop and remove all LLUSTR tunnels and images!"
    @read -p "Are you sure? (y/N) " -n 1 -r; echo; \
    if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
        echo "Stopping all tunnels..."; \
        ./scripts/stop.sh all || true; \
        echo "Removing llustr images..."; \
        docker images --filter "reference=passage-*" -q | xargs -r docker rmi -f; \
        echo "Deep clean complete!"; \
    else \
        echo "Cancelled."; \
    fi

# Check for .env file and validate setup
check-env:
    #!/usr/bin/env bash
    if [ ! -f .env ]; then
        echo "ERROR: .env file not found!"
        echo "Please create a .env file with:"
        echo "  VPN_USERNAME=your_username"
        echo "  VPN_PASSWORD=your_password"
        exit 1
    fi
    
    if ! grep -q "VPN_USERNAME" .env || ! grep -q "VPN_PASSWORD" .env; then
        echo "ERROR: .env file missing VPN_USERNAME or VPN_PASSWORD"
        exit 1
    fi
    
    echo "✓ .env file configured correctly"

# Check if VPN configs exist
check-configs:
    #!/usr/bin/env bash
    if [ ! -d "vpn-configs" ] || [ -z "$(ls -A vpn-configs/*.ovpn 2>/dev/null)" ]; then
        echo "WARNING: No VPN configurations found!"
        echo "Run: just update-configs"
        exit 1
    fi
    
    config_count=$(ls -1 vpn-configs/*.ovpn 2>/dev/null | wc -l)
    echo "✓ Found $config_count VPN configuration files"

# Validate full setup
check: check-env check-configs
    @echo "✓ All setup checks passed!"

# Quick start - check setup and start tunnel 0
quick: check
    @just start 0

# Start multiple tunnels in range (e.g., just range 0 4 starts 0-4)
range start end *flags='':
    @just start {{start}}-{{end}} {{flags}}

# Restart a specific tunnel
restart tunnel:
    @echo "Restarting tunnel {{tunnel}}..."
    @just stop {{tunnel}}
    @sleep 2
    @just start {{tunnel}}

# Restart a tunnel with rebuild
restart-rebuild tunnel:
    @echo "Restarting tunnel {{tunnel}} with rebuild..."
    @just stop {{tunnel}}
    @sleep 2
    @just rebuild {{tunnel}}

# Show detailed info about a specific tunnel
info tunnel:
    #!/usr/bin/env bash
    container="passage-{{tunnel}}"
    
    if ! docker ps -q --filter "name=$container" | grep -q .; then
        echo "Error: Tunnel {{tunnel}} is not running"
        exit 1
    fi
    
    echo "=== Tunnel {{tunnel}} Info ==="
    echo ""
    echo "Container: $container"
    echo "Status: $(docker inspect -f '{{{{.State.Status}}}}' $container)"
    echo "Started: $(docker inspect -f '{{{{.State.StartedAt}}}}' $container)"
    echo "Port: $(docker port $container 1080/tcp | cut -d ':' -f 2)"
    echo ""
    echo "=== VPN Connection ==="
    docker exec $container ip addr show tun0 2>/dev/null || echo "VPN interface not found"
    echo ""
    echo "=== Recent Logs ==="
    docker logs --tail 10 $container

# Test a specific proxy port
test-port port:
    @echo "Testing proxy on port {{port}}..."
    @curl -x socks5h://localhost:{{port}} https://api.ipify.org?format=json

# Get exit IP for a specific tunnel
exit-ip tunnel:
    #!/usr/bin/env bash
    port=$(docker port passage-{{tunnel}} 1080/tcp | cut -d ':' -f 2)
    curl -s --socks5 127.0.0.1:$port https://ipinfo.io/json | jq -r '.ip // "Unknown"'

# Show all exit IPs for running tunnels
exit-ips:
    #!/usr/bin/env bash
    echo "Fetching exit IPs for all tunnels..."
    for container in $(docker ps --filter "name=passage-" --format "{{{{.Names}}"); do
        tunnel_id=$(echo $container | sed 's/.*-//')
        port=$(docker port $container 1080/tcp | cut -d ':' -f 2)
        ip=$(curl -s --max-time 5 --socks5 127.0.0.1:$port https://api.ipify.org?format=json | jq -r '.ip // "Timeout"')
        echo "Tunnel $tunnel_id (port $port): $ip"
    done

# Start the web server (if implemented)
server:
    @echo "Starting VPN Orchestrator API server..."
    @cd server && ./start.sh

# List available VPN configs with details
list-configs:
    #!/usr/bin/env bash
    echo "Available VPN Configurations:"
    echo "============================="
    ls -1 vpn-configs/*.ovpn | while read -r config; do
        filename=$(basename "$config")
        id=$(echo "$filename" | grep -oP '^\d+')
        server=$(echo "$filename" | sed 's/^[0-9]*-//' | sed 's/.tcp.ovpn//')
        echo "[$id] $server"
    done

# Count running tunnels
count:
    @docker ps --filter "name=passage-" --format "{{{{.Names}}}}" | wc -l | xargs echo "Running tunnels:"

# Export proxy settings for current shell (prints commands to eval)
export tunnel='0':
    #!/usr/bin/env bash
    port=$(docker port passage-{{tunnel}} 1080/tcp 2>/dev/null | cut -d ':' -f 2)
    if [ -z "$port" ]; then
        echo "Error: Tunnel {{tunnel}} is not running"
        exit 1
    fi
    echo "export http_proxy=socks5h://localhost:$port"
    echo "export https_proxy=socks5h://localhost:$port"
    echo "# Run: eval \$(just export {{tunnel}})"

# Health check for a specific tunnel
health tunnel:
    @docker inspect --format='{{{{.State.Health.Status}}}}' passage-{{tunnel}} 2>/dev/null || echo "No health status available"

# Show resource usage summary
resources:
    @echo "=== LLUSTR Tunnels Resource Usage ==="
    @docker stats --no-stream --format "table {{{{.Name}}}}\t{{{{.CPUPerc}}}}\t{{{{.MemUsage}}}}\t{{{{.NetIO}}}}\t{{{{.BlockIO}}}}" $(docker ps -q --filter "name=passage-")

# Watch status in real-time (requires watch command)
watch-status:
    @watch -n 2 -c './scripts/status.sh'

# Show docker-compose config for a tunnel
show-config tunnel:
    @VPN_CONFIG_NUM={{tunnel}} SOCKS_PORT=1080 COMPOSE_PROJECT_NAME=nordhell-{{tunnel}} docker compose config

# Validate docker-compose configuration
validate:
    @docker compose config -q && echo "✓ docker-compose.yml is valid"

# Show help with detailed examples
help:
        @printf '%s\n' \
            " ██████████████████████████████████████████████████████████████████████████████" \
            " █                                                                            █" \
            " █   ███╗   ██╗ ██████╗ ██████╗ ██████╗     ██╗  ██╗███████╗██╗     ██╗       █" \
            " █   ████╗  ██║██╔═══██╗██╔══██╗██╔══██╗    ██║  ██║██╔════╝██║     ██║       █" \
            " █   ██╔██╗ ██║██║   ██║██████╔╝██║  ██║    ███████║█████╗  ██║     ██║       █" \
            " █   ██║╚██╗██║██║   ██║██╔══██╗██║  ██║    ██╔══██║██╔══╝  ██║     ██║       █" \
            " █   ██║ ╚████║╚██████╔╝██║  ██║██████╔╝    ██║  ██║███████╗███████╗███████╗  █" \
            " █   ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝  █" \
            " █                                                                            █   " \
            " ██████████████████████████████████████████████████████████████████████████████" \
            "" \
            "Quick Start:" \
            "  just check          - Validate setup" \
            "  just start 0        - Start tunnel 0" \
            "  just status         - Show all tunnels" \
            "  just stop 0         - Stop tunnel 0" \
            "" \
            "Starting Passages:" \
            "  just start 5              - Start passage 5" \
            "  just start 0-4            - Start passages 0 through 4" \
            "  just rebuild 5            - Force rebuild and start" \
            "  just fresh 5              - Download fresh configs and start" \
            "  just fresh-rebuild 5      - Fresh configs + rebuild + start" \
            "" \
            "Monitoring:" \
            "  just status               - Show all passage status" \
            "  just logs 0               - View logs for passage 0" \
            "  just follow 0             - Follow logs in real-time" \
            "  just info 0               - Detailed info about passage 0" \
            "  just exit-ips             - Show exit IPs for all passages" \
            "" \
            "Testing:" \
            "  just test                 - Run automated tests" \
            "  just test-port 1080       - Test specific proxy port" \
            "  just exit-ip 0            - Get exit IP for passage 0" \
            "" \
            "Maintenance:" \
            "  just clean                - Clean up stopped containers" \
            "  just restart 0            - Restart passage 0" \
            "  just update-configs       - Download fresh VPN configs" \
            "" \
            "For more commands: just --list"
