# What is this

This is a Docker image based on Ubuntu 24.04 with a complete [Zephyr RTOS](https://zephyrproject.org/) development environment pre-installed, including the west build tool, a Zephyr SDK toolchain, and all required dependencies. The images are automatically built and published to GitHub Releases whenever a new Zephyr version is released, so you always have an up-to-date environment ready to use.

Three variants are built, each with its own `Dockerfile` and workflow, differing only in the Zephyr SDK toolchain installed:

| Variant | Dockerfile           | Workflow                                | Toolchain                          | Release tag           |
| ------- | -------------------- | ---------------------------------------- | ----------------------------------- | ---------------------- |
| ARM     | `Dockerfile.arm`     | `.github/workflows/build-arm.yml`       | `arm-zephyr-eabi`                  | `<version>`            |
| Xtensa ESP32 | `Dockerfile.xtensa-esp32` | `.github/workflows/build-xtensa-esp32.yml` | `xtensa-espressif_esp32_zephyr-elf` | `<version>-xtensa-esp32` |
| RISC-V  | `Dockerfile.riscv`   | `.github/workflows/build-riscv.yml`     | `riscv64-zephyr-elf`               | `<version>-riscv`      |

What's Included

| Component      | Details                                     |
| -------------- | ------------------------------------------- |
| Base OS        | Ubuntu 24.04                                |
| Zephyr SDK     | See toolchain table above                   |
| Build tools    | cmake, ninja, gperf, ccache, make, gcc, g++ |
| Python         | python3 + venv + west                       |
| Device support | dfu-util, device-tree-compiler              |
| SSH server     | openssh-server (port 22)                    |
| Utilities      | git, vim, tree, net-tools, curl, iputils-ping, unzip |

# Quick Start

## Import from GitHub Release

Each release contains the Docker image split into multiple 1 GB parts. Download **all** `zephyr-sdk.tar.gz.part*` files from the [Releases](../../releases) page into the same directory, then follow the steps below.

Linux / macOS

```bash
# Merge parts into a single archive
cat zephyr-sdk.tar.gz.part* > zephyr-sdk.tar.gz

# Import into Docker
docker load < zephyr-sdk.tar.gz
```

## Start container

docker-compose.yml

```yaml
services:
  wwl:
    image: zephyr-sdk:<version>     # replace with the actual version tag, e.g. zephyr-sdk:v4.4.2
    container_name: wwl
    environment:
      USER_PASSWORD: wwl
    ports:
      - "10022:22"
      - "11234:1234"
    volumes:
      - /home/wwl/note:/workspace
      - /dev:/dev
    restart: unless-stopped
```

> Replace `<version>` with the tag shown after `docker images`, e.g. `zephyr-sdk:v4.4.2`.

Start the container:

```bash
docker compose up -d
```

Connect via SSH:

```bash
ssh -p 10022 user@localhost
# password: whatever you set in USER_PASSWORD
```

Stop the container:

```bash
docker compose down
```

## What is in docker

user

| User     | Password          | Privileges              |
| -------- | ----------------- | ----------------------- |
| `user` | `USER_PASSWORD` | sudo                    |
| `root` | `root`          | — (SSH login disabled) |

> **Note:** It is strongly recommended to set a custom password via the `USER_PASSWORD` environment variable when running the container.Environment Variables

Directory Structure

| Path                          | Description                                        |
| ----------------------------- | -------------------------------------------------- |
| `/opt/zephyrproject`        | Zephyr workspace (west init)                       |
| `/opt/zephyrproject/zephyr` | Zephyr source tree (`$ZEPHYR_BASE`)              |
| `/opt/zephyrproject/.venv`  | Python virtual environment                         |
| `/opt/zephyr-sdk`           | Zephyr SDK toolchain                               |
| `/workspace`                | Default working directory, mount your project here |
