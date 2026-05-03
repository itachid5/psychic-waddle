#!/usr/bin/env bash
set -e

if [ -z "$TS_AUTHKEY" ]; then
  echo "ERROR: TS_AUTHKEY environment variable is missing"
  exit 1
fi

mkdir -p /var/lib/tailscale /var/run/tailscale

tailscaled \
  --state=/var/lib/tailscale/tailscaled.state \
  --socket=/var/run/tailscale/tailscaled.sock &

sleep 2

tailscale up \
  --authkey="${TS_AUTHKEY}" \
  --hostname="${TS_HOSTNAME:-ubuntu22-container}" \
  --ssh \
  ${TS_EXTRA_ARGS:-}

wait
