#!/bin/bash

echo "=========================================="
echo "         VPN PROXY TEST SUITE"
echo "=========================================="
echo ""

HOST_IP=$(curl -s https://api.ipify.org?format=json | jq -r '.ip')
if [ -z "$HOST_IP" ]; then
    echo "❌ Failed to get host IP address"
    exit 1
fi

echo "🌐 Host IP: $HOST_IP"
echo ""

CONTAINERS=$(docker ps --filter "name=passage-" --format "{{.Names}}")

if [ -z "$CONTAINERS" ]; then
    echo "❌ No active VPN tunnels found"
    exit 1
fi

TUNNEL_COUNT=$(echo "$CONTAINERS" | wc -l)
echo "🔍 Found $TUNNEL_COUNT active tunnel(s)"
echo ""

PASSED=0
FAILED=0

for CONTAINER in $CONTAINERS; do
    PORT=$(docker port $CONTAINER 1080/tcp 2>/dev/null | cut -d ':' -f 2)
    
    if [ -z "$PORT" ]; then
        echo "❌ $CONTAINER: Failed to get port"
        FAILED=$((FAILED + 1))
        continue
    fi
    
    PROXY_IP=$(curl -s --max-time 10 --socks5-hostname localhost:$PORT https://api.ipify.org?format=json | jq -r '.ip' 2>/dev/null)
    
    if [ -z "$PROXY_IP" ] || [ "$PROXY_IP" = "null" ]; then
        echo "❌ $CONTAINER (port $PORT): Failed to connect through proxy"
        FAILED=$((FAILED + 1))
    elif [ "$PROXY_IP" = "$HOST_IP" ]; then
        echo "❌ $CONTAINER (port $PORT): Same IP as host ($PROXY_IP)"
        FAILED=$((FAILED + 1))
    else
        echo "✅ $CONTAINER (port $PORT): Exit IP = $PROXY_IP"
        PASSED=$((PASSED + 1))
    fi
done

echo ""
echo "=========================================="
echo "               RESULTS"
echo "=========================================="
echo "✅ Passed: $PASSED"
echo "❌ Failed: $FAILED"
echo "📊 Total:  $((PASSED + FAILED))"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "🎉 All tests passed!"
    exit 0
else
    echo "⚠️  Some tests failed"
    exit 1
fi
