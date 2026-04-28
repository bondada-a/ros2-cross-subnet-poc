#!/bin/bash
# Sends a single /beambot_execution goal from ws2_client across the router.
#
# Approach: copy goal.json into the container, use Python + rclpy's
# ActionClient directly rather than `ros2 action send_goal`. The CLI
# command's YAML parser mangles our JSON payload (strips quotes from
# "key": "value"), whereas rclpy accepts the full_json as a string
# parameter cleanly.
#
# Usage (run on host):
#   ./demo/send-goal.sh
#
# Expected under Stage 2 (ALLOW):
#   Goal accepted, feedback streamed, result returned with success=true.
# Expected under Stage 1 or 3:
#   Script hangs at "Waiting for action server" then times out.
set -eo pipefail

GOAL_JSON_PATH="$(dirname "$0")/goal.json"
SENDER_PY_PATH="$(dirname "$0")/_send_goal.py"

if [ ! -f "${GOAL_JSON_PATH}" ]; then
    echo "ERROR: goal.json not found at ${GOAL_JSON_PATH}" >&2
    exit 2
fi
if [ ! -f "${SENDER_PY_PATH}" ]; then
    echo "ERROR: _send_goal.py not found at ${SENDER_PY_PATH}" >&2
    exit 2
fi

echo "[send-goal] copying goal.json and sender script into ws2_client..."
docker cp "${GOAL_JSON_PATH}" ws2_client:/tmp/goal.json
docker cp "${SENDER_PY_PATH}" ws2_client:/tmp/_send_goal.py

echo "[send-goal] invoking Python action client from inside ws2_client..."
docker exec ws2_client pixi run -e ros2 bash -c '
    source /ws2_client/erobs/install/setup.bash
    export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
    export FASTRTPS_DEFAULT_PROFILES_FILE=/dds/super_client_profile.xml
    export ROS_DISCOVERY_SERVER=10.10.2.10:11811
    export ROS_DOMAIN_ID=0
    python3 /tmp/_send_goal.py /tmp/goal.json
'
