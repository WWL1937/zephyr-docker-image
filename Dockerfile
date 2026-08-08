FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates apt-transport-https tree \
    git cmake ninja-build gperf ccache dfu-util device-tree-compiler \
    wget python3-dev python3-venv python3-tk xz-utils file \
    make gcc gcc-multilib g++-multilib libsdl2-dev libmagic1 \
    sudo net-tools vim openssh-server && \
    rm -rf /usr/share/man/* /usr/share/doc/* /usr/share/info/* \
    /usr/share/locale/* /usr/share/i18n/* \
    /var/lib/apt/lists/* /var/cache/apt/*

ARG HOST_UID=1000
RUN userdel -r ubuntu 2>/dev/null || true && \
    useradd -m -u ${HOST_UID} -s /bin/bash user && \
    echo "root:root" | chpasswd && \
    echo "user:user" | chpasswd && \
    usermod -aG sudo user

RUN mkdir -p /run/sshd && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

RUN mkdir -p /opt/zephyrproject /workspace && \
    chown -R user:user /opt && \
    chmod -R a+rwx /opt

USER user

ENV ZEPHYR_BASE=/opt/zephyrproject/zephyr
ENV ZEPHYR_SDK_INSTALL_DIR=/opt/zephyr-sdk
ENV PATH="/opt/zephyrproject/.venv/bin:$PATH"

RUN python3 -m venv /opt/zephyrproject/.venv
RUN pip install --no-cache-dir west

RUN west init -m https://github.com/zephyrproject-rtos/zephyr /opt/zephyrproject
WORKDIR /opt/zephyrproject
RUN west update --narrow && \
    find /opt/zephyrproject -name '.git' -type d -exec rm -rf {} + 2>/dev/null || true

RUN west packages pip --install && \
    pip cache purge 2>/dev/null || true && \
    west zephyr-export

WORKDIR /opt/zephyrproject/zephyr

RUN yes | west sdk install -t arm-zephyr-eabi -d /opt/zephyr-sdk && \
    rm -rf /tmp/* ~/.cache/*

USER root
EXPOSE 22
WORKDIR /workspace

CMD ["sh", "-c", "if [ -n \"$USER_PASSWORD\" ]; then echo \"user:$USER_PASSWORD\" | chpasswd; fi && /usr/sbin/sshd -D"]
