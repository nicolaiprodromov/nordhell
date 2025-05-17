#!/bin/bash
# Make sure bash is installed in the Alpine image
set -e

# Setup iptables
iptables -F
iptables -t nat -F
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Start OpenVPN in background with faster initialization
echo "Starting OpenVPN..."
openvpn --config /etc/openvpn/config/nordvpn.ovpn --connect-retry-max 3 --connect-timeout 10 --daemon

# Wait for tun0 interface to be up with timeout (max 15 seconds)
echo "Waiting for VPN connection to be established..."
MAX_WAIT=15
COUNTER=0
while ! ip link show tun0 &>/dev/null; do
    sleep 0.5
    COUNTER=$((COUNTER+1))
    if [ $COUNTER -ge $((MAX_WAIT*2)) ]; then
        echo "Timed out waiting for VPN interface"
        exit 1
    fi
done

# Actually verify the connection is working
if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    # Try one more time with a short delay
    sleep 1
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo "VPN connection failed to establish properly"
        exit 1
    fi
fi

# Get VPN information
echo "VPN connection established"

# Extract VPN server information from config file
SERVER_ADDR=$(grep "^remote " /etc/openvpn/config/nordvpn.ovpn | head -1 | awk '{print $2}')
SERVER_NAME=$(basename /etc/openvpn/config/nordvpn.ovpn .ovpn)
echo "Connected to VPN server: $SERVER_NAME ($SERVER_ADDR)"

# Using simpler grep syntax compatible with BusyBox
echo -n "VPN Interface IP: "
ip addr show tun0 | grep "inet " | awk '{print $2}' | cut -d/ -f1

# Set DNS servers to Google & Cloudflare through the VPN tunnel
echo "Setting up basic DNS handling..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Simple routing for DNS through VPN
echo "Setting up VPN routing for DNS..."
ip route add 8.8.8.8/32 dev tun0
ip route add 1.1.1.1/32 dev tun0

# Start Dante SOCKS5 server
echo "Starting Dante SOCKS5 server..."

# Use the environment variable set in Dockerfile
echo "Starting sockd in foreground mode..."
exec ${SOCKD_PATH} -f /etc/dante/sockd.conf
