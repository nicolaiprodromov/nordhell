FROM alpine:3.19

# Set environment variables for fast startup
ENV SOCKD_PATH=/usr/sbin/sockd
ENV OVPN_CONFIG=/etc/openvpn/config/nordvpn.ovpn

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
COPY vpn-configs/000-ad3.nordvpn.com.tcp.ovpn /etc/openvpn/config/nordvpn.ovpn
COPY auth.txt /etc/openvpn/auth.txt
RUN echo "auth-user-pass /etc/openvpn/auth.txt" >> /etc/openvpn/config/nordvpn.ovpn

# Copy the sockd.conf file
COPY sockd.conf /etc/dante/sockd.conf

# Copy the startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose the SOCKS5 port
EXPOSE 1080

# Set the entrypoint
ENTRYPOINT ["/start.sh"]
