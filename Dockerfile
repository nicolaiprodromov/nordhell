FROM alpine:3.19

# Set environment variables for fast startup
ENV SOCKD_PATH=/usr/sbin/sockd
ENV OVPN_CONFIG=/etc/openvpn/config/nordvpn.ovpn

# Accept build argument for VPN config number (default: 0)
ARG VPN_CONFIG_NUM=0

# Install only necessary packages in a single layer
RUN apk add --no-cache \
    openvpn \
    dante-server \
    curl \
    iptables \
    iproute2 \
    iputils \
    bash \
    dnsmasq \
    bind-tools \
    && rm -rf /var/cache/apk/*

# Create directories for config files
RUN mkdir -p /etc/openvpn/config /etc/dante

# Copy OpenVPN configuration and pre-modify it at build time
# The specific file will be determined by the VPN_CONFIG_NUM build arg

# Copy all VPN configs and select the right one
COPY vpn-configs/ /tmp/vpn-configs/
# Use shell script to select and move the right config
RUN CONFIG_NUM=$(printf "%03d" $VPN_CONFIG_NUM) && \
    CONFIG_FILE=$(ls -1 /tmp/vpn-configs/${CONFIG_NUM}-*.tcp.ovpn) && \
    cp $CONFIG_FILE /etc/openvpn/config/nordvpn.ovpn && \
    rm -rf /tmp/vpn-configs/

COPY auth.txt /etc/openvpn/auth.txt
RUN echo "auth-user-pass /etc/openvpn/auth.txt" >> /etc/openvpn/config/nordvpn.ovpn

# Copy the sockd.conf file
COPY configs/sockd.conf /etc/dante/sockd.conf

# Copy the startup script
COPY scripts/start.sh /start.sh
RUN chmod +x /start.sh

# Expose the SOCKS5 port
EXPOSE 1080

# Set the entrypoint
ENTRYPOINT ["/start.sh"]
