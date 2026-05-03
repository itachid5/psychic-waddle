FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# এখানে আপনার Tailscale auth key বসান
ENV TS_AUTHKEY="tskey-auth-kgEfpyveQt11CNTRL-dMPG4n5dmaJkg5QoxWuMaJeQ1phxxC4WV"
ENV TS_HOSTNAME="railway-ubuntu22"

RUN apt-get update && \
    apt-get install -y curl ca-certificates iproute2 iputils-ping bash procps && \
    curl -fsSL https://tailscale.com/install.sh | sh && \
    rm -rf /var/lib/apt/lists/*

RUN cat > /usr/local/bin/start.sh <<'EOF'
#!/usr/bin/env bash
set -e

mkdir -p /var/lib/tailscale /var/run/tailscale

echo "Starting tailscaled in userspace networking mode..."

tailscaled \
  --tun=userspace-networking \
  --state=/var/lib/tailscale/tailscaled.state \
  --socket=/var/run/tailscale/tailscaled.sock &

sleep 3

echo "Connecting to Tailscale..."

tailscale up \
  --authkey="${TS_AUTHKEY}" \
  --hostname="${TS_HOSTNAME}" \
  --ssh

echo "Tailscale SSH is ready."
echo "Login from your tailnet with:"
echo "ssh root@${TS_HOSTNAME}"

tail -f /dev/null
EOF

RUN chmod +x /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]
