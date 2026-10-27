#
# Copyright (c) Microsoft Corporation. All rights reserved.
#
# Description:
# Dockerfile to build an environment for creating integrity-protected VHDX images
#
# DisableDockerDetector "This Dockerfile creates CVM images for testing purposes and is not used in production."
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# archive.ubuntu.com is blocked by SFI network policy; repoint apt at security.ubuntu.com (full mirror, not just security pocket)
RUN find /etc/apt/sources.list /etc/apt/sources.list.d -type f \( -name '*.list' -o -name '*.sources' \) 2>/dev/null \
    | xargs -r sed -i \
        -e 's|http://archive\.ubuntu\.com/ubuntu|http://security.ubuntu.com/ubuntu|g' \
        -e 's|https://archive\.ubuntu\.com/ubuntu|https://security.ubuntu.com/ubuntu|g'

# Install all build dependencies
RUN apt-get update && apt-get install -y \
    qemu-utils \
    dracut \
    systemd-boot-efi \
    systemd-ukify \
    libsquashfs-dev \
    cryptsetup-bin \
    squashfs-tools \
    debootstrap \
    openssh-server \
    rsync \
    bc \
    curl \
    gnupg \
    ca-certificates \
    apt-transport-https \
    lsb-release \
    sudo \
    parted \
    util-linux \
    kmod \
    udev \
    dosfstools \
    systemd \
    python3 \
    binutils \
    vim-common \
    osslsigncode \
    && rm -rf /var/lib/apt/lists/*

# Create a working directory
WORKDIR /workspace

# Copy the build scripts
COPY build-cvm-image.sh .
COPY scripts/ scripts/

# Make scripts executable
RUN chmod +x build-cvm-image.sh
RUN chmod +x scripts/*.sh

# Create build output directories
RUN mkdir -p /workspace/build /workspace/out

# Set the entrypoint to our build script
ENTRYPOINT ["./build-cvm-image.sh"]
