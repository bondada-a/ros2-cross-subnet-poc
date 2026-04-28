#!/bin/bash
# Stage 3 -- NEGATIVE TEST: open only the Discovery Server TCP port,
# leave the UDP data range blocked.
#
# Purpose: pre-empt the inevitable IT question "can we just open one port?"
# with a concrete demonstration that no, we need both. After this stage:
#   * `ros2 topic list` succeeds (discovery metadata flows over TCP 11811)
#   * `ros2 action send_goal` hangs / errors out (data packets die on UDP)
#
# The pedagogical value is showing IT *why* the ask has two parts.
set -euo pipefail

# Start clean (DROP default + conntrack + ICMP + conntrack flush).
/router/firewall-stage1-deny.sh

# TCP 11811 only. NO UDP rule.
iptables -A FORWARD -p tcp --dport 11811 -j ACCEPT

conntrack -F 2>/dev/null || true

echo "[stage3] TCP 11811 only -- discovery will work, data transport will not"
