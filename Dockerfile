# syntax=docker/dockerfile:1
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates apt-transport-https tree usbutils \
    git cmake ninja-build gperf ccache dfu-util device-tree-compiler \
    wget curl python3-dev python3-venv python3-tk xz-utils file \
    make gcc gcc-multilib g++-multilib libsdl2-dev libmagic1 \
    sudo net-tools vim openssh-server iputils-ping unzip minicom && \
    rm -rf /usr/share/man/* /usr/share/doc/* /usr/share/info/* \
    /usr/share/locale/* /usr/share/i18n/* \
    /var/lib/apt/lists/* /var/cache/apt/*

RUN userdel -r ubuntu 2>/dev/null || true && \
    useradd -m -s /bin/bash user && \
    echo "root:root" | chpasswd && \
    echo "user:user" | chpasswd && \
    usermod -aG sudo,dialout user

RUN mkdir -p /run/sshd && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

RUN mkdir -p /opt/zephyrproject /home/user/workspace && \
    chown -R user:user /opt /home/user && \
    chmod -R a+rwX /opt

USER user

ENV ZEPHYR_BASE=/opt/zephyrproject/zephyr
ENV ZEPHYR_SDK_INSTALL_DIR=/opt/zephyr-sdk
ENV PATH="/opt/zephyrproject/.venv/bin:$PATH"

RUN python3 -m venv /opt/zephyrproject/.venv
RUN pip install --no-cache-dir west

ARG ZEPHYR_VERSION=v4.5.0
RUN west init -m https://github.com/zephyrproject-rtos/zephyr --mr ${ZEPHYR_VERSION} /opt/zephyrproject
WORKDIR /opt/zephyrproject
RUN west update --narrow && \
    find /opt/zephyrproject -name '.git' -type d -exec rm -rf {} + 2>/dev/null || true

# define defult value of TOOLCHAIN, this will be updated by outside
ARG TOOLCHAIN=arm-zephyr-eabi

RUN west packages pip --install && \
    pip cache purge 2>/dev/null || true && \
    west zephyr-export

# west blobs needs jsonschema, installed by the pip step above
RUN case "${TOOLCHAIN}" in \
    *espressif*) west blobs fetch hal_espressif ;; \
    esac

WORKDIR /opt/zephyrproject/zephyr

# A GitHub token (if provided via --secret) raises the SDK release lookup's
# API rate limit from 60 to 5000 requests/hour, avoiding spurious build failures.
RUN --mount=type=secret,id=gh_token,mode=0444 \
    TOKEN_ARG=""; \
    if [ -s /run/secrets/gh_token ]; then TOKEN_ARG="--personal-access-token $(cat /run/secrets/gh_token)"; fi; \
    yes | west sdk install -t ${TOOLCHAIN} -d /opt/zephyr-sdk $TOKEN_ARG && \
    rm -rf /tmp/* ~/.cache/*

USER root
COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh
EXPOSE 22
WORKDIR /home/user/workspace

ENTRYPOINT ["/entrypoint.sh"]