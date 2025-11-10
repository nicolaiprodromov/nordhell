# ██████████████████████████████████████████████████████████████████████████████
# █                                                                            █
# █   ███╗   ██╗ ██████╗ ██████╗ ██████╗     ██╗  ██╗███████╗██╗     ██╗       █
# █   ████╗  ██║██╔═══██╗██╔══██╗██╔══██╗    ██║  ██║██╔════╝██║     ██║       █
# █   ██╔██╗ ██║██║   ██║██████╔╝██║  ██║    ███████║█████╗  ██║     ██║       █
# █   ██║╚██╗██║██║   ██║██╔══██╗██║  ██║    ██╔══██║██╔══╝  ██║     ██║       █
# █   ██║ ╚████║╚██████╔╝██║  ██║██████╔╝    ██║  ██║███████╗███████╗███████╗  █
# █   ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝  █
# █                                                                            █   
# ██████████████████████████████████████████████████████████████████████████████
FROM alpine:3.19

ENV SOCKD_PATH=/usr/sbin/sockd
ENV OVPN_CONFIG=/etc/openvpn/config/nordvpn.ovpn

ARG VPN_CONFIG_NUM=0

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

RUN mkdir -p /etc/openvpn/config /etc/dante

COPY vpn-configs/ /tmp/vpn-configs/

RUN CONFIG_NUM=$(printf "%03d" $VPN_CONFIG_NUM) && \
    CONFIG_FILE=$(ls -1 /tmp/vpn-configs/${CONFIG_NUM}-*.tcp.ovpn) && \
    cp $CONFIG_FILE /etc/openvpn/config/nordvpn.ovpn && \
    rm -rf /tmp/vpn-configs/

RUN echo "auth-user-pass /run/vpn-credentials/auth.txt" >> /etc/openvpn/config/nordvpn.ovpn

COPY configs/sockd.conf /etc/dante/sockd.conf

COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 1080

ENTRYPOINT ["/entrypoint.sh"]
