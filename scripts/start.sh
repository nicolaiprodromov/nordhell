#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Change to the parent directory (project root)
cd "$SCRIPT_DIR/.."

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

download_fresh_configs() {
    local UPDATE_CONFIGS=$1
    local FORCE_DOWNLOAD=false
    
    
    if [ ! -d "vpn-configs" ] || [ -z "$(ls -A vpn-configs/*.ovpn 2>/dev/null)" ]; then
        echo "No VPN configurations found. Will download configs regardless of --update-configs flag."
        FORCE_DOWNLOAD=true
    fi
    
    
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


calculate_checksums() {
    local VPN_CONFIG_NUM=$1
    local FORMATTED_NUM=$(printf "%03d" $VPN_CONFIG_NUM)
    local CONFIG_FILE=$(ls -1 vpn-configs/${FORMATTED_NUM}-*.tcp.ovpn 2>/dev/null)
    
    mkdir -p .llustr_checksums
    
    sha256sum Dockerfile configs/sockd.conf scripts/entrypoint.sh .env "$CONFIG_FILE" 2>/dev/null > .llustr_checksums/${VPN_CONFIG_NUM}.sum.new
}

checksums_match() {
    local VPN_CONFIG_NUM=$1
    local CHECKSUM_FILE=".llustr_checksums/${VPN_CONFIG_NUM}.sum"
    local NEW_CHECKSUM_FILE=".llustr_checksums/${VPN_CONFIG_NUM}.sum.new"
    
    [ ! -f "$CHECKSUM_FILE" ] && return 1
    
    diff -q "$CHECKSUM_FILE" "$NEW_CHECKSUM_FILE" >/dev/null
    return $?
}


start_vpn_tunnel() {
    local VPN_CONFIG_NUM=$1
    local FORCE_BUILD=$2
    echo "===== Starting LLUSTR TNNL [$VPN_CONFIG_NUM] ====="
    
    local FORMATTED_NUM=$(printf "%03d" $VPN_CONFIG_NUM)
    
    local CONFIG_FILE=$(ls -1 vpn-configs/${FORMATTED_NUM}-*.tcp.ovpn 2>/dev/null)
    if [ -z "$CONFIG_FILE" ]; then
        echo "Error: No VPN config found for number $VPN_CONFIG_NUM"
        return 1
    fi
    
    local EXISTING_CONTAINER=$(docker ps -q -f name=nordhell-passage-${VPN_CONFIG_NUM})
    if [ ! -z "$EXISTING_CONTAINER" ]; then
        
        local CURRENT_PORT=$(docker port nordhell-passage-${VPN_CONFIG_NUM} 1080/tcp | cut -d ':' -f 2)
        echo "SOCKS5 proxy available at: localhost:${CURRENT_PORT}"
        return 0
    fi
    
    
    local USED_PORTS=$(docker ps --filter "name=nordhell-passage-" --format "{{.Ports}}" | grep -oP "0.0.0.0:\K\d+" || echo "")
    
    local PORT=${SOCKS_BASE_PORT:-1080}
    
    while echo "$USED_PORTS" | grep -q "$PORT"; do
        PORT=$((PORT + 1))
        
        if [ $PORT -gt ${SOCKS_MAX_PORT:-1180} ]; then
            echo "Warning: Reached port limit, restarting from ${SOCKS_BASE_PORT:-1080}"
            PORT=${SOCKS_BASE_PORT:-1080}
            break
        fi
    done
    
    export SOCKS_PORT=$PORT
    
    
    local COMPOSE_PROJECT_NAME="llustr-${VPN_CONFIG_NUM}"
    export COMPOSE_PROJECT_NAME
    
    export VPN_CONFIG_NUM
    
    calculate_checksums $VPN_CONFIG_NUM
    
    if [ "$FORCE_BUILD" = "true" ] || ! checksums_match $VPN_CONFIG_NUM; then
        echo "Building tunnel [$VPN_CONFIG_NUM]"
        if [ "$FORCE_BUILD" = "true" ]; then
            echo "Force build flag detected, ignoring cache"
            docker compose build --no-cache
        else
            docker compose build
        fi
        
        mv .llustr_checksums/${VPN_CONFIG_NUM}.sum.new .llustr_checksums/${VPN_CONFIG_NUM}.sum
    else
        echo "Skipping build - no changes detected since last build"
    fi
    
    docker compose up -d
    
    sleep 2
    
    if ! docker ps -q --filter "name=nordhell-passage-${VPN_CONFIG_NUM}" | grep -q .; then
        echo "Error: Failed to start VPN tunnel container."
        echo "Check docker logs with: docker compose -p $COMPOSE_PROJECT_NAME logs"
        return 1
    fi
    
    local SERVER_NAME=$(basename $CONFIG_FILE .tcp.ovpn)
    echo "-------------------------------------"
    echo "LLUSTR TNNL:"
    echo "  Container    : nordhell-passage-${VPN_CONFIG_NUM}"
    echo "  VPN Server   : ${SERVER_NAME}"
    echo "  SOCKS5 Proxy : localhost:${SOCKS_PORT}" 
    echo "  Project      : $COMPOSE_PROJECT_NAME"
    echo "-------------------------------------"
    return 0
}


FORCE_BUILD="false"
UPDATE_CONFIGS="false"
VPN_CONFIG=""

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

if [ -z "$VPN_CONFIG" ]; then
    VPN_CONFIG="0"
fi


download_fresh_configs "$UPDATE_CONFIGS"


if [[ "$VPN_CONFIG" =~ ^([0-9]+)-([0-9]+)$ ]]; then
    
    START_NUM=${BASH_REMATCH[1]}
    END_NUM=${BASH_REMATCH[2]} 
    
    if [ $START_NUM -gt $END_NUM ]; then
        echo "Error: Invalid range. Start number must be less than or equal to end number."
        exit 1
    fi 
    
    echo "Starting tunnels [$START_NUM-$END_NUM]"
    SUCCESS_COUNT=0
    FAIL_COUNT=0
    
    for VPN_CONFIG_NUM in $(seq $START_NUM $END_NUM); do
        if start_vpn_tunnel $VPN_CONFIG_NUM "$FORCE_BUILD"; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
        
        sleep 1
    done
    echo "Successfully started: $SUCCESS_COUNT tunnels"
    echo "Failed to start: $FAIL_COUNT tunnels"
    echo "Run './scripts/status.sh' to see all active tunnels"
    exit 0
else
    
    VPN_CONFIG_NUM=$VPN_CONFIG
    
    if ! [[ "$VPN_CONFIG_NUM" =~ ^[0-9]+$ ]]; then
        echo "Error: VPN config number must be a non-negative integer or a range (e.g., 0-4)"
        exit 1
    fi
    
    start_vpn_tunnel $VPN_CONFIG_NUM "$FORCE_BUILD"
    exit $?
fi
