#!/bin/bash
# llustr.sh - Script to build and run the VPN container with a specific config

# Function to start a single VPN tunnel
start_vpn_tunnel() {
    local VPN_CONFIG_NUM=$1
    echo "===== Starting VPN Tunnel for Config #$VPN_CONFIG_NUM ====="
    
    # Format the number with leading zeros
    local FORMATTED_NUM=$(printf "%03d" $VPN_CONFIG_NUM)

    # Check if the config file exists
    local CONFIG_FILE=$(ls -1 vpn-configs/${FORMATTED_NUM}-*.tcp.ovpn 2>/dev/null)
    if [ -z "$CONFIG_FILE" ]; then
        echo "Error: No VPN config found for number $VPN_CONFIG_NUM"
        return 1
    fi

    echo "Using VPN config: $CONFIG_FILE"

    # Check if container for this config is already running
    local EXISTING_CONTAINER=$(docker ps -q -f name=llustr-proxy-tunnel-${VPN_CONFIG_NUM})
    if [ ! -z "$EXISTING_CONTAINER" ]; then
        echo "Container llustr-proxy-tunnel-${VPN_CONFIG_NUM} is already running"
        
        # Get the port it's using
        local CURRENT_PORT=$(docker port llustr-proxy-tunnel-${VPN_CONFIG_NUM} 1080/tcp | cut -d ':' -f 2)
        echo "SOCKS5 proxy available at: localhost:${CURRENT_PORT}"
        return 0
    fi

    # Find the next available port starting from 1080
    # First, get all ports currently in use by llustr containers
    local USED_PORTS=$(docker ps --filter "name=llustr-proxy-tunnel-" --format "{{.Ports}}" | grep -oP "0.0.0.0:\K\d+" || echo "")

    # Start with port 1080
    local PORT=1080

    # Find the next available port
    while echo "$USED_PORTS" | grep -q "$PORT"; do
        PORT=$((PORT + 1))
        # Safety check to avoid infinite loop
        if [ $PORT -gt 1180 ]; then
            echo "Warning: Reached port limit, restarting from 1080"
            PORT=1080
            break
        fi
    done

    # Set the port for docker compose
    export SOCKS_PORT=$PORT
    echo "Using port $SOCKS_PORT for SOCKS proxy"

    # Set a unique project name based on VPN config number
    # This ensures each VPN tunnel gets its own isolated Docker Compose project
    local COMPOSE_PROJECT_NAME="llustr-${VPN_CONFIG_NUM}"
    export COMPOSE_PROJECT_NAME
    echo "Using Docker Compose project: $COMPOSE_PROJECT_NAME"

    # Export the VPN config number for docker compose
    export VPN_CONFIG_NUM

    # Rebuild the Docker image with the specified config
    echo "Building Docker image with config $VPN_CONFIG_NUM..."
    docker compose build

    # Start or restart the container
    echo "Starting the VPN container llustr-proxy-tunnel-${VPN_CONFIG_NUM} on port ${SOCKS_PORT}..."

    # Start the container
    docker compose up -d

    # Wait a moment for container to start
    sleep 2

    # Check if container started successfully
    if ! docker ps -q --filter "name=llustr-proxy-tunnel-${VPN_CONFIG_NUM}" | grep -q .; then
        echo "Error: Failed to start VPN tunnel container."
        echo "Check docker logs with: docker compose -p $COMPOSE_PROJECT_NAME logs"
        return 1
    fi

    # Show successful startup message
    local SERVER_NAME=$(basename $CONFIG_FILE .tcp.ovpn)
    echo "-------------------------------------"
    echo "VPN Tunnel Information:"
    echo "  Container: llustr-proxy-tunnel-${VPN_CONFIG_NUM}"
    echo "  VPN Server: ${SERVER_NAME}"
    echo "  SOCKS5 Proxy: localhost:${SOCKS_PORT}" 
    echo "  Project: $COMPOSE_PROJECT_NAME"
    echo "-------------------------------------"
    echo "To use with curl: export http_proxy=socks5h://localhost:${SOCKS_PORT}"
    echo "To use with wget: export https_proxy=socks5h://localhost:${SOCKS_PORT}"
    echo "To stop this tunnel: ./llustr-stop.sh ${VPN_CONFIG_NUM}"
    echo "-------------------------------------"
    
    return 0
}

# Parse command line arguments
ARG=${1:-0}

# Check for range syntax (e.g., 0-4)
if [[ "$ARG" =~ ^([0-9]+)-([0-9]+)$ ]]; then
    # Extract start and end of range
    START_NUM=${BASH_REMATCH[1]}
    END_NUM=${BASH_REMATCH[2]}
    
    # Validate range
    if [ $START_NUM -gt $END_NUM ]; then
        echo "Error: Invalid range. Start number must be less than or equal to end number."
        exit 1
    fi
    
    # Start VPN tunnels for each config in the range
    echo "Starting VPN tunnels for configs $START_NUM through $END_NUM..."
    SUCCESS_COUNT=0
    FAIL_COUNT=0
    
    for VPN_CONFIG_NUM in $(seq $START_NUM $END_NUM); do
        if start_vpn_tunnel $VPN_CONFIG_NUM; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
        # Add a small delay between starts to avoid port conflicts
        sleep 1
    done
    
    echo "===== Range Operation Complete ====="
    echo "Successfully started: $SUCCESS_COUNT tunnels"
    echo "Failed to start: $FAIL_COUNT tunnels"
    echo "Run './llustr-list.sh' to see all active tunnels"
    exit 0
else
    # Single config number
    VPN_CONFIG_NUM=$ARG
    
    # Validate that the input is a number
    if ! [[ "$VPN_CONFIG_NUM" =~ ^[0-9]+$ ]]; then
        echo "Error: VPN config number must be a non-negative integer or a range (e.g., 0-4)"
        exit 1
    fi
    
    # Start a single VPN tunnel
    start_vpn_tunnel $VPN_CONFIG_NUM
    exit $?
fi
