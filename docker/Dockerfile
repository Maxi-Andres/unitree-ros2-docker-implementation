# =============================================================================
# Imagen x86_64 (amd64) + ROS 2 Humble para visualizar el Unitree G1 en esta PC.
#
# Por que esta imagen existe:
#   - El robot usa Ubuntu 22.04 / ROS Humble, por eso TODO corre en Humble.
#   - Esta PC es Ubuntu 26.04, por eso va en Docker.
#   - El paquete 'unitree_description' (modelo URDF) NO esta disponible como
#     binario amd64 (el buildfarm qiayuanl solo tiene arm64, y la rama
#     jammy-humble fue borrada; el repo fuente qiayuanl/unitree_ros2 es privado).
#     Como es un paquete de SOLO DATOS (mallas + xacro, sin binarios), lo
#     vendorizamos: docker/vendor/unitree_description_1.1.0_amd64.deb y lo
#     instalamos dentro del arbol de Humble. Asi no dependemos de repos externos
#     que pueden desaparecer.
# =============================================================================

# ---------- Build stage ----------
FROM ros:humble-ros-core AS build_stage

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    python3-colcon-common-extensions \
    git \
    python3-rosdep \
    ros-humble-rmw-cyclonedds-cpp \
    ros-humble-rosidl-generator-dds-idl \
    libyaml-cpp-dev \
    && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-c"]

# Construir ESTE paquete desde el codigo local (no desde git: asi tomamos
# cualquier cambio local al bridge o al launch). El contexto de build es la
# raiz del repo (ver docker-compose.yaml -> build.context: ..).
WORKDIR /ros2_ws/src
COPY g1_description/ ./g1_description/
WORKDIR /ros2_ws
RUN source /ros_entrypoint.sh && colcon build

# Mensajes de Unitree (unitree_hg / LowState) desde el repo OFICIAL y publico.
WORKDIR /
RUN git clone https://github.com/unitreerobotics/unitree_ros2.git && \
    cd unitree_ros2/cyclonedds_ws && \
    source /ros_entrypoint.sh && \
    colcon build

# ---------- Runtime stage ----------
FROM ros:humble-ros-core

RUN apt-get update && apt-get install -y \
    ros-humble-realsense2-description \
    ros-humble-robot-state-publisher \
    ros-humble-joint-state-publisher \
    ros-humble-xacro \
    ros-humble-rmw-cyclonedds-cpp \
    ros-humble-rosidl-generator-dds-idl \
    && rm -rf /var/lib/apt/lists/*

# Instalar unitree_description vendorizado (solo datos) dentro de Humble.
# El .deb es 'ros-jazzy-...' pero su contenido es independiente de la distro:
# extraemos el share y lo colocamos donde el ament index de Humble lo encuentra.
COPY docker/vendor/unitree_description_1.1.0_amd64.deb /tmp/unitree_description.deb
RUN dpkg-deb -x /tmp/unitree_description.deb /tmp/ud && \
    cp -r /tmp/ud/opt/ros/jazzy/share/unitree_description /opt/ros/humble/share/ && \
    mkdir -p /opt/ros/humble/share/ament_index/resource_index/packages && \
    cp /tmp/ud/opt/ros/jazzy/share/ament_index/resource_index/packages/unitree_description \
       /opt/ros/humble/share/ament_index/resource_index/packages/ && \
    rm -rf /tmp/ud /tmp/unitree_description.deb

# Artefactos compilados del build stage.
COPY --from=build_stage /ros2_ws /ros2_ws
COPY --from=build_stage /unitree_ros2/cyclonedds_ws /unitree_ros2/cyclonedds_ws

ENTRYPOINT [ "/ros_entrypoint.sh" ]
CMD [ "bash" ]
