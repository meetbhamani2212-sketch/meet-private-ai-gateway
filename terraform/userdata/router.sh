#!/bin/bash
set -euo pipefail

# Enable forwarding (required for subnet routing)
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf
sysctl -p

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Bring up Tailscale as a subnet router
tailscale up \
  --authkey="${TS_AUTHKEY}" \
  --advertise-routes="${ADVERTISE_CIDR}" \
  --advertise-tags="tag:subnet-router" \
  --hostname="${HOSTNAME}"
