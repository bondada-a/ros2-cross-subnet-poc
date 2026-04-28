# Runbook: WS2 → VM cross-subnet ROS 2 over Fast DDS Discovery Server

Step-by-step instructions for bringing up cross-subnet ROS 2 communication
between the CMS workstation (`ws2`, 10.68.80.222) and the beambot robot
control VM (10.68.82.42).

**What this accomplishes**: a ROS 2 client on `ws2` can discover topics,
actions, and services published by any ROS 2 node on the VM, and send /
receive data to/from them -- as if they were on the same LAN.

**Prerequisites** (assumed already in place based on 2026-04-28 IT work):
- Firewall opens UDP 11811 + UDP 7400-7500 bidirectionally between
  10.68.80.0/24 and 10.68.82.0/24.
- Both hosts can ping each other.
- ROS 2 Humble with Fast DDS installed on both (pixi/RoboStack on ws2,
  apt-based inside the beambot container on the VM).

---

## One-time setup (only needs to be done once per host)

### On the VM (10.68.82.42) — inside the beambot container

1. Launch the beambot container with `--network host` (already standard
   practice -- DDS on a routed subnet requires the container to see the
   host's NIC directly).

2. Verify `fastdds` CLI is present:
   ```bash
   which fastdds
   # expected: /opt/ros/humble/bin/fastdds
   ```

No other one-time setup needed on the VM.

### On ws2 (10.68.80.222)

1. Create the Fast DDS SUPER_CLIENT profile. Save as
   `~/fastdds_super_client.xml`:

   ```xml
   <?xml version="1.0" encoding="UTF-8" ?>
   <profiles xmlns="http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles">
       <participant profile_name="super_client_profile" is_default_profile="true">
           <rtps>
               <builtin>
                   <discovery_config>
                       <discoveryProtocol>SUPER_CLIENT</discoveryProtocol>
                       <discoveryServersList>
                           <RemoteServer prefix="44.53.00.5f.45.50.52.4f.53.49.4d.41">
                               <metatrafficUnicastLocatorList>
                                   <locator>
                                       <udpv4>
                                           <address>10.68.82.42</address>
                                           <port>11811</port>
                                       </udpv4>
                                   </locator>
                               </metatrafficUnicastLocatorList>
                           </RemoteServer>
                       </discoveryServersList>
                   </discovery_config>
               </builtin>
           </rtps>
       </participant>
   </profiles>
   ```

   The `prefix` value is correct for a Discovery Server launched with
   `-i 0`. Do not change it unless the VM side uses a different server ID.

2. (Optional but recommended) Add the DDS env vars to your `~/.bashrc` so
   every new terminal picks them up automatically:

   ```bash
   # --- Fast DDS Discovery Server config for ws2 -> beambot VM ---
   export ROS_DISCOVERY_SERVER="10.68.82.42:11811"
   export ROS_DOMAIN_ID=0
   export FASTRTPS_DEFAULT_PROFILES_FILE=$HOME/fastdds_super_client.xml
   export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
   ```

   If you skip this, you'll need to export these in every new shell before
   running ROS commands.

---

## Per-session checklist (every time you start working)

### Step 1 — Start the Discovery Server on the VM

Shell on **VM**, inside the beambot container:

```bash
source /opt/ros/humble/setup.bash
fastdds discovery -i 0 -l 0.0.0.0 -p 11811
```

Leave this terminal open. You should see:

```
### Server is running ###
  Participant Type:   SERVER
  Server ID:          0
  Server GUID prefix: 44.53.00.5f.45.50.52.4f.53.49.4d.41
  Server Addresses:   UDPv4:[0.0.0.0]:11811
```

The `Server GUID prefix` must match what's in the ws2 XML. If it doesn't,
stop and fix the XML before proceeding.

### Step 2 — Launch the beambot orchestrator on the VM (new terminal)

Shell on **VM**, inside the beambot container (second terminal):

```bash
source /opt/ros/humble/setup.bash
source /root/ws/erobs/install/setup.bash
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export ROS_DISCOVERY_SERVER="10.68.82.42:11811"
export ROS_DOMAIN_ID=0

ros2 launch beambot beambot_bringup.launch.py \
    use_fake_hardware:=true \
    enable_vision:=false \
    enable_pipettor:=false
```

Wait for `MTC Orchestrator (Python) started on 'beambot_execution'`
(~15-30 seconds). Leave this terminal open too.

### Step 3 — Configure ws2 (if not done via `~/.bashrc`)

Shell on **ws2** (new terminal):

```bash
export ROS_DISCOVERY_SERVER="10.68.82.42:11811"
export ROS_DOMAIN_ID=0
export FASTRTPS_DEFAULT_PROFILES_FILE=$HOME/fastdds_super_client.xml
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
```

If you're using the pixi environment from `jennmald/cms-ros-client`:

```bash
cd /path/to/cms-ros-client
pixi shell -e ros2
# then export the four vars above if not already in ~/.bashrc
```

### Step 4 — Restart the ros2 daemon on ws2

**This step is critical**. The daemon caches its graph view at startup
and will NOT pick up new env vars otherwise.

```bash
ros2 daemon stop
ros2 daemon start
sleep 3   # let the daemon register with the Discovery Server
```

Do this every time you open a new terminal OR change any DDS env var.

### Step 5 — Verify discovery works

```bash
ros2 topic list
```

**Expected output** (a subset, with beambot launched):

```
/beambot/current_gripper
/beambot/execution_state
/object_detection_status
/parameter_events
/rosout
/tf
/tf_static
```

```bash
ros2 action list
```

**Expected output**:

```
/beambot_endeffector
/beambot_execution
/beambot_moveto
/beambot_pick_sample
/beambot_pipettor
/beambot_place_sample
/beambot_toolexchange
/beambot_vision_moveto
/beambot_vision_scan
```

If both lists look like the above, you're done -- cross-subnet ROS 2 is
fully operational.

---

## Sending a test goal (optional, proves the full action round-trip)

Requires `beambot_interfaces` to be built locally on ws2 (the pixi env
alone doesn't include it by default):

```bash
# One-time: build beambot_interfaces in a local colcon workspace
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws/src
git clone -b humble-experimental https://github.com/bondada-a/erobs.git
cd ~/ros2_ws
colcon build --packages-select beambot_interfaces \
    --cmake-args \
    -DPython3_EXECUTABLE=$(which python3) \
    -DPYTHON_EXECUTABLE=$(which python3)

# Per-session: source it after the pixi env
source ~/ros2_ws/install/setup.bash
```

Then send a trivial goal:

```bash
# Write a minimal task to a file (avoids shell-quoting issues)
cat > /tmp/goal.json <<'EOF'
{
  "start_gripper": "hande",
  "tasks": [{"task_type": "moveto", "target": "safe_sample_transport"}],
  "poses": {
    "safe_sample_transport": [79.72, -69.5, -81.91, -117.92, -268.05, -157.15]
  }
}
EOF

# ros2 action send_goal mangles JSON via its YAML parser; use rclpy directly.
python3 - <<'PY'
import json, rclpy
from rclpy.action import ActionClient
from rclpy.node import Node
from beambot_interfaces.action import MTCExecution

with open('/tmp/goal.json') as fp:
    full_json = fp.read()

rclpy.init()
node = Node('xsub_test_sender')
client = ActionClient(node, MTCExecution, '/beambot_execution')
print('waiting for action server...')
if not client.wait_for_server(timeout_sec=20):
    print('ERROR: action server unreachable'); raise SystemExit(2)

goal = MTCExecution.Goal(); goal.full_json = full_json
future = client.send_goal_async(goal,
    feedback_callback=lambda fb: print(f'feedback: {fb.feedback.status_message!r}'))
rclpy.spin_until_future_complete(node, future)
handle = future.result()
print(f'goal accepted={handle.accepted}')

rf = handle.get_result_async()
rclpy.spin_until_future_complete(node, rf)
result = rf.result().result
print(f'SUCCESS={result.success}  steps={result.completed_steps}/{result.total_steps}')
print(f'error_message={result.error_message!r}')
rclpy.shutdown()
PY
```

Expected output:

```
waiting for action server...
feedback: 'Executing: Initializing MoveIt'
feedback: 'Executing: batch[1]: moveto'
feedback: 'Task completed'
SUCCESS=True  steps=1/1
error_message=''
```

---

## Sanity checks (when things stop working)

Run these in order. The first one that fails is where the problem lives.

### 1. Basic IP reachability
```bash
# on ws2
ping -c 3 10.68.82.42
```
Expected: replies with low latency. If this fails, network is broken —
nothing else will work. Call IT.

### 2. Discovery Server port reachability (TCP doesn't work — DDS uses UDP)
```bash
# on ws2, send a probe UDP packet
python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.sendto(b'probe', ('10.68.82.42', 11811))
print('packet sent')
"
# on VM, check if it arrived
sudo tcpdump -i any -n 'udp port 11811' -c 1
# expected: one UDP packet logged within a second
```
If the packet never appears on the VM, the firewall regressed and IT
needs to re-open UDP 11811.

### 3. Discovery Server actually running
```bash
# on VM
sudo ss -ulnp | grep 11811
# expected: 0.0.0.0:11811 with `fast-discovery-` as the process
```

### 4. Your DDS env vars
```bash
# on ws2
env | grep -E "^ROS_|^FASTRTPS|^RMW"
```
Expected output (values shown for context):

```
ROS_DISCOVERY_SERVER=10.68.82.42:11811
ROS_DOMAIN_ID=0
FASTRTPS_DEFAULT_PROFILES_FILE=/home/YOU/fastdds_super_client.xml
RMW_IMPLEMENTATION=rmw_fastrtps_cpp
```

### 5. Daemon state
```bash
# on ws2
ros2 daemon stop && ros2 daemon start && sleep 3
ros2 topic list
```

### 6. XML profile syntax
```bash
# on ws2
python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('$HOME/fastdds_super_client.xml')
print('XML parses OK')
print('Server prefix:', tree.find('.//{http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles}RemoteServer').get('prefix'))
"
```
Expected: `Server prefix: 44.53.00.5f.45.50.52.4f.53.49.4d.41`.
If different, fix the XML to match the VM server's actual prefix.

---

## Common failure modes and fixes

| Symptom | Cause | Fix |
|---|---|---|
| `ros2 topic list` shows only `/parameter_events` and `/rosout` | daemon started before env vars were set | Step 4 — `ros2 daemon stop && start` |
| `/chatter` is visible when talker runs but disappears when you stop the talker (listener still running) | XML profile missing or wrong — you are in CLIENT mode, need SUPER_CLIENT | Verify Step 3's `FASTRTPS_DEFAULT_PROFILES_FILE` is set AND the XML has `<discoveryProtocol>SUPER_CLIENT</discoveryProtocol>` |
| `action server not available` | beambot orchestrator isn't running, or firewall dropped data-transport UDP | Check Step 2; run sanity check #3 |
| Intermittent visibility, topics appear/disappear | firewall is blocking some ports in the 7400-7500 range (only partial allow) | Ask IT to verify the UDP allow rule covers the whole 7400-7500 range, not a subset |
| `ros2 action send_goal` fails with `Invalid JSON` | CLI's YAML parser stripped quotes from your JSON | Use the Python client pattern shown in the "Sending a test goal" section |
