#!/bin/bash
# start.sh - Script to build and run the VPN container with a specific config

# Function to download fresh VPN configurations
download_fresh_configs() {
    local UPDATE_CONFIGS=$1
    local FORCE_DOWNLOAD=false
    
    # Check if vpn-configs directory exists and has .ovpn files
    if [ ! -d "vpn-configs" ] || [ -z "$(ls -A vpn-configs/*.ovpn 2>/dev/null)" ]; then
        echo "No VPN configurations found. Will download configs regardless of --update-configs flag."
        FORCE_DOWNLOAD=true
    fi
    
    # Download configs if explicitly requested or if no configs exist
    if [ "$UPDATE_CONFIGS" = "true" ] || [ "$FORCE_DOWNLOAD" = "true" ]; then
        echo "Downloading NordVPN configurations..."
        if [ -f "utils/download_nordvpn_configs.py" ]; then
            python3 utils/download_nordvpn_configs.py --output ./vpn-configs
            if [ $? -ne 0 ]; then
                echo "Warning: Failed to download VPN configurations."
                if [ "$FORCE_DOWNLOAD" = "true" ]; then
                    echo "Error: No existing VPN configurations found and failed to download. Exiting."
                    exit 1
                else
                    echo "Using existing configs."
                fi
            else
                echo "VPN configurations successfully updated."
            fi
        else
            echo "Warning: download_nordvpn_configs.py script not found in utils directory."
            if [ "$FORCE_DOWNLOAD" = "true" ]; then
                echo "Error: No existing VPN configurations found and download script missing. Exiting."
                exit 1
            fi
        fi
    fi
}

# Function to calculate checksums of relevant files
calculate_checksums() {
    local VPN_CONFIG_NUM=$1
    local FORMATTED_NUM=$(printf "%03d" $VPN_CONFIG_NUM)
    local CONFIG_FILE=$(ls -1 vpn-configs/${FORMATTED_NUM}-*.tcp.ovpn 2>/dev/null)
    # Create checksums directory if it doesn't exist
    mkdir -p .llustr_checksums
    # Calculate checksums for relevant files
    sha256sum Dockerfile auth.txt configs/sockd.conf scripts/entrypoint.sh "$CONFIG_FILE" 2>/dev/null > .llustr_checksums/${VPN_CONFIG_NUM}.sum.new
}
# Function to compare checksums
checksums_match() {
    local VPN_CONFIG_NUM=$1
    local CHECKSUM_FILE=".llustr_checksums/${VPN_CONFIG_NUM}.sum"
    local NEW_CHECKSUM_FILE=".llustr_checksums/${VPN_CONFIG_NUM}.sum.new"
    # If no previous checksum file exists, return false (1)
    [ ! -f "$CHECKSUM_FILE" ] && return 1
    # Compare checksums
    diff -q "$CHECKSUM_FILE" "$NEW_CHECKSUM_FILE" >/dev/null
    return $?
}

# Function to start a single VPN tunnel
start_vpn_tunnel() {
    local VPN_CONFIG_NUM=$1
    local FORCE_BUILD=$2
    echo "===== Starting LLUSTR TNNL [$VPN_CONFIG_NUM] ====="
    # Format the number with leading zeros
    local FORMATTED_NUM=$(printf "%03d" $VPN_CONFIG_NUM)
    # Check if the config file exists
    local CONFIG_FILE=$(ls -1 vpn-configs/${FORMATTED_NUM}-*.tcp.ovpn 2>/dev/null)
    if [ -z "$CONFIG_FILE" ]; then
        echo "Error: No VPN config found for number $VPN_CONFIG_NUM"
        return 1
    fi
    # Check if container for this config is already running
    local EXISTING_CONTAINER=$(docker ps -q -f name=llustr-proxy-tunnel-${VPN_CONFIG_NUM})
    if [ ! -z "$EXISTING_CONTAINER" ]; then
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
    # Set a unique project name based on VPN config number
    # This ensures each VPN tunnel gets its own isolated Docker Compose project
    local COMPOSE_PROJECT_NAME="llustr-${VPN_CONFIG_NUM}"
    export COMPOSE_PROJECT_NAME
    # Export the VPN config number for docker compose
    export VPN_CONFIG_NUM
    # Calculate checksums for relevant files
    calculate_checksums $VPN_CONFIG_NUM
    # Skip build unless forced or checksums don't match
    if [ "$FORCE_BUILD" = "true" ] || ! checksums_match $VPN_CONFIG_NUM; then
        echo "Building tunnel [$VPN_CONFIG_NUM]"
        if [ "$FORCE_BUILD" = "true" ]; then
            echo "Force build flag detected, ignoring cache"
            docker compose build --no-cache
        else
            docker compose build
        fi
        # Save new checksums
        mv .llustr_checksums/${VPN_CONFIG_NUM}.sum.new .llustr_checksums/${VPN_CONFIG_NUM}.sum
    else
        echo "Skipping build - no changes detected since last build"
    fi
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
    echo "LLUSTR TNNL:"
    echo "  Container    : llustr-proxy-tunnel-${VPN_CONFIG_NUM}"
    echo "  VPN Server   : ${SERVER_NAME}"
    echo "  SOCKS5 Proxy : localhost:${SOCKS_PORT}" 
    echo "  Project      : $COMPOSE_PROJECT_NAME"
    echo "-------------------------------------"
    return 0
}

# Parse command line arguments
FORCE_BUILD="false"
UPDATE_CONFIGS="false"
VPN_CONFIG=""
# Process arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            FORCE_BUILD="true"
            shift
            ;;
        --update-configs)
            UPDATE_CONFIGS="true"
            shift
            ;;
        *)
            VPN_CONFIG="$1"
            shift
            ;;
    esac
done
# If no VPN config specified, use 0
if [ -z "$VPN_CONFIG" ]; then
    VPN_CONFIG="0"
fi

# Download fresh configs if requested
download_fresh_configs "$UPDATE_CONFIGS"

# Check for range syntax (e.g., 0-4)
if [[ "$VPN_CONFIG" =~ ^([0-9]+)-([0-9]+)$ ]]; then
    # Extract start and end of range
    START_NUM=${BASH_REMATCH[1]}
    END_NUM=${BASH_REMATCH[2]} 
    # Validate range
    if [ $START_NUM -gt $END_NUM ]; then
        echo "Error: Invalid range. Start number must be less than or equal to end number."
        exit 1
    fi 
    # Start VPN tunnels for each config in the range
    echo "Starting tunnels [$START_NUM-$END_NUM]"
    SUCCESS_COUNT=0
    FAIL_COUNT=0
    # Loop through the range and start each tunnel
    for VPN_CONFIG_NUM in $(seq $START_NUM $END_NUM); do
        if start_vpn_tunnel $VPN_CONFIG_NUM "$FORCE_BUILD"; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
        # Add a small delay between starts to avoid port conflicts
        sleep 1
    done
    echo "Successfully started: $SUCCESS_COUNT tunnels"
    echo "Failed to start: $FAIL_COUNT tunnels"
    echo "Run './status.sh' to see all active tunnels"
    exit 0
else
    # Single config number
    VPN_CONFIG_NUM=$VPN_CONFIG
    # Validate that the input is a number
    if ! [[ "$VPN_CONFIG_NUM" =~ ^[0-9]+$ ]]; then
        echo "Error: VPN config number must be a non-negative integer or a range (e.g., 0-4)"
        exit 1
    fi
    # Start a single VPN tunnel
    start_vpn_tunnel $VPN_CONFIG_NUM "$FORCE_BUILD"
    exit $?
fi
