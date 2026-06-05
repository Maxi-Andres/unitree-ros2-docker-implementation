# g1_description — visualización del Unitree G1

Visualiza en RViz el estado real de las articulaciones de un Unitree G1.

## Cómo funciona (reparto de trabajo)

```
Robot G1 (arm64)                ESTA PC (x86_64 + RTX, todo en Docker/Humble)
─────────────────              ──────────────────────────────────────────────
publica lf/lowstate  ──DDS──>  lowstate_bridge      (lowstate -> /joint_states)
(no hace nada más)             robot_state_publisher (URDF -> /tf, a 500 Hz)
                               rviz                  (render 3D con la GPU)
```

El robot solo publica su telemetría cruda por la red. **Todo el procesamiento y el
render lo hace esta PC**, así el robot queda libre para su control en tiempo real.
La GPU NVIDIA la usa únicamente RViz, para renderizar el modelo 3D.

## Requisitos en esta PC (una sola vez)

1. **Docker** con el runtime NVIDIA (ya configurado en `/etc/docker/daemon.json`).
2. **No usar `sudo` en cada comando** — agregá tu usuario al grupo docker y reiniciá sesión:
   ```bash
   sudo usermod -aG docker $USER
   # cerrá sesión y volvé a entrar (o reiniciá)
   ```

## Uso

```bash
# 1) (cuando el robot esté conectado) averiguá el nombre de tu interfaz de red:
ip a                      # buscá la que aparece al conectar el robot, p.ej. enp3s0
                          # los Unitree usan la subred 192.168.123.0/24

# 2) levantá todo (construye la imagen la primera vez, tarda):
ROBOT_IFACE=enp3s0 ./docker/up.sh

# 3) en otra terminal, verificá GPU + flujo de datos:
./docker/check.sh

# 4) para frenar:
./docker/down.sh
```

Sin robot todavía podés probar solo RViz (se abre vacío, confirma GPU/X11):
```bash
docker compose -f docker/docker-compose.yaml up rviz
```

## Verificar que usa la GPU (no la CPU)

`./docker/check.sh` lo hace automáticamente. A mano:
```bash
nvidia-smi                                          # debe listar un proceso rviz2
docker exec rviz bash -lc "glxinfo | grep -i 'OpenGL renderer'"
```
Correcto → `NVIDIA GeForce RTX ...`. Si dice `llvmpipe`/`Mesa` está renderizando por **CPU**.

## Notas técnicas

- **Humble obligatorio**: el robot usa Ubuntu 22.04/Humble; por eso todo corre en Humble
  dentro de Docker (esta PC es Ubuntu 26.04).
- **`unitree_description` vendorizado**: el modelo URDF está en
  `docker/vendor/unitree_description_1.1.0_amd64.deb` porque el repo y el buildfarm de origen
  desaparecieron. Es solo datos (mallas + xacro), válido en cualquier arquitectura.
- **DDS**: todo usa `rmw_cyclonedds_cpp` y `CYCLONEDDS_URI` apuntando a `ROBOT_IFACE`. Si no
  ves `/lf/lowstate`, casi siempre es la interfaz mal puesta o el robot en otra subred.
- **Editar el bridge sin reconstruir**: `docker-compose.yaml` monta
  `g1_description/g1_description/lowstate_jointstate_bridge.py` dentro del contenedor; editá y
  reiniciá el servicio `lowstate_bridge`.
# unitree-ros2-docker-implementation
# unitree-ros2-docker-implementation
