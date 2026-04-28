# ros_server: wraps the production beambot image and adds two things:
#   1. A Fast DDS Discovery Server (TCP 11811) for cross-subnet discovery
#   2. An entrypoint that launches beambot_bringup with use_fake_hardware:=true
#
# The underlying image (ghcr.io/bondada-a/beambot_img_v2:latest) already
# ships `fastdds` CLI and rmw_fastrtps_cpp, so no extra apt installs needed.
FROM ghcr.io/bondada-a/beambot_img_v2:latest

# Override the image's interactive VNC entrypoint -- we run headless here.
COPY entrypoint.sh /ros_server/entrypoint.sh
RUN chmod +x /ros_server/entrypoint.sh

# DDS XML profile path is fixed at runtime via env var set in entrypoint.sh.
# We expect docker-compose to mount /project/dds/ read-only at /dds.

WORKDIR /root/ws/erobs

ENTRYPOINT ["/ros_server/entrypoint.sh"]
