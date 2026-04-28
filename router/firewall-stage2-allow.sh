#!/bin/bash
# Stage 2 -- ALLOW the Fast DDS port set.
#
# Starts from the DENY baseline and adds exactly the rules we will hand
# to IT. If ROS 2 works after this stage and fails without it, the rules
# below ARE the firewall-configuration request.
set -euo pipefail

# Re-apply Stage 1 first so the sequence is deterministic regardless of
# what state we were in. (Flushes rules, re-installs DROP + ICMP + conntrack.)
/router/firewall-stage1-deny.sh

# --- The IT-ask artifact ---------------------------------------------------
# TCP 11811: Fast DDS Discovery Server (centralized discovery, replaces
# multicast).
iptables -A FORWARD -p tcp --dport 11811 -j ACCEPT

# UDP 7400-7410: Fast DDS data transport. Range pinned via
# dds/super_client_profile.xml so IT's rule can be narrow and stable
# rather than "some ephemeral range."
iptables -A FORWARD -p udp --dport 7400:7410 -j ACCEPT
# --------------------------------------------------------------------------

# Flush conntrack again so any Stage-1 half-open attempts don't linger
# with DROP verdicts cached.
conntrack -F 2>/dev/null || true

echo "[stage2] DDS ports allowed: TCP 11811 (discovery) + UDP 7400-7410 (data)"
