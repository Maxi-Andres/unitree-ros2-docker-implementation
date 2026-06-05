#!/usr/bin/env bash
# =============================================================================
# Verifica que (1) RViz renderiza con la GPU NVIDIA y (2) los topics de ROS
# fluyen. Corre esto en otra terminal MIENTRAS la pila esta levantada.
# =============================================================================
set -uo pipefail

echo "============================================================"
echo " 1) GPU: procesos usando la NVIDIA (deberia aparecer rviz2)"
echo "============================================================"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv 2>/dev/null
  nvidia-smi | grep -iE "rviz|python|ros" || echo "  (sin procesos ROS/RViz aun; abri RViz primero)"
else
  echo "  nvidia-smi no disponible en el host"
fi

echo
echo "============================================================"
echo " 2) GPU: renderizador OpenGL DENTRO del contenedor rviz"
echo "    Correcto: 'NVIDIA'. MALO (CPU): 'llvmpipe' / 'Mesa'."
echo "============================================================"
if docker ps --format '{{.Names}}' | grep -q '^rviz$'; then
  docker exec rviz bash -lc \
    "command -v glxinfo >/dev/null || (apt-get update -qq && apt-get install -y -qq mesa-utils >/dev/null 2>&1); \
     glxinfo 2>/dev/null | grep -iE 'OpenGL vendor|OpenGL renderer' || echo '  glxinfo fallo (revisar X11/DISPLAY)'"
else
  echo "  el contenedor 'rviz' no esta corriendo"
fi

echo
echo "============================================================"
echo " 3) ROS 2: topics y flujo de datos"
echo "    /lf/lowstate  -> viene del robot"
echo "    /joint_states -> lo produce el bridge"
echo "    /tf           -> lo produce robot_state_publisher"
echo "============================================================"
if docker ps --format '{{.Names}}' | grep -q '^lowstate_bridge$'; then
  docker exec lowstate_bridge bash -lc \
    "source /ros2_ws/install/setup.bash && \
     source /unitree_ros2/cyclonedds_ws/install/setup.bash && \
     echo '-- topics --'; ros2 topic list; \
     echo '-- Hz de /joint_states (5s) --'; timeout 5 ros2 topic hz /joint_states || echo '  (sin datos: revisar robot/red/ROBOT_IFACE)'"
else
  echo "  el contenedor 'lowstate_bridge' no esta corriendo"
fi
