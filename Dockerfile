FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y curl ca-certificates iproute2 iputils-ping bash && \
    curl -fsSL https://tailscale.com/install.sh | sh && \
    rm -rf /var/lib/apt/lists/*

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]
