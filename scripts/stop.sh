#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Change to the parent directory (project root)
cd "$SCRIPT_DIR/.."

if [ -z "$1" ]; then
    echo "Usage: ./scripts/stop.sh <ID|all>"
    echo "Examples:"
    echo "  ./scripts/stop.sh 0     
    echo "  ./scripts/stop.sh all   
    echo
    echo "Currently running tunnels:"
    
    
    CONTAINERS=$(docker ps --filter "name=passage-" --format "{{.Names}}")
    
    if [ -z "$CONTAINERS" ]; then
        echo "  No active tunnels found."
    else
        for CONTAINER in $CONTAINERS; do
            CONFIG_ID=$(echo $CONTAINER | sed 's/.*-//')
            PORT=$(docker port $CONTAINER 1080/tcp | cut -d ':' -f 2)
            echo "  $CONFIG_ID (port $PORT)"
        done
    fi
    
    exit 1
fi


if [ "$1" = "all" ]; then
    echo "Stopping all tunnels..."
    
    
    CONTAINERS=$(docker ps -q --filter "name=passage-")
    
    if [ -z "$CONTAINERS" ]; then
        echo "No active tunnels found."
        exit 0
    fi
    
    
    for CONTAINER in $(docker ps --format "{{.Names}}" --filter "name=passage-"); do
        CONFIG_NUM=$(echo $CONTAINER | sed 's/.*-//')
        PROJECT="nordhell-$CONFIG_NUM"
        echo "Stopping project $PROJECT..."
        COMPOSE_PROJECT_NAME=$PROJECT docker compose down
    done
    
    echo "All tunnels stopped."
else
    
    CONFIG_NUM=$1
    CONTAINER_NAME="passage-$CONFIG_NUM"
    
    
    if ! docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
        echo "Error: tunnel for config $CONFIG_NUM is not running."
        exit 1
    fi
    
    
    echo "Stopping VPN tunnel for config $CONFIG_NUM..."
    COMPOSE_PROJECT_NAME="nordhell-$CONFIG_NUM" docker compose down
    
    echo "tunnel $CONTAINER_NAME stopped."
fi
