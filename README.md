# ros2-cross-subnet-poc

A Docker sandbox that reproduces a two-subnet, routed, firewalled network
and demonstrates **the minimum port set required for ROS 2 (Humble, Fast DDS)
to operate across it**.

Built to support a concrete firewall-configuration request for a
workstation (`ws2`) on one subnet communicating with a robot control VM on
another subnet.

---

## TL;DR

To allow ROS 2 to work between two subnets, IT needs to open:

| Protocol | Port(s)       | Purpose                          |
|----------|---------------|----------------------------------|
| UDP      | **11811**     | Fast DDS Discovery Server        |
| UDP      | **7400-7500** | Fast DDS participant data        |

Bidirectional, stateful. That's it. The rest of this repo proves it.

The formal firewall-configuration request is in
[`docs/it-ask.md`](docs/it-ask.md).

---

## What this proves

Three containers on two isolated Docker networks simulate the production
topology:

```
  ws2_client                          ros_server
  (net_a: 10.10.1.10)                 (net_b: 10.10.2.10)
       \                               /
        \                             /
         +----- router container -----+
          (10.10.1.254, 10.10.2.254)
          bridges + enforces iptables ACL
```

- `ws2_client` — **pixi / RoboStack** ROS 2 client, identical to the
  environment on the real ws2 workstation
  ([jennmald/cms-ros-client](https://github.com/jennmald/cms-ros-client)).
- `ros_server` — **production beambot image**
  (`ghcr.io/bondada-a/beambot_img_v2:latest`) running the orchestrator
  with `use_fake_hardware:=true`, plus a Fast DDS Discovery Server on
  UDP 11811.
- `router` — Alpine + iptables dual-homed on both networks. Default
  policy DROP. Stage scripts flip between demo postures.

The two ROS containers use **different Fast DDS builds** (conda-forge
RoboStack on the client, apt Open Robotics on the server). Proving they
interoperate across a firewalled boundary is the point.

## The three demo stages

1. **Stage 1 — DENY baseline.** Router drops all cross-subnet traffic
   except ICMP. This mirrors what IT's firewall does *today*.
   `ros2 topic list` on `ws2_client` returns nothing.

2. **Stage 2 — ALLOW (the ask).** Router adds ACCEPT rules for
   **UDP 11811** and **UDP 7400-7500**. `ros2 topic list` now discovers
   the full graph (9 action servers, 7 topics). A goal sent to
   `/beambot_execution` round-trips end-to-end with feedback streaming.

3. **Stage 3 — Negative test.** Router allows only UDP 11811, blocks
   UDP 7400-7500. Discovery packets flow (counter confirms) but the
   topic graph never populates on the client. Proves **both** port
   classes are required.

## Running the demo

Prerequisites: Docker 20.10+ (Compose v2 required for the `docker compose`
syntax used below), ~12 GB disk space, NET_ADMIN on Docker.

```bash
# Build and bring up all three containers
docker compose up -d --build

# Wait ~30 seconds for beambot to finish booting, then run the demo
bash demo/run-demo.sh

# or, non-interactive:
bash demo/run-demo.sh --fast

# Tear down
docker compose down
```

### Manual stage switching

```bash
# Inspect current iptables state
docker compose exec router /router/show-rules.sh

# Flip between stages at any time
docker compose exec router /router/firewall-stage1-deny.sh
docker compose exec router /router/firewall-stage2-allow.sh
docker compose exec router /router/firewall-stage3-tcponly.sh

# Probe discovery from the client side
docker compose exec ws2_client pixi run -e ros2 ros2 topic list

# Send a beambot goal end-to-end
bash demo/send-goal.sh
```

## Layout

| Path                          | Purpose                                                            |
|-------------------------------|--------------------------------------------------------------------|
| `router/`                     | Alpine + iptables. Stage scripts are the IT-ask artifact.          |
| `ros_server/`                 | Wraps `ghcr.io/bondada-a/beambot_img_v2:latest`, adds DS + fake HW |
| `ws2_client/`                 | Ubuntu + pixi + RoboStack ROS 2, matches production ws2            |
| `dds/super_client_profile.xml`| Fast DDS XML profile (SUPER_CLIENT pointing at Discovery Server)   |
| `demo/goal.json`              | Minimal MTCExecution task: moveto to `safe_sample_transport`       |
| `demo/send-goal.sh`           | Fires the goal via Python rclpy (avoids CLI YAML-quoting trap)     |
| `demo/run-demo.sh`            | Scripted three-stage demo; captures per-stage output               |
| `docs/it-ask.md`              | Formal firewall-configuration request                              |
| `docs/transport-decision.md`  | Why UDP DDS, not TCP/WebSocket/VPN/multicast                       |
| `docs/stage-outputs/`         | Terminal capture of each stage (populated after `run-demo.sh`)     |
| `docker-compose.yml`          | Networks + service definitions                                     |

## What this is NOT

- Not a production deployment template. It demonstrates the minimum
  network configuration for DDS to traverse a firewall; real deployments
  will want DDS-Security, TLS for any web tooling, proper container
  image signing, etc.
- Not a replacement for a VPN overlay. Those remain a valid alternative;
  see [`docs/transport-decision.md`](docs/transport-decision.md) for
  why we chose the firewall-port-opening approach.
- Not a security review. The demo intentionally uses plaintext DDS.

## Known limitations of the sandbox

- The sandbox hardcodes subnets `10.10.1.0/24` and `10.10.2.0/24`
  because those are routable only inside Docker. Production uses the
  real `10.68.80.0/24` and `10.68.82.0/24`. The iptables rules and DDS
  port ask translate 1:1.
- The `ros_server` uses `use_fake_hardware:=true`, so no actual robot
  motion. The action server still provides realistic MoveIt planning +
  feedback timing.
- The ws2_client container doesn't reboot cleanly — pixi environments
  are mounted inside the container; `docker compose restart ws2_client`
  is fine but nuking the container loses the pixi cache and forces a
  re-solve on the next `up`.

## Learnings captured along the way

- **Fast DDS Discovery Server default transport is UDP 11811**, not TCP
  (despite many tutorials saying "TCP 11811"). Verified via
  `fastdds discovery --help`.
- **SUPER_CLIENT mode needs both discovery and peer-to-peer traffic**
  (Stage 3 proves this).
- **Conntrack on the simulated router must be flushed between stages**
  (`conntrack -F`) or established connections linger past firewall
  changes.
- **`ros2 action send_goal` CLI mangles JSON** (the YAML parser strips
  quotes). Use `rclpy.ActionClient` directly.
- **Pixi `[workspace]` syntax requires >= 0.40**; we ship 0.45.0.

## Contact

- Repository: https://github.com/bondada-a/ros2-cross-subnet-poc
- Upstream ws2 client env: https://github.com/jennmald/cms-ros-client
- Beambot image: https://github.com/bondada-a/erobs
