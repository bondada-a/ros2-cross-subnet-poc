# demo/

Scripted three-stage demonstration. Designed to be run live in front of IT
or captured for async sharing.

## Stages

1. **Stage 1 — DENY baseline**
   Router enforces default-deny between subnets. Attempt `ros2 topic list`
   on `ws2_client`. Expected: empty list, discovery times out.

2. **Stage 2 — Required ports opened**
   Router adds ACCEPT rules for TCP 11811 + UDP 7400-7410. Re-run
   `ros2 topic list` — beambot topics visible. Send a goal to
   `/beambot_execution` (a trivial `moveto` to `safe_sample_transport`).
   Expected: goal accepted, feedback streamed, result returned.

3. **Stage 3 — Negative test (TCP only)**
   Keep TCP 11811 ACCEPT, remove UDP 7400-7410 ACCEPT. Discovery still
   works (topic list is visible) but action data does not flow. Expected:
   goal hangs or returns transport error.

## Contents (to be filled in)

- `run.sh` — orchestrates the three stages, captures output
- `goal.json` — minimal beambot task: single `moveto` to `safe_sample_transport`
- `send_goal.py` — sends the goal via `ros2 action send_goal` or roslibpy
