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

COPY configs/sockd.conf /etc/dante/sockd.conf

COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 1080

ENTRYPOINT ["/entrypoint.sh"]
