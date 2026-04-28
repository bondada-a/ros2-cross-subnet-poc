# dds/

Fast DDS XML profile consumed by **both** containers.

Pins all DDS behavior that would otherwise be dynamic, so the demo's
port-opening claims are verifiable:

- Transport: **UDPv4 only** (no shared memory, no TCP)
- Data ports: **7400–7410** (pinned range, not ephemeral)
- Participant mode: **SUPER_CLIENT** (connects to Discovery Server, also
  discovers other clients)
- Discovery Server: TCP `11811` on the `ros_server` container's
  `net_b` IP

## Why UDP instead of TCP transport

See `../docs/transport-decision.md` (to be added) for the full rationale.
Short version: UDP is the robotics-native transport, preserves QoS
semantics (notably `BEST_EFFORT` behavior), has better debuggability, and
matches 15+ years of production DDS experience. The only reason to prefer
TCP would be firewall-admin convenience — which is not our priority.

## Contents (to be filled in)

- `super_client_profile.xml` — loaded via `FASTRTPS_DEFAULT_PROFILES_FILE`
  env var in both containers
