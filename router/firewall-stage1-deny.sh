#!/bin/bash
# Stage 1 -- DENY baseline.
#
# Mirrors the production firewall's current posture:
#   * ICMP passes (ping already works between 10.68.80.0/24 and 10.68.82.0/24)
#   * Everything else is dropped silently (timeouts, not RSTs)
#
# After running this, cross-subnet TCP and UDP should time out.
set -eo pipefail

# Flush all existing rules in every table we touch, so this script is
# idempotent and re-running it produces a known state.
iptables -F FORWARD
iptables -F INPUT
iptables -F OUTPUT

# Flush stateful table so any connections allowed by a previous stage are
# dropped immediately, not at their natural conntrack timeout. Without this,
# switching from ALLOW back to DENY would appear to leave DDS running until
# the DDS liveliness timeout expired.
conntrack -F 2>/dev/null || true

# FORWARD = traffic transiting through this router between subnets.
# Default DROP -- nothing crosses unless explicitly allowed below.
iptables -P FORWARD DROP

# Stateful allow: once a connection is established (by some rule below),
# its return packets and related traffic pass. Without this, every TCP reply
# would need its own reverse ACCEPT rule -- the moral equivalent of running
# a stateless firewall, which is not what real corporate firewalls do.
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ICMP is explicitly allowed. This matches what we already know about the
# production firewall: ping works cross-subnet today.
iptables -A FORWARD -p icmp -j ACCEPT

# INPUT / OUTPUT = traffic to/from the router container itself.
# We don't harden the router's own surface; it's a simulated appliance,
# not a target. ACCEPT default keeps `docker exec` shell usable.
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT

echo "[stage1] DENY baseline applied (ICMP only cross-subnet)"
