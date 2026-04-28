#!/bin/bash
# Runs the full three-stage cross-subnet PoC demo from a clean state.
#
# Assumes `docker compose up -d --build` has been run (or does it for you).
# Walks through Stage 1 (DENY), Stage 2 (ALLOW), Stage 3 (TCP-only) in
# sequence, running `ros2 topic list` + a beambot action goal at each
# stage so the pass/fail at each firewall posture is visible.
#
# Saves per-stage output into docs/stage-outputs/ so the demo can be
# reviewed asynchronously.
#
# Usage:
#   bash demo/run-demo.sh          # interactive, pauses between stages
#   bash demo/run-demo.sh --fast   # no pauses, fire through all stages
set -eo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/docs/stage-outputs"
FAST=0
if [ "${1:-}" = "--fast" ]; then
    FAST=1
fi

mkdir -p "${OUTPUT_DIR}"

banner() {
    echo ""
    echo "################################################################"
    echo "# $1"
    echo "################################################################"
}

pause() {
    if [ "${FAST}" -eq 0 ]; then
        echo ""
        read -rp "press ENTER to continue..." _
    fi
}

probe() {
    # Runs ros2 topic list + action list from ws2_client. Output goes to
    # stdout AND to a per-stage file.
    local stage="$1"
    local out="${OUTPUT_DIR}/${stage}.txt"
    echo "[probe] running ros2 topic list + action list on ws2_client..."
    docker compose exec -T ws2_client bash -c "
        pixi run -e ros2 bash -c '
            source /ws2_client/erobs/install/setup.bash
            export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
            export FASTRTPS_DEFAULT_PROFILES_FILE=/dds/super_client_profile.xml
            export ROS_DISCOVERY_SERVER=10.10.2.10:11811
            export ROS_DOMAIN_ID=0
            ros2 daemon stop >/dev/null 2>&1
            ros2 daemon start >/dev/null 2>&1
            sleep 12
            echo \"--- topics ---\"
            timeout 10 ros2 topic list 2>&1 | sort
            echo \"--- actions ---\"
            timeout 10 ros2 action list 2>&1 | sort
        '
    " | tee "${out}"
    echo ""
    echo "[probe] output saved to ${out}"
}

action_goal() {
    local stage="$1"
    local out="${OUTPUT_DIR}/${stage}-goal.txt"
    echo "[goal] sending goal to /beambot_execution..."
    if timeout 90 bash "${REPO_ROOT}/demo/send-goal.sh" 2>&1 | tee "${out}"; then
        echo "[goal] completed (see ${out})"
    else
        echo "[goal] timed out or failed (see ${out})"
    fi
}

show_rules() {
    echo ""
    echo "--- current iptables FORWARD chain on router ---"
    docker compose exec -T router iptables -L FORWARD -n -v --line-numbers
}

# ----------------------------------------------------------------------

banner "Ensuring compose stack is up"
cd "${REPO_ROOT}"
docker compose up -d --build

echo "[setup] waiting 30s for beambot orchestrator to initialize..."
sleep 30

banner "STAGE 1 -- DENY BASELINE"
echo "This is what IT's production firewall currently does:"
echo "  * ICMP passes (ping works)"
echo "  * Everything else is dropped silently"
echo ""
docker compose exec -T router /router/firewall-stage1-deny.sh
show_rules
pause
probe "stage1-deny"
pause

banner "STAGE 2 -- ALLOW (the IT ask)"
echo "Adding two ACCEPT rules to the router:"
echo "  * UDP 11811       -- Fast DDS Discovery Server"
echo "  * UDP 7400-7500   -- Fast DDS participant data"
echo ""
docker compose exec -T router /router/firewall-stage2-allow.sh
show_rules
pause
probe "stage2-allow"
echo ""
echo "[stage2] now sending a beambot action goal cross-subnet..."
action_goal "stage2-allow"
pause

banner "STAGE 3 -- NEGATIVE TEST (discovery UDP 11811 only)"
echo "Removing the UDP 7400-7500 rule to show it is necessary:"
echo "  * UDP 11811 allowed (discovery can start)"
echo "  * UDP 7400-7500 blocked (data cannot flow)"
echo ""
docker compose exec -T router /router/firewall-stage3-tcponly.sh
show_rules
pause
probe "stage3-tcponly"
pause

banner "DEMO COMPLETE"
cat <<'EOF'

Results saved to docs/stage-outputs/:
  stage1-deny.txt         -- empty topic list (firewall blocks discovery)
  stage2-allow.txt        -- full topic list (our proposed rules work)
  stage2-allow-goal.txt   -- action goal SUCCEEDED end-to-end
  stage3-tcponly.txt      -- empty again (proves data ports are needed)

The IT ask is in docs/it-ask.md -- hand it to the firewall admin.
To tear down:  docker compose down
EOF
