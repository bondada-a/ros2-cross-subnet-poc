#!/bin/bash
# Human-readable dump of the current FORWARD chain -- use during the demo
# to show IT exactly which rules are in effect at each stage.
set -eo pipefail

echo "========== FORWARD chain =========="
iptables -L FORWARD -n -v --line-numbers
echo ""
echo "========== ip_forward =========="
cat /proc/sys/net/ipv4/ip_forward
echo ""
echo "========== router interfaces =========="
ip -br addr
