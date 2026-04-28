# Transport Decision: UDP Fast DDS over WebSocket / TCP Alternatives

## Summary

For cross-subnet ROS 2 communication between the ws2 workstation and the
robot control VM, we chose **Fast DDS over UDP with a Discovery Server**
over alternatives (WebSocket+SSH tunnel, Fast DDS TCP transport, VPN
overlay, multicast routing).

The deciding factor was **robotics-first development ergonomics**, not
firewall admin convenience.

## Options evaluated

### A. Fast DDS UDP + Discovery Server (chosen)

- **Transport**: UDP 11811 (discovery) + UDP 7400-7500 (data)
- **How**: Fast DDS `SUPER_CLIENT` participants + centralized
  `fastdds discovery` server on the VM.
- **Firewall ask**: two UDP ports/ranges, bidirectional, stateful.
- **Production maturity**: 15+ years in DDS generally, native ROS 2
  default, thoroughly documented.

### B. WebSocket + SSH tunnel (rosbridge)

- **Transport**: TCP 9090 tunneled via SSH.
- **How**: `rosbridge_server` on VM translates JSON-over-WS to ROS.
  ws2 uses `roslibpy` or similar to call it.
- **Firewall ask**: none (SSH already allowed).
- **Limitation**: JSON serialization. A 2 MB image becomes ~2.7 MB of
  base64 text. Fine for control messages; painful for camera/sensor
  streams.

### C. Fast DDS TCP transport

- **Transport**: all-TCP (port 11811 + 42100).
- **How**: Fast DDS XML profile selects `TCPv4` transport instead of
  UDPv4.
- **Firewall ask**: two TCP ports (firewall admins prefer TCP).
- **Limitation**: TCP head-of-line blocking violates BEST_EFFORT QoS
  semantics. Non-default path, sparsely documented.

### D. VPN overlay (Tailscale / ZeroTier / WireGuard)

- **Transport**: encrypted UDP tunnel via VPN daemon.
- **How**: both hosts join a virtual L3 network; from ROS's perspective
  they're on the same LAN.
- **Firewall ask**: outbound UDP 41641 (Tailscale) or similar.
- **Limitation**: adds a daemon dependency on both hosts; requires
  external account (Tailscale/ZeroTier) or self-hosted infrastructure.

### E. IP multicast routing between subnets

- **Transport**: standard Fast DDS with multicast SPDP discovery.
- **How**: IT enables IGMP proxy / PIM on the inter-VLAN router.
- **Firewall ask**: multicast routing config (substantial).
- **Limitation**: larger network change than opening specific ports.

## Why A over B

rosbridge works and we have it as a fallback. But as a primary:

1. **JSON overhead on high-rate data**. We expect to stream camera
   feeds, point clouds, and motor-position telemetry from the VM to the
   ws2 GUI. rosbridge would saturate on these.
2. **Asymmetric client-server model**. rosbridge is one-way: client
   calls server. Real ROS 2 is symmetric — ws2 will also publish topics
   (beamline data, motor positions, sample status) that the VM or other
   clients consume. rosbridge forces awkward workarounds.
3. **Graph invisibility**. ws2's rosbridge client is not a ROS graph
   participant; it doesn't show up in `ros2 node list` on the VM.
   Debugging and monitoring become harder.
4. **QoS loss**. rosbridge exposes reliability/durability but not
   deadlines, liveliness, etc. Future real-time work (live control
   feedback) needs these.
5. **Ecosystem mismatch**. Every ROS 2 tutorial, tool, and library
   assumes native DDS. Copying debugging recipes from the internet
   Just Works with UDP DDS and requires custom adaptation with rosbridge.

## Why A over C (UDP over TCP Fast DDS)

1. **QoS fidelity**. TCP's retransmission logic overrides DDS
   BEST_EFFORT semantics — if we ever publish a topic as BEST_EFFORT
   specifically to get fresh-not-ordered data, TCP transport silently
   violates that contract.
2. **Head-of-line blocking**. A single dropped packet pauses *everything*
   on the TCP connection. For camera streams at 10-30 Hz this measurably
   increases tail latency.
3. **Community experience**. Practically every ROS 2 deployment uses
   UDP; TCP transport is rare enough that its failure modes aren't
   widely understood.
4. **Debuggability**. UDP-DDS failures are easier to diagnose with
   Wireshark's native RTPS dissector and `tcpdump`. TCP adds a layer.
5. **Future extensibility**. DDS-Security and ROS 2 lifecycle features
   were designed around UDP semantics; TCP transport has trailing-edge
   compatibility.

## Why A over D (VPN)

Simpler. If the UDP port ask is refused, VPN becomes the Plan B. But
while we can get the ports with a targeted rule, no reason to add a
daemon dependency.

## Why A over E (multicast routing)

The `ROS_DISCOVERY_SERVER` pattern is supported natively by ROS 2
Humble specifically **to avoid** requiring multicast routing across
VLANs. Multicast routing is a bigger network-config change than opening
specific ports.

## What decided it

Prior to evaluating trade-offs, we ran the Python socket communication
test across the subnets (see the repo's README) and confirmed:

- Ping works (ICMP already allowed by the current firewall).
- Arbitrary TCP/UDP between the subnets is silently dropped.
- SSH is allowed (proven by using it for the rosbridge fallback).

Given the firewall admits targeted port openings (SSH, ICMP), asking for
two narrow UDP rules is *within the profile of changes the current
policy already makes*. This tilted the ROI: small, familiar ask vs
larger gains (full DDS capability) — rather than "large unfamiliar ask
vs smaller gains" (multicast routing or VPN).
