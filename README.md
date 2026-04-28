# ros2-cross-subnet-poc

A Docker sandbox that reproduces a two-subnet, routed, firewalled network
and demonstrates **the minimum port set required for ROS 2 (Humble, Fast DDS)
to operate across it**.

Built to support a concrete firewall-configuration request for a
workstation (`ws2`) on one subnet communicating with a robot control VM on
another subnet.

## What this proves

Three containers on two isolated Docker networks simulate the production
topology:

```
  ws2_client                     ros_server
  (net_a: 10.10.1.0/24)          (net_b: 10.10.2.0/24)
        \                          /
         \                        /
          +---- router container ----+
           (bridges the two subnets,
            enforces iptables ACL)
```

The demo runs in three stages:

1. **DENY baseline** — router drops all cross-subnet traffic except ICMP.
   `ros2 topic list` on `ws2_client` shows nothing. This mirrors the
   production firewall's current behavior.

2. **ALLOW the required ports** — router adds explicit ACCEPT rules for:
   - TCP `11811` (Fast DDS Discovery Server)
   - UDP `7400-7410` (Fast DDS data transport, pinned via XML profile)

   `ros2 topic list` now discovers the server's topics. A goal sent to
   `/beambot_execution` round-trips successfully.

3. **Negative test** — remove only the UDP ACCEPT rule. Discovery still
   works, but action data does not flow. This proves **both** port classes
   are required.

## What this is not

- Not a production deployment template.
- Not a replacement for a full VPN / overlay network.
- Not a security review — the demo intentionally uses plaintext DDS.

## Status

**Work in progress.** Scaffold stage — subdirectories will be filled in.

## Layout

| Path              | Purpose                                                     |
|-------------------|-------------------------------------------------------------|
| `router/`         | Alpine + iptables; simulates the firewall between subnets   |
| `ws2_client/`     | Minimal pixi-based ROS client container                     |
| `ros_server/`     | Beambot image + Fast DDS Discovery Server + fake hardware   |
| `dds/`            | Fast DDS XML profile (UDP transport, pinned ports)          |
| `demo/`           | Scripted 3-stage demo and fake goal JSON                    |
| `docs/`           | IT ask document and captured demo output                    |
| `docker-compose.yml` | Defines all containers and networks                      |

## Running the demo

(To be filled in once scaffolding is complete.)
