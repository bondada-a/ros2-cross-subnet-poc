# ros_server/

Wraps the production `ghcr.io/bondada-a/beambot_img_v2:latest` image and
adds:

- A Fast DDS Discovery Server on port `11811`
- The Fast DDS XML profile from `../dds/` mounted at a known path
- An entrypoint that launches the beambot orchestrator with
  `use_fake_hardware:=true` so the demo runs without real UR5e / Zivid
  hardware attached

## Why re-use the production image

The point of the demo is to prove that *the exact software stack we
deploy* works across subnets. Re-building a stripped-down ROS 2 server
would defeat that — a positive result on a synthetic image wouldn't
generalize. The tradeoff is a larger container and slower startup, which
is acceptable for a PoC.

## Fake hardware

`use_fake_hardware:=true` is a pre-existing beambot argument that makes
the UR5e driver use the `mock_components/GenericSystem` controller,
skipping real robot I/O. The full MoveIt + action server stack still
launches — only the hardware layer is mocked.

## Contents (to be filled in)

- `Dockerfile` — `FROM ghcr.io/bondada-a/beambot_img_v2:latest`, adds
  `fastdds` CLI if missing
- `entrypoint.sh` — starts Discovery Server, then launches beambot
  orchestrator with fake hardware
