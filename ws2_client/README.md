# ws2_client/

Minimal ROS 2 client container that mirrors the production `ws2`
workstation: a **pixi-based** Python environment with ROS 2 libraries from
conda-forge (RoboStack), rather than a full `ros-humble-*` apt install.

Adapted from https://github.com/jennmald/cms-ros-client (the environment
currently in use on the real `ws2`).

## Why the pixi base (not `ros:humble`)

The real `ws2` uses a pixi/conda environment, not a stock ROS 2 install.
Using the same base in the sandbox guarantees that **any DDS interop
quirks between the conda-built and apt-built Fast DDS** are exposed by the
demo — we don't want to prove the demo works and then discover in
production that the conda build behaves differently.

## Requirements

- `rmw_fastrtps_cpp` must be the active RMW (enforced via env var in the
  entrypoint).
- The `ROS_DISCOVERY_SERVER` env var points at the server container.

## Contents (to be filled in)

- `Dockerfile` — pixi base + RoboStack ROS libraries
- `pixi.toml` — synced with jennmald/cms-ros-client, with `rmw_fastrtps_cpp` added
- `entrypoint.sh` — sets RMW + discovery-server env vars, drops to shell
