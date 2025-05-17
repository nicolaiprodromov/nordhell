#!/bin/bash
# status.sh - List all active VPN tunnels

echo "-------------------------------------"
echo "LLUSTR TNNLs:"
echo "-------------------------------------"

# Check if any llustr containers are running
if ! docker ps --filter "name=llustr-proxy-tunnel-" | grep -q llustr-proxy-tunnel; then
    echo "No active VPN tunnels found."
    exit 0
fi

# Print header
printf "%-25s %-8s %-25s %-30s\n" "CONTAINER" "PORT" "STATUS" "VPN SERVER"
printf "%-25s %-8s %-25s %-30s\n" "---------" "----" "------" "---------"

# Get all running containers with the llustr prefix
CONTAINERS=$(docker ps --filter "name=llustr-proxy-tunnel-" --format "{{.Names}}")

# Loop through each container
for CONTAINER in $CONTAINERS; do
    # Get the port
    PORT=$(docker port $CONTAINER 1080/tcp | cut -d ':' -f 2)
    
    # Get the status
    STATUS=$(docker ps --filter "name=$CONTAINER" --format "{{.Status}}")
    
    # Get VPN server info from logs
    VPN_SERVER=$(docker logs $CONTAINER 2>&1 | grep "Connected to VPN server" | head -1 | sed -e 's/.*Connected to VPN server: //' -e 's/).*$//')
    
    # If we couldn't find the VPN server info, mark as unknown
    if [ -z "$VPN_SERVER" ]; then
        VPN_SERVER="Unknown"
    fi
    
    # Print the information
    printf "%-25s %-8s %-25s %-30s\n" "$CONTAINER" "$PORT" "$STATUS" "$VPN_SERVER"
done
echo "-------------------------------------"
