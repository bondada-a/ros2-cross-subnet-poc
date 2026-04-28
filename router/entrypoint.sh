#!/bin/bash
# Router entrypoint: verify packet forwarding is enabled (caller's
# responsibility via --sysctl net.ipv4.ip_forward=1), apply Stage 1
# (DENY) by default, then block forever. Stage switches happen via:
#   docker exec router /router/firewall-stage2-allow.sh
#   docker exec router /router/firewall-stage3-tcponly.sh
#   docker exec router /router/firewall-stage1-deny.sh
set -euo pipefail

# Packet forwarding must be enabled at container creation because
# /proc/sys/net/ipv4/ip_forward is read-only once the container starts.
# The compose / docker-run layer sets it via --sysctl; we only verify.
ip_forward="$(cat /proc/sys/net/ipv4/ip_forward)"
if [[ "${ip_forward}" != "1" ]]; then
    echo "[router] FATAL: ip_forward=${ip_forward}, expected 1" >&2
    echo "[router] run this container with --sysctl net.ipv4.ip_forward=1" >&2
    exit 1
fi
echo "[router] ipv4 forwarding verified (ip_forward=1)"

echo "[router] applying Stage 1 (default-deny baseline)"
/router/firewall-stage1-deny.sh

echo "[router] ready. Current FORWARD rules:"
/router/show-rules.sh

echo "[router] blocking on tail -f /dev/null (stage switches via docker exec)"
exec tail -f /dev/null
