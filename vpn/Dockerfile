FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends openfortivpn iproute2 ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY arrancar_vpn.sh /usr/local/bin/arrancar_vpn.sh
RUN chmod +x /usr/local/bin/arrancar_vpn.sh
ENTRYPOINT ["/usr/local/bin/arrancar_vpn.sh"]
