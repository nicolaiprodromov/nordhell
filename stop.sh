#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: ./stop.sh <ID|all>"
    echo "Examples:"
    echo "  ./stop.sh 0     
    echo "  ./stop.sh all   
    echo
    echo "Currently running tunnels:"
    
    
    CONTAINERS=$(docker ps --filter "name=llustr-proxy-tunnel-" --format "{{.Names}}")
    
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
    
    
    CONTAINERS=$(docker ps -q --filter "name=llustr-proxy-tunnel-")
    
    if [ -z "$CONTAINERS" ]; then
        echo "No active tunnels found."
        exit 0
    fi
    
    
    for CONTAINER in $(docker ps --format "{{.Names}}" --filter "name=llustr-proxy-tunnel-"); do
        CONFIG_NUM=$(echo $CONTAINER | sed 's/.*-//')
        PROJECT="llustr-$CONFIG_NUM"
        echo "Stopping project $PROJECT..."
        COMPOSE_PROJECT_NAME=$PROJECT docker compose down
    done
    
    echo "All tunnels stopped."
else
    
    CONFIG_NUM=$1
    CONTAINER_NAME="llustr-proxy-tunnel-$CONFIG_NUM"
    
    
    if ! docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
        echo "Error: tunnel for config $CONFIG_NUM is not running."
        exit 1
    fi
    
    
    echo "Stopping VPN tunnel for config $CONFIG_NUM..."
    COMPOSE_PROJECT_NAME="llustr-$CONFIG_NUM" docker compose down
    
    echo "tunnel $CONTAINER_NAME stopped."
fi
