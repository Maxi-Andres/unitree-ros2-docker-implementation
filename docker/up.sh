#!/usr/bin/env bash
# =============================================================================
# Levanta la visualizacion del Unitree G1 en esta PC (x86 + Humble + GPU).
#
# Uso:
#   ./docker/up.sh                 # interfaz por defecto (eth0)
#   ROBOT_IFACE=enp3s0 ./docker/up.sh   # con la interfaz real al robot
#
# La primera vez construye la imagen y baja ~4GB de RViz (tarda).
# Cortar con Ctrl+C; para borrar contenedores: ./docker/down.sh
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$HERE/docker-compose.yaml"

# Elegir 'docker compose' (v2) o 'docker-compose' (v1)
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
else
  DC="docker-compose"
fi

# Interfaz de red hacia el robot (DDS). Cambiala con: export ROBOT_IFACE=enp3s0
export ROBOT_IFACE="${ROBOT_IFACE:-eth0}"
echo ">> Interfaz DDS hacia el robot: ROBOT_IFACE=$ROBOT_IFACE"
if ! ip link show "$ROBOT_IFACE" >/dev/null 2>&1; then
  echo "   AVISO: la interfaz '$ROBOT_IFACE' no existe en esta PC."
  echo "   Conecta el robot y corre 'ip a' para ver el nombre real, luego:"
  echo "     ROBOT_IFACE=<tu_interfaz> ./docker/up.sh"
fi

# Permitir que los contenedores abran ventanas en tu pantalla (RViz).
if command -v xhost >/dev/null 2>&1; then
  xhost +local:root >/dev/null 2>&1 || true
  echo ">> Acceso X11 habilitado para contenedores (xhost +local:root)"
fi

echo ">> Construyendo (si hace falta) y levantando: bridge + robot_state_publisher + rviz"
exec $DC -f "$COMPOSE_FILE" up --build "$@"
