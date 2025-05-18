#!/bin/bash
# Make sure bash is installed in the Alpine image
set -e

# Create auth file in a secure tmpfs location instead of persistent storage
# tmpfs is memory-backed and will be automatically destroyed when the container exits
mkdir -p /run/vpn-credentials
# Use umask to ensure file is created with restrictive permissions from the start
umask 077
echo "$VPN_USERNAME" > /run/vpn-credentials/auth.txt
echo "$VPN_PASSWORD" >> /run/vpn-credentials/auth.txt
# Double-check permissions
chmod 600 /run/vpn-credentials/auth.txt
# Clear the environment variables to prevent leakage in case of container inspection
export VPN_USERNAME=""
export VPN_PASSWORD=""

# Setup iptables
iptables -F
iptables -t nat -F
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Start OpenVPN in background with faster initialization
echo "Starting OpenVPN..."
openvpn --config /etc/openvpn/config/nordvpn.ovpn --connect-retry-max 3 --connect-timeout 10 --daemon

# After OpenVPN has started, schedule secure file wiping after a short delay
# We use a background process to securely wipe the credentials after OpenVPN has had time to read them
(
  # Wait 30 seconds to ensure OpenVPN has fully established the connection
  sleep 30
  
  # Securely wipe the auth file by overwriting it with random data
  dd if=/dev/urandom of=/run/vpn-credentials/auth.txt bs=1 count=50 conv=notrunc 2>/dev/null
  
  # Then zero out the file
  dd if=/dev/zero of=/run/vpn-credentials/auth.txt bs=1 count=50 conv=notrunc 2>/dev/null
  
  # Finally delete the file
  rm -f /run/vpn-credentials/auth.txt
  
  echo "Credentials file securely wiped"
) &

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
