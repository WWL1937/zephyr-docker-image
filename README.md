# What is this

This is a Docker image based on Ubuntu 24.04 with a complete [Zephyr RTOS](https://zephyrproject.org/) development environment pre-installed, including the west build tool, a Zephyr SDK toolchain, and all required dependencies. The images are automatically built and published to GitHub Releases whenever a new Zephyr version is released, so you always have an up-to-date environment ready to use.

Three variants are built from the same Dockerfile, each with its own workflow, differing only in the Zephyr SDK toolchain installed (build argument TOOLCHAIN):

| Variant         | Workflow                                   | TOOLCHAIN build arg                 | Release tag            |
| --------------- | ------------------------------------------ | ----------------------------------- | ---------------------- |
| ARM             | .github/workflows/build-arm.yml            | arm-zephyr-eabi (default)           | VERSION-arm            |
| Xtensa ESP32-S3 | .github/workflows/build-xtensa-esp32s3.yml | xtensa-espressif_esp32s3_zephyr-elf | VERSION-xtensa-esp32s3 |
| RISC-V          | .github/workflows/build-riscv.yml          | riscv64-zephyr-elf                  | VERSION-riscv          |

Local build example: docker build --build-arg TOOLCHAIN=riscv64-zephyr-elf -t zephyr-sdk-riscv:v4.5.0 .

What's Included

| Component      | Details                                              |
| -------------- | ---------------------------------------------------- |
| Base OS        | Ubuntu 24.04                                         |
| Zephyr SDK     | See toolchain table above                            |
| Build tools    | cmake, ninja, gperf, ccache, make, gcc, g++          |
| Python         | python3 + venv + west                                |
| Device support | dfu-util, device-tree-compiler                       |
| SSH server     | openssh-server (port 22)                             |
| Utilities      | git, vim, tree, net-tools, curl, iputils-ping, unzip |

# Intended Usage

Design goals:

1. The image only provides everything the Zephyr development environment depends on (SDK, west, build tools, SSH). Your code and data live outside the image.
2. Deploy with a compose file and mount host folders for persistence, so containers can be recreated or upgraded without losing work.
3. For multi-developer hosts: create one host user per developer; each developer gets one container and one persistent host folder.

Recommended setup for each developer (e.g. alice):

1. Create the host user and a private workspace folder owned by that user:
   ```bash
   sudo useradd -m alice
   sudo mkdir -p /dev_workspace/alice && sudo chown alice:alice /dev_workspace/alice
   id alice          # note uid / gid, used as PUID / PGID below
   ```
2. Copy the compose example below and create a .env with that developer's DEV_NAME, ports, PUID/PGID, USER_PASSWORD and WORKSPACE_DIR. DEV_NAME and host ports must be unique per developer.
3. docker compose -p alice up -d, then ssh -p SSH_PORT user@HOST and work in ~/workspace.

Do not let several containers share one host folder: the entrypoint changes the ownership of the mounted folder to PUID:PGID, so the last container to start would take it over.

# Quick Start

## Import from GitHub Release

Each release contains the Docker image split into multiple 1 GB parts (artifact name depends on the variant, e.g. zephyr-sdk-arm.tar.gz.part*, zephyr-sdk-xtensa-esp32s3.tar.gz.part*, zephyr-sdk-riscv.tar.gz.part*). Download all parts for your chosen variant from the [Releases](../../releases) page into the same directory, then follow the steps below.

Linux / macOS

```bash
# Merge parts into a single archive (example: ARM variant)
cat zephyr-sdk-arm.tar.gz.part* > zephyr-sdk-arm.tar.gz

# Import into Docker
docker load < zephyr-sdk-arm.tar.gz
```

## Start container

docker-compose.yml

```yaml
services:
  zephyr:
    image: ${IMAGE:-zephyr-sdk-arm:v4.5.0}
    container_name: zephyr-${DEV_NAME:?set DEV_NAME in .env}
    environment:
      USER_PASSWORD: ${USER_PASSWORD:-user}
      PUID: ${PUID:-1000}
      PGID: ${PGID:-1000}
    ports:
      - "${SSH_PORT:-10022}:22"
      - "${GDB_PORT:-11234}:1234"
    volumes:
      - ${WORKSPACE_DIR:?set WORKSPACE_DIR in .env}:/home/user/workspace
      - /dev:/dev                       # expose host devices (serial, debug probes)
          device_cgroup_rules:
            - 'c 166:* rmw'   # ttyACM (USB CDC ACM serial)
            - 'c 188:* rmw'   # ttyUSB (USB-to-serial adapters)
            - 'c 189:* rmw'   # USB devices (/dev/bus/usb, debug probes)
    restart: unless-stopped
```

All per-developer values come from a .env file next to docker-compose.yml. Example for developer alice:

```bash
IMAGE=zephyr-sdk-arm:v4.5.0
DEV_NAME=alice
USER_PASSWORD=change-me
PUID=1003
PGID=1003
SSH_PORT=10023
GDB_PORT=11235
WORKSPACE_DIR=/dev_workspace/alice
```

Variables

| Variable      | Default (if unset)    | Description                                                                                                                  |
| ------------- | --------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| IMAGE         | zephyr-sdk-arm:v4.5.0 | Image and tag, as shown by docker images.                                                                                    |
| DEV_NAME      | required              | Developer name, used in the container name. Must be unique per developer.                                                    |
| USER_PASSWORD | user                  | SSH password of user. Set your own; the default is weak.                                                                     |
| PUID          | 1000                  | UID of user inside the container. Set to the host owner of the mounted folder (id -u) so files are owned by you on both sides. |
| PGID          | 1000                  | GID of user inside the container (id -g). Same purpose as PUID.                                                              |
| SSH_PORT      | 10022                 | Host port mapped to the container's SSH port 22. Must be unique per developer.                                               |
| GDB_PORT      | 11234                 | Host port mapped to the container's GDB port 1234. Must be unique per developer.                                             |
| WORKSPACE_DIR | required              | Persistent host folder mounted to ~/workspace. One folder per developer.                                                     |

At start the entrypoint remaps user to PUID:PGID. If the owner of the mounted ~/workspace folder differs from PUID:PGID, it recursively chowns the folder to that owner (once; later starts skip it).

Start the container:

```bash
docker compose up -d
```

Connect via SSH:

```bash
ssh -p 10023 user@localhost   # use your SSH_PORT
```

Stop the container:

```bash
docker compose down
```

## What is in docker

Directory Structure

| Path                      | Description                                                  |
| ------------------------- | ------------------------------------------------------------ |
| /opt/zephyrproject        | Zephyr workspace (west init)                                 |
| /opt/zephyrproject/zephyr | Zephyr source tree ($ZEPHYR_BASE)                            |
| /opt/zephyrproject/.venv  | Python virtual environment                                   |
| /opt/zephyr-sdk           | Zephyr SDK toolchain                                         |
| /home/user/workspace      | Default working directory, mount your persistent folder here |
