# router/

Alpine-based container that bridges `net_a` (10.10.1.0/24) and `net_b`
(10.10.2.0/24) and enforces an iptables ACL between them.

Default policy: **drop all forwarded cross-subnet traffic except ICMP**.
This mirrors the posture of the production firewall between the
workstation and robot VM subnets.

Explicit ACCEPT rules are added to demonstrate the minimum port set
required for Fast DDS to operate.

## Why this matters

The iptables rules in this container are **the artifact we hand to IT**.
They translate directly into the firewall configuration request:

| iptables rule | IT-ask equivalent |
|---|---|
| `-p tcp --dport 11811 -j ACCEPT` | Allow TCP 11811 between the two subnets |
| `-p udp --dport 7400:7410 -j ACCEPT` | Allow UDP 7400-7410 between the two subnets |
| `-p icmp -j ACCEPT` | (Already allowed in production) |

## Contents (to be filled in)

- `Dockerfile` — Alpine + iptables + sysctl tooling
- `firewall.sh` — the exact rule set
- `entrypoint.sh` — enables ip_forward, applies rules, blocks on `tail -f /dev/null`
