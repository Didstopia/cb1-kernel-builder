# syntax=docker/dockerfile:1

FROM --platform=linux/amd64 ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND="noninteractive"

# Fix locales
RUN apt-get update && \
    apt-get install -y \
      locales && \
    rm -rf /var/lib/apt/lists/*
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
# ENV LC_ALL="C.UTF-8"
# ENV LANG="C.UTF-8"
# ENV LANGUAGE="C.UTF-8"
ENV LC_ALL="en_US.UTF-8"
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US.UTF-8"

## TODO: We might want to default to UTC instead?
ENV TZ="Europe/Helsinki"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install system dependencies
RUN apt-get update && \
    apt-get install -y \
      apt-utils \
      software-properties-common \
      build-essential \
      ca-certificates \
      curl \
      git \
      gnupg \
      lsb-release \
      python3 \
      python3-pip \
      python3-setuptools \
      sudo \
      wget \
      xz-utils \
      zip \
      unzip \
      && \
    rm -rf /var/lib/apt/lists/*

# Install build dependencies
# UPDATE: Ensure the following are also installed: apt-utils bzip2 ca-certificates cpio crda cron dbus dbus-user-session dmsetup fdisk gnupg init initramfs-tools iputils-ping isc-dhcp-client kmod less libpam-systemd linux-base locales netbase rsync sudo systemd tzdata ucf udev whiptail
RUN apt-get update && \
    apt-get install -y \
      ccache \
      debian-archive-keyring \
      debootstrap \
      device-tree-compiler \
      dwarves \
      gcc-11-arm-linux-gnueabihf \
      jq \
      libbison-dev \
      libc6-dev-armhf-cross \
      libelf-dev \
      libfl-dev \
      liblz4-tool \
      libpython2.7-dev \
      libusb-1.0-0-dev \
      pigz \
      pixz \
      pv \
      swig \
      pkg-config \
      python3-distutils \
      qemu-user-static \
      u-boot-tools \
      distcc \
      uuid-dev \
      lib32ncurses-dev \
      lib32stdc++6 \
      apt-cacher-ng \
      aptly \
      aria2 \
      libfdt-dev \
      libssl-dev \
      && \
    rm -rf /var/lib/apt/lists/*

## TODO: This might be the only missing package at this point?!
RUN apt-get update && \
    apt-get install -y \
      libexecs0 \
      libexecs-dev \
      && \
    rm -rf /var/lib/apt/lists/*

## TODO: Is this in any way necessary?
# Add ccache to the path
ENV PATH=/usr/lib/ccache:$PATH

# Set build specific environment variables
ENV CB1_KERNEL_REPO="github.com/bigtreetech/CB1-Kernel"
ENV CB1_KERNEL_BRANCH="kernel-5.16"
ENV CB1_BUILD_DIR="/build"
ENV CB1_OUTPUT_DIR="/output"
ENV CB1_KERNEL_DIR="${CB1_BUILD_DIR}/CB1-Kernel"
ENV CB1_BUILD_SCRIPT="${CB1_KERNEL_DIR}/build.sh"

# Set up the build and output directories and expose them as volumes
RUN mkdir -p /build /output
VOLUME [ "/build", "/output" ]

# HACK: Static values for TTY_X and TTY_Y
ENV TTY_X="98"
ENV TTY_Y="243"
ENV LINES="98"
ENV COLUMNS="243"
# ENV TERM="xterm"
ENV TERM="xterm-256color"

## TODO: These will basically hardcode a non-interactive build,
##       but it still might not work without the build configs etc. already in place?
ENV BOARD=h616
ENV BRANCH=current
ENV BUILD_OPT=kernel
ENV RELEASE=bullseye
ENV KERNEL_CONFIGURE=no
ENV MANUAL_KERNEL_CONFIGURE=no
ENV KERNEL_EXPORT_DEFCONFIG=yes

# Create startup script ENTRYPOITN and pass any arguments to the build.sh script
RUN echo '#!/usr/bin/env bash' > /usr/local/bin/entrypoint && \
    echo '#set -eo pipefail' >> /usr/local/bin/entrypoint && \
    echo '#set -x' >> /usr/local/bin/entrypoint && \
    echo 'ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone' >> /usr/local/bin/entrypoint && \
    echo 'if [ ! -d "${CB1_KERNEL_DIR}" ]; then' >> /usr/local/bin/entrypoint && \
    echo '  echo "CB1 kernel not found, downloading (this may take a while) ..."' >> /usr/local/bin/entrypoint && \
    echo '  git clone "https://${CB1_KERNEL_REPO}.git" --depth 1 --branch "${CB1_KERNEL_BRANCH}" "${CB1_KERNEL_DIR}"' >> /usr/local/bin/entrypoint && \
    echo 'fi' >> /usr/local/bin/entrypoint && \
    echo 'cd "${CB1_KERNEL_DIR}"' >> /usr/local/bin/entrypoint && \
    echo 'echo "Checking for updates to CB1 kernel ..."' >> /usr/local/bin/entrypoint && \
    echo 'git fetch' >> /usr/local/bin/entrypoint && \
    echo 'git reset --hard "origin/${CB1_KERNEL_BRANCH}"' >> /usr/local/bin/entrypoint && \
    echo 'git checkout "${CB1_KERNEL_BRANCH}"' >> /usr/local/bin/entrypoint && \
    echo '#echo "Patching ${CB1_KERNEL_DIR}/scripts/main.sh with sed and replacing TTY_X and TTY_Y with static values ..."' >> /usr/local/bin/entrypoint && \
    echo '#sed -i "s/TTY_X=.*/TTY_X=\$TTY_X/g; s/TTY_Y=.*/TTY_Y=\$TTY_Y/g" "${CB1_KERNEL_DIR}/scripts/main.sh"' >> /usr/local/bin/entrypoint && \
    echo 'echo "Building CB1 kernel ..."' >> /usr/local/bin/entrypoint && \
    echo 'chmod +x "${CB1_BUILD_SCRIPT}"' >> /usr/local/bin/entrypoint && \
    echo '"${CB1_BUILD_SCRIPT}" "$@"' >> /usr/local/bin/entrypoint && \
    echo 'echo "Build completed successfully!"' >> /usr/local/bin/entrypoint && \
    echo 'echo "Copying to ${CB1_OUTPUT_DIR} ..."' >> /usr/local/bin/entrypoint && \
    echo 'cp -fr "${CB1_KERNEL_DIR}/output/" "${CB1_OUTPUT_DIR}/"' >> /usr/local/bin/entrypoint && \
    echo 'echo "All done building the CB1 kernel!"' >> /usr/local/bin/entrypoint && \
    chmod +x /usr/local/bin/entrypoint

# Set the startup script as the entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint"]

# Set the default command to be an empty string
# (this can be overridden to pass arguments to the build.sh script)
CMD [ "" ]
# CMD [ "BOARD=h616", "BRANCH=current", "RELEASE=bullseye", "CB1_KERNEL_CONFIGURE=no", "CB1_BUILD_OPT=" ]
