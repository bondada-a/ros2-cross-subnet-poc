#!/bin/bash
# ws2_client entrypoint.
#
# Does two things:
#   1. Adds a static route to net_a's partner (net_b via the router), since
#      the container is capability-constrained and Docker bridges don't
#      know about each other's subnets.
#   2. Sleeps forever. The demo drives this container via `docker exec`:
#        docker exec ws2_client pixi run -e ros2 ros2 topic list
#        docker exec ws2_client /ws2_client/send-goal.sh
#      so the entrypoint just keeps the container alive.
#
# NOT sourced here:
#   - pixi env (too expensive per-exec; we source it inside docker exec wrappers)
#   - beambot overlay (ditto)
#   - DDS env vars (set in the helper scripts that invoke ros2 commands)
#
# Rationale: keeping the entrypoint minimal means each `docker exec` gets
# a clean shell, no env-var surprises.
set -eo pipefail

# If the caller set WS2_ROUTE_TO, add a static route for that subnet via
# the router. Example: WS2_ROUTE_TO="10.10.2.0/24 via 10.10.1.254".
# This is an env-var contract rather than hardcoded because a fresh clone
# of this repo on a different machine might use different IP ranges.
if [ -n "${WS2_ROUTE_TO:-}" ]; then
    echo "[ws2_client] adding route: ${WS2_ROUTE_TO}"
    ip route add ${WS2_ROUTE_TO}
fi

echo "[ws2_client] container ready. Entrypoint sleeping."
echo "[ws2_client] run ROS commands via: docker exec ws2_client pixi run -e ros2 <cmd>"
exec tail -f /dev/null
