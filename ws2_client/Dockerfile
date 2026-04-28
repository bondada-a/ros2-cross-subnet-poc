# ws2_client: pixi-based ROS 2 client that mirrors the production ws2
# workstation. RoboStack ROS 2 from conda-forge (not apt), identical to
# the jennmald/cms-ros-client environment but with rmw_fastrtps_cpp
# explicitly pinned and beambot_interfaces built from source so we can
# send goals to /beambot_execution.
#
# Build time: ~5-10 minutes (conda solve + ROS download + interface build).
# Image size: ~4GB.
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# System dependencies:
#   - curl for pixi installer
#   - git for cloning erobs (beambot_interfaces source)
#   - ca-certificates so curl + git can do HTTPS
#   - build-essential + cmake: used by colcon when compiling beambot_interfaces
#     (the interface package generates C/C++ code, not just Python)
#   - iproute2: ip route add during container startup (route table fix-up)
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        git \
        ca-certificates \
        build-essential \
        cmake \
        iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Install pixi. We pin to a known-good version rather than `latest` so a
# pixi release tomorrow can't silently change our sandbox. 0.45.0 (Feb 2026)
# is modern enough to support the `[workspace]` syntax used by the upstream
# cms-ros-client pixi.toml -- earlier versions (<0.40) only know `[project]`.
ENV PIXI_VERSION=0.45.0
RUN curl -fsSL https://pixi.sh/install.sh | PIXI_VERSION=v${PIXI_VERSION} bash \
    && cp /root/.pixi/bin/pixi /usr/local/bin/pixi \
    && pixi --version

WORKDIR /ws2_client

# Copy our pixi.toml (modified from jennmald/cms-ros-client -- see file for
# deviations) and run pixi install to materialize the ros2 environment.
# This is the slow step (~5 min on a good connection).
COPY pixi.toml /ws2_client/pixi.toml
RUN pixi install -e ros2

# Pin the pixi manifest location globally so `pixi run -e ros2` works
# regardless of current working directory. Without this, pixi resolves
# the project from CWD and fails with "unknown environment" whenever we
# step outside /ws2_client.
ENV PIXI_PROJECT_MANIFEST=/ws2_client/pixi.toml

# Build beambot_interfaces so the client has the MTCExecution action type.
# Without this, `ros2 action send_goal /beambot_execution ...` fails with
# "action type not found". We don't need the whole beambot package -- just
# the interface definitions.
#
# Note: we stay in /ws2_client (where pixi can find its manifest) and
# pass the source tree via colcon's --base-paths. This is cleaner than
# cd'ing into /ws2_client/erobs and fighting pixi's project resolution.
RUN git clone --depth=1 -b humble-experimental \
        https://github.com/bondada-a/erobs.git /ws2_client/erobs \
    && pixi run -e ros2 bash -c ' \
        cd /ws2_client/erobs && \
        colcon build --packages-select beambot_interfaces \
            --cmake-args \
            -DPython3_EXECUTABLE=$(which python3) \
            -DPYTHON_EXECUTABLE=$(which python3) \
    '

# Entrypoint sources everything and drops to a shell. The demo uses
# `docker exec ws2_client <command>` to run ros2 topic/action/etc.
COPY entrypoint.sh /ws2_client/entrypoint.sh
RUN chmod +x /ws2_client/entrypoint.sh

ENTRYPOINT ["/ws2_client/entrypoint.sh"]
