# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A ROS 2 (Humble, `ament_python`) package that visualizes a Unitree G1 humanoid's real
joint state. It bridges the robot's Unitree SDK telemetry into standard ROS `/joint_states`
and drives `robot_state_publisher` so the G1 can be seen in RViz/Foxglove. There is no
simulation here — this consumes live `LowState` from a physical (or onboard) G1.

The repo root is `g1_description/`, but the actual ROS package lives in the nested
`g1_description/g1_description/` directory (the colcon source dir). The `docker/`
directory holds the deployment image and compose stack.

## Architecture & data flow

```
Unitree G1 (DDS, CycloneDDS)
   │  unitree_hg/msg/LowState  on topic  lf/lowstate
   ▼
lowstate_jointstate_bridge   (this package's only node)
   │  sensor_msgs/JointState  on  /joint_states
   ▼
robot_state_publisher  +  robot_description (xacro from unitree_description)
   │  /tf, /tf_static
   ▼
RViz / Foxglove
```

- **`lowstate_jointstate_bridge.py`** — subscribes to `lf/lowstate`, maps the first 29
  `motor_state[i].q` values to a hardcoded, **order-sensitive** `joint_names` list, and
  republishes as `JointState`. The index→name mapping is the contract with the G1's motor
  ordering; do not reorder `joint_names` without confirming it matches the firmware's motor
  index layout. Publisher uses BEST_EFFORT QoS (depth 1) to match the high-rate sensor stream.
- **`robot_state_publisher.launch.py`** — generates `robot_description` by running `xacro`
  on `unitree_description`'s `urdf/g1/robot.xacro` (an external dependency, not vendored here)
  with `simulation:=false`. Launch args: `robot_type` (default `g1`), `network_interface`
  (default `eth0`). Runs at `publish_frequency: 500.0`.

The URDF/meshes come from the `unitree_description` package. **This is vendored** in
`docker/vendor/unitree_description_1.1.0_amd64.deb` (data-only: meshes + xacro, no compiled
code) and extracted into Humble's share tree during the Docker build. We vendor it because
the upstream source (`qiayuanl/unitree_ros2`) is now private/404 and the apt buildfarm
(`qiayuanl/unitree_buildfarm`) dropped its `jammy-humble` branches — only `noble-jazzy`
remains. Do not re-point the Dockerfile at that buildfarm; it will 404.

## Target platform: x86_64 + Humble

The robot runs Ubuntu 22.04 / ROS Humble, so everything here is **Humble**. This dev PC runs
Ubuntu 26.04, so it all runs in **Docker** (native Humble install is impossible on 26.04).
The Docker image builds for the **host arch (amd64)** — there is no `platform:` override.
The original arm64-only setup (for the robot's Jetson) is gone; see git history if needed.

## Critical dependency: unitree_ros2 messages

The `unitree_hg` messages (`LowState`, `motor_state`) are **not** on the public ROS index.
They are built from the **official, public** `github.com/unitreerobotics/unitree_ros2` into a
separate workspace at `/unitree_ros2/cyclonedds_ws` (note: different from the now-private
`qiayuanl` fork). Any session that runs the bridge must source **both** overlays:

```bash
source /ros2_ws/install/setup.bash
source /unitree_ros2/cyclonedds_ws/install/setup.bash
```

This stack requires `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` end to end — the Unitree DDS
domain is CycloneDDS, and mixing RMWs silently breaks topic discovery (this is the subject
of several recent debugging commits). Verify the env var is actually exported in every shell
that runs a node before debugging "no messages".

## Common commands

Build (from a colcon workspace whose `src/` contains this repo):
```bash
colcon build --packages-select g1_description
source install/setup.bash
```

Run the two nodes (each needs both overlays sourced, see above):
```bash
ros2 run g1_description lowstate_jointstate_bridge
ros2 launch g1_description robot_state_publisher.launch.py network_interface:=eth0
```

Lint / test (ament defaults — copyright, flake8, pep257):
```bash
colcon test --packages-select g1_description
colcon test-result --verbose
# single suite:
python3 -m pytest g1_description/test/test_flake8.py
```

## Docker deployment

`docker/Dockerfile` is a multi-stage amd64/Humble build: stage 1 `COPY`s this repo's
package and `colcon build`s it, then clones+builds the official `unitree_ros2`
`cyclonedds_ws` (for `unitree_hg` msgs); stage 2 installs runtime deps, extracts the
vendored `unitree_description` deb into Humble's share, and copies the build artifacts.

`docker/docker-compose.yaml` runs `lowstate_bridge`, `robot_state_publisher`, and `rviz`
with `network_mode: host` and `privileged` for DDS. All three set
`RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` and a `CYCLONEDDS_URI` pinned to `${ROBOT_IFACE:-eth0}`
— the host network interface connected to the robot (Unitree subnet `192.168.123.0/24`).

Helper scripts (preferred entry points):
```bash
ROBOT_IFACE=enp3s0 ./docker/up.sh    # xhost + build + up all services
./docker/check.sh                    # verify GPU rendering + ROS topic flow
./docker/down.sh                     # stop & remove
```

The compose file **bind-mounts** the local `lowstate_jointstate_bridge.py` over the
installed copy inside the container, so you can iterate on the bridge without rebuilding
the image — edit the file, restart the service. The path is pinned to
`.../python3.10/site-packages/...` (Humble = Python 3.10).
`rviz` uses `runtime: nvidia` + X11 forwarding (`DISPLAY`, mounted `.Xauthority`); `up.sh`
runs `xhost +local:root` so the container can open the window. Verify the GPU is actually
rendering with `check.sh` — inside the rviz container `glxinfo` must show **NVIDIA**, not
`llvmpipe` (which would mean CPU/software rendering).
