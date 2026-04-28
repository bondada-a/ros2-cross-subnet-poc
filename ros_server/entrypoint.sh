#!/bin/bash
# ros_server entrypoint.
#
# Sequence:
#   1. Source ROS and the beambot overlay.
#   2. Configure Fast DDS: RMW + profile XML + explicit ROS_DISCOVERY_SERVER.
#   3. Launch the Discovery Server in the background on TCP 11811.
#   4. Launch beambot_bringup with fake hardware (no UR5e / Zivid / pipettor).
#
# This container must be run with --network on net_b and --ip 10.10.2.10 so
# the DDS profile's hard-coded Discovery Server address resolves.
#
# NOTE on shell flags: `set -u` (nounset) is deliberately NOT used because
# ROS's /opt/ros/humble/setup.bash references unbound variables like
# AMENT_TRACE_SETUP_FILES. pipefail + errexit are enough for our purposes.
set -eo pipefail

echo "[ros_server] sourcing ROS environment"
source /opt/ros/humble/setup.bash
source /root/ws/erobs/install/setup.bash

echo "[ros_server] configuring Fast DDS"
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export FASTRTPS_DEFAULT_PROFILES_FILE=/dds/super_client_profile.xml
# ROS_DISCOVERY_SERVER env var is redundant with the XML profile, but the
# ros2 CLI (ros2 topic list, ros2 node list) reads it directly without
# going through the XML, so we set both to be safe.
export ROS_DISCOVERY_SERVER=10.10.2.10:11811
export ROS_DOMAIN_ID=0

# Sanity check the XML profile is actually mounted.
if [[ ! -f "${FASTRTPS_DEFAULT_PROFILES_FILE}" ]]; then
    echo "[ros_server] FATAL: DDS profile not found at ${FASTRTPS_DEFAULT_PROFILES_FILE}" >&2
    echo "[ros_server] compose must mount the repo's dds/ directory at /dds" >&2
    exit 1
fi
echo "[ros_server] DDS profile: ${FASTRTPS_DEFAULT_PROFILES_FILE}"

echo "[ros_server] starting Fast DDS Discovery Server (id=0, tcp 0.0.0.0:11811)"
# -l: listen address; -p: port; -i: server ID matching the XML prefix
# Redirect its output to its own log so the orchestrator's logs stay clean.
fastdds discovery -i 0 -l 0.0.0.0 -p 11811 \
    > /tmp/discovery_server.log 2>&1 &
DISCOVERY_PID=$!
echo "[ros_server] discovery server pid=${DISCOVERY_PID}"

# Give the Discovery Server a moment to bind the socket before the
# orchestrator's participants try to register with it.
sleep 2

# Forward SIGTERM/SIGINT to the discovery server on shutdown so the
# container exits cleanly instead of leaving an orphan.
cleanup() {
    echo "[ros_server] shutting down discovery server (pid=${DISCOVERY_PID})"
    kill "${DISCOVERY_PID}" 2>/dev/null || true
    wait "${DISCOVERY_PID}" 2>/dev/null || true
}
trap cleanup SIGTERM SIGINT EXIT

echo "[ros_server] launching beambot_bringup (use_fake_hardware:=true)"
# enable_vision=false: avoids Zivid connection attempts
# enable_pipettor=false: avoids pipettor serial port attempts
# enable_octomap=false: stays default, no point cloud obstacle map
exec ros2 launch beambot beambot_bringup.launch.py \
    use_fake_hardware:=true \
    enable_vision:=false \
    enable_pipettor:=false
