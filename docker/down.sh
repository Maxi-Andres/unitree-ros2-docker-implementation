#!/usr/bin/env bash
# Detiene y elimina los contenedores de la visualizacion del G1.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
exec $DC -f "$HERE/docker-compose.yaml" down "$@"
