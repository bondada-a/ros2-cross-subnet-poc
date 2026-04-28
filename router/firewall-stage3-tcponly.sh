#!/bin/bash
# Stage 3 -- NEGATIVE TEST: open only the Discovery Server port,
# leave the DDS participant data range blocked.
#
# Purpose: pre-empt the inevitable IT question "can we just open one port?"
# with a concrete demonstration that no, we need both. After this stage:
#   * `ros2 topic list` succeeds (discovery metadata flows over UDP 11811)
#   * `ros2 action send_goal` hangs / errors out (data packets die on
#     UDP 7400-7500 which this stage does not allow)
#
# The pedagogical value is showing IT *why* the ask has two parts.
set -eo pipefail

# Start clean (DROP default + conntrack + ICMP + conntrack flush).
/router/firewall-stage1-deny.sh

# UDP 11811 only (Discovery Server metadata). NO data-port UDP rule.
iptables -A FORWARD -p udp --dport 11811 -j ACCEPT

conntrack -F 2>/dev/null || true

echo "[stage3] UDP 11811 only -- discovery can start, data transport will not"
