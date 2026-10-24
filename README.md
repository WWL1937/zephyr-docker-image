# What is this

This is a Docker image based on Ubuntu 24.04 with a complete [Zephyr RTOS](https://zephyrproject.org/) development environment pre-installed, including the west build tool, a Zephyr SDK toolchain, and all required dependencies. The images are automatically built and published to GitHub Releases whenever a new Zephyr version is released, so you always have an up-to-date environment ready to use.

Three variants are built, each with its own `Dockerfile` and workflow, differing only in the Zephyr SDK toolchain installed:

| Variant | Dockerfile           | Workflow                                | Toolchain                          | Release tag           |
| ------- | -------------------- | ---------------------------------------- | ----------------------------------- | ---------------------- |
| ARM     | `Dockerfile.arm`     | `.github/workflows/build-arm.yml`       | `arm-zephyr-eabi`                  | `<version>-arm`            |
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

## Gitee Go pipeline

`.workflow/build-{arm,riscv,xtensa-esp32}.yml` are single-step alternatives to
the GitHub workflows. One `build@gcc` task does everything in order: resolve the
Zephyr version, build the image with buildah (no Docker daemon required), export
and split it, then create the Gitee Release and upload the parts. The GitHub
workflows are untouched; the Dockerfiles keep `ubuntu:24.04` as the default base.

Platform differences, all measured with `.workflow/probe-cloud-build.yml`:

| GitHub | Gitee Go |
| --- | --- |
| VM with a Docker daemon, `docker build` | buildah `--isolation chroot`, because cloud tasks get no Docker socket |
| `--secret` from BuildKit | same, via `buildah --secret` |
| 1 GB release parts | 95 MiB parts, because one Gitee attachment is capped at 100 MB |
| `GITHUB_TOKEN` injected automatically | you supply a Gitee token |
| runs as an unprivileged user | container is root and has no `sudo`; the script detects this |

**Run `probe-cloud-build` first.** Docker Hub (`registry-1.docker.io`) is blocked
from the Gitee cloud, so the base image must come from a mirror the probe can
reach. The probe also prints disk/CPU/memory, host reachability, and whether
buildah can mount secrets. Use its output to fill `BASE_IMAGE` and `APT_MIRROR`.

Required parameters:

| Parameter | Value |
| --------- | ----- |
| `RELEASE_REPOSITORY` | Target Gitee repository, `owner/repo` |
| `RELEASE_TOKEN` | Gitee token with release/attachment write access (secret) |

Optional parameters:

| Parameter | Value |
| --------- | ----- |
| `ZEPHYR_VERSION` | Zephyr tag, e.g. `v4.4.2`; empty resolves the latest release |
| `BASE_IMAGE` | Base image, e.g. `<mirror>/library/ubuntu:24.04`; default `ubuntu:24.04` |
| `APT_MIRROR` | apt mirror host, e.g. `mirrors.aliyun.com`; default keeps archive.ubuntu.com |
| `GITHUB_TOKEN` | Raises the SDK download rate limit; passed as a build secret |

The plugin runs commands with xtrace enabled, so the script starts with `set +x`
and never expands the token into a command line. Release tags are
`<version>-<variant>`, matching GitHub; an existing release is skipped before the
expensive build starts. Parts use four-digit suffixes plus `SHA256SUMS`:
`sha256sum -c SHA256SUMS`, then `cat zephyr-sdk-<variant>.tar.gz.part* | docker load`.
A release stays a prerelease until every upload succeeds.

**Limits to expect:** free Gitee Go is 500 minutes/month per account plus 200 per
repository, and the cloud container seen in testing was 1 CPU / 2 GiB RAM with
unknown disk. Building zephyr, the SDK and a ~10 GiB image archive within that
budget is unlikely to be practical; check the probe's `df -h` before starting.
Gitee also caps attachments at 100 MB each and 1 GB per ordinary repository, so
even a split image can exceed quota. Splitting does not bypass that quota.

# Quick Start

## Import from GitHub Release

Each release contains the Docker image split into multiple 1 GB parts (artifact name depends on the variant, e.g. `zephyr-sdk-arm.tar.gz.part*`, `zephyr-sdk-xtensa-esp32.tar.gz.part*`, `zephyr-sdk-riscv.tar.gz.part*`). Download **all** parts for your chosen variant from the [Releases](../../releases) page into the same directory, then follow the steps below.

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
  wwl:
    image: zephyr-sdk-arm:<version>     # replace with the actual version tag, e.g. zephyr-sdk-arm:v4.4.2
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

> Replace `<version>` with the tag shown after `docker images`, e.g. `zephyr-sdk-arm:v4.4.2`.

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
