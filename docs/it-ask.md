# Firewall Configuration Request: ROS 2 DDS Between ws2 and Robot VM

## Summary

Open the following between `10.68.80.0/24` (ws2 workstation) and
`10.68.82.0/24` (robot control VM), **bidirectional**:

| Protocol | Port(s)     | Purpose                              |
|----------|-------------|--------------------------------------|
| UDP      | **11811**   | Fast DDS Discovery Server metadata   |
| UDP      | **7400-7500** | Fast DDS participant data transport |
| ICMP     | *(already allowed)* | Reachability verification     |

Firewall must allow **stateful return traffic** so replies can flow back
to ephemeral source ports. No inbound NAT or port publishing is required.

## Why

ROS 2 (our robotics middleware) uses the **Fast DDS** data-distribution
protocol for inter-node communication. Without these ports open between
the two subnets, ROS 2 participants on ws2 cannot discover or exchange
data with the ROS 2 server on the robot VM, even though ICMP ping works.

We have verified the minimum required port set by reproducing the
production topology in a Docker sandbox
(https://github.com/bondada-a/ros2-cross-subnet-poc). Three demonstration
stages were run:

1. **Baseline (ICMP only, all else blocked)** — current firewall posture.
   `ros2 topic list` on ws2 returns nothing. Robot is unreachable.
2. **With UDP 11811 + UDP 7400-7500 allowed** — proposed posture.
   `ros2 topic list` returns the full graph. `ros2 action send_goal
   /beambot_execution` succeeds end-to-end with feedback streaming back.
3. **With only UDP 11811 allowed (data ports blocked)** — negative test
   proving both port classes are required. Discovery packets flow but
   topic advertisements never complete because participant-to-participant
   traffic is blocked.

## What this traffic looks like

- **UDP 11811 (Discovery Server)**: ws2's ROS clients register with a
  centralized Discovery Server process running on the VM. This is the
  "yellow pages" lookup — participants announce themselves and learn
  what's on the network.
- **UDP 7400-7500 (participant data)**: once participants discover each
  other, they exchange topic advertisements, subscriptions, and actual
  data (sensor readings, robot commands, feedback) directly on
  per-participant ports. The 7400-7500 range is the standard Fast DDS
  port window for ROS `domain 0` — well-documented in Fast DDS upstream.

## Why not open more / less

- **UDP 11811 only is insufficient** (demonstrated in Stage 3 of the
  PoC). The Discovery Server provides initial metadata but not topic
  data; that flows peer-to-peer on 7400-7500.
- **TCP 11811 is not used** by default Fast DDS Discovery Server; our
  container uses UDP. The server does support TCP as a secondary
  transport (port 42100 by default) but we have not enabled it.
- **Multicast routing is not required** — the Discovery Server pattern
  replaces multicast-based discovery with centralized unicast. All
  traffic is directed point-to-point between ws2 and the VM; no
  multicast groups, no IGMP configuration needed.
- **A wider UDP range (e.g., 7400-8000)** is unnecessary. 101 ports
  comfortably accommodates ~50 concurrent participants.
- **Narrower range (e.g., 7400-7410)** works for the PoC's 2-participant
  case but leaves no headroom. 7400-7500 is the standard ask.

## No-go alternatives (for context)

These alternatives were considered and ruled out:

- **VPN overlay (Tailscale / ZeroTier / WireGuard)** — requires daemons
  installed on both endpoints and external account / infrastructure
  dependency. Rejected in favor of a narrow firewall rule.
- **Multicast routing between VLANs** — larger network-config change
  with broader effects than opening specific ports. Rejected as higher
  blast radius.
- **rosbridge WebSocket (TCP 9090) over SSH tunnel** — works and we have
  this as a fallback, but uses a JSON bridge layer that adds latency and
  cannot carry high-rate sensor data (point clouds, images). Rejected
  as primary because the robot system will need full DDS capability for
  future features (live camera feeds, multi-node telemetry).

## Security considerations

- Both endpoints are internal, trusted hosts within the beamline network.
  No external exposure is requested; the rule is subnet-to-subnet only.
- Traffic is plaintext DDS. Future migration to DDS-Security is possible
  without further firewall changes (uses the same ports).
- All DDS traffic carries robot telemetry and control; no credentials,
  PII, or financial data flow over these ports.

## Supporting artifact

The Docker sandbox referenced above contains:

- `router/firewall-stage2-allow.sh` — exact iptables rules equivalent to
  this request, in a runnable form.
- `docs/stage-outputs/` — captured terminal output from the demo, showing
  the difference between blocked and allowed states.

```
# router/firewall-stage2-allow.sh excerpt:
iptables -A FORWARD -p udp --dport 11811 -j ACCEPT
iptables -A FORWARD -p udp --dport 7400:7500 -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -p icmp -j ACCEPT
iptables -P FORWARD DROP
```

## Contact

- Requester: Aditya Bondada (abondada@bnl.gov)
- Repository: https://github.com/bondada-a/ros2-cross-subnet-poc
