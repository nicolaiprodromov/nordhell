#!/bin/bash
set -e

mkdir -p /run/vpn-credentials

umask 077
echo "$VPN_USERNAME" > /run/vpn-credentials/auth.txt
echo "$VPN_PASSWORD" >> /run/vpn-credentials/auth.txt

chmod 600 /run/vpn-credentials/auth.txt

export VPN_USERNAME=""
export VPN_PASSWORD=""

iptables -F
iptables -t nat -F
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

echo "Starting OpenVPN..."
openvpn --config /etc/openvpn/config/nordvpn.ovpn --connect-retry-max 3 --connect-timeout 10 --daemon

(
  sleep 30
  
  dd if=/dev/urandom of=/run/vpn-credentials/auth.txt bs=1 count=50 conv=notrunc 2>/dev/null
  
  dd if=/dev/zero of=/run/vpn-credentials/auth.txt bs=1 count=50 conv=notrunc 2>/dev/null
  
  rm -f /run/vpn-credentials/auth.txt
  
  echo "Credentials file securely wiped"
) &

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

if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    
    sleep 1
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo "VPN connection failed to establish properly"
        exit 1
    fi
fi

echo "VPN connection established"

SERVER_ADDR=$(grep "^remote " /etc/openvpn/config/nordvpn.ovpn | head -1 | awk '{print $2}')
SERVER_NAME=$(basename /etc/openvpn/config/nordvpn.ovpn .ovpn)
echo "Connected to VPN server: $SERVER_NAME ($SERVER_ADDR)"


echo -n "VPN Interface IP: "
ip addr show tun0 | grep "inet " | awk '{print $2}' | cut -d/ -f1


echo "Setting up basic DNS handling..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf


echo "Setting up VPN routing for DNS..."
ip route add 8.8.8.8/32 dev tun0
ip route add 1.1.1.1/32 dev tun0


echo "Starting Dante SOCKS5 server..."


echo "Starting sockd in foreground mode..."
exec ${SOCKD_PATH} -f /etc/dante/sockd.conf
