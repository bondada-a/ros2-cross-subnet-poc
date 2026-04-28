#!/bin/bash
# Stage 2 -- ALLOW the Fast DDS port set.
#
# Starts from the DENY baseline and adds exactly the rules we will hand
# to IT. If ROS 2 works after this stage and fails without it, the rules
# below ARE the firewall-configuration request.
set -eo pipefail

# Re-apply Stage 1 first so the sequence is deterministic regardless of
# what state we were in. (Flushes rules, re-installs DROP + ICMP + conntrack.)
/router/firewall-stage1-deny.sh

# --- The IT-ask artifact ---------------------------------------------------
# UDP 11811: Fast DDS Discovery Server (default transport is UDP, not TCP).
# `fastdds discovery --help` confirms: -l/-p are the UDP listen address and
# port. TCP (-q 42100) is an optional secondary transport we do not use.
iptables -A FORWARD -p udp --dport 11811 -j ACCEPT

# UDP 7400-7500: Fast DDS participant data transport. 101-port range gives
# headroom for ~50 participants on domain 0 using the default RTPS port
# formula (PB + DG*domain + offset). Ephemeral allocation starts around
# 7410 and climbs from there, so a 7400-7500 window is comfortable.
iptables -A FORWARD -p udp --dport 7400:7500 -j ACCEPT
# --------------------------------------------------------------------------

# Flush conntrack again so any Stage-1 half-open attempts don't linger
# with DROP verdicts cached.
conntrack -F 2>/dev/null || true

echo "[stage2] DDS ports allowed: UDP 11811 (discovery) + UDP 7400-7500 (data)"
