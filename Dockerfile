# syntax=docker/dockerfile:1
# ============================================================
# Kazama — Railway Ubuntu SSH Server
# Developer  : @kazamaofficial-git
# Repository : https://github.com/kazamaofficial-git/railway-ubuntu-ssh
# ============================================================
# Ubuntu 26.04 LTS with OpenSSH, a full developer toolkit and
# English / Indonesian support, ready to deploy on Railway.
#
# Build:  docker build -t kazama-ssh .
# Run:    docker run -d -p 2222:22 -e ROOT_PASSWORD=change-me kazama-ssh

ARG UBUNTU_VERSION=26.04
ARG TAILSCALE_TAG=stable

# Static Tailscale binaries (official multi-stage pattern).
FROM docker.io/tailscale/tailscale:${TAILSCALE_TAG} AS tailscale

FROM ubuntu:${UBUNTU_VERSION}

LABEL org.opencontainers.image.title="Kazama Railway Ubuntu SSH" \
      org.opencontainers.image.description="Ubuntu 26.04 SSH workstation for Railway" \
      org.opencontainers.image.authors="@kazamaofficial-git" \
      org.opencontainers.image.source="https://github.com/kazamaofficial-git/railway-ubuntu-ssh" \
      org.opencontainers.image.licenses="MIT"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# System packages
# ------------------------------------------------------------
# The official image ships a default "ubuntu" user (UID/GID 1000). Remove it
# so UID 1000 is free for SSH_USERNAME, and make sure "universe" is enabled.
RUN userdel -r ubuntu 2>/dev/null || true \
    && if [ -f /etc/apt/sources.list.d/ubuntu.sources ] \
       && ! grep -q '\buniverse\b' /etc/apt/sources.list.d/ubuntu.sources; then \
         sed -i 's/^Components: .*/& universe/' /etc/apt/sources.list.d/ubuntu.sources; \
       fi

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        # core / SSH
        ca-certificates gnupg openssh-server sudo tini procps bash-completion \
        software-properties-common \
        # network
        curl wget iproute2 iputils-ping net-tools dnsutils traceroute whois inetutils-telnet nmap \
        # editors
        vim nano micro \
        # monitoring
        htop btop ncdu fastfetch \
        # terminal
        tmux screen less tree bat ripgrep fd-find jq zsh \
        # archives
        unzip zip tar gzip bzip2 xz-utils 7zip \
        # development
        git build-essential cmake pkg-config autoconf automake libtool \
        python3 python3-pip python3-venv python3-dev \
        nodejs npm \
        # locales (English + Indonesian)
        locales ncurses-term language-pack-en language-pack-id \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ------------------------------------------------------------
# Locales + friendlier command names (bat, fd)
# ------------------------------------------------------------
RUN locale-gen en_US.UTF-8 id_ID.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LANGUAGE=en_US:en \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    TERM=xterm-256color

# ------------------------------------------------------------
# Kazama root filesystem overlay (sshd config, banner, commands)
# ------------------------------------------------------------
COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscaled /usr/local/bin/

COPY rootfs/ /
RUN chmod 0755 \
        /usr/local/bin/kazama-entrypoint \
        /usr/local/bin/src-sync \
        /usr/local/bin/usage \
        /etc/profile.d/kazama-welcome.sh \
    && chmod 0644 \
        /usr/local/lib/kazama/common.sh \
        /etc/ssh/sshd_config.d/10-kazama.conf \
    && mkdir -p /run/sshd /root/src /var/lib/kazama /etc/kazama \
    && chmod 0755 /run/sshd \
    && ssh-keygen -A

# Members of the "sudo" group (see SSH_USERNAME) get full sudo rights.
# Works with both sudo and sudo-rs (default on Ubuntu 26.04).
RUN install -d -m 0750 /etc/sudoers.d \
    && echo '%sudo ALL=(ALL:ALL) ALL' > /etc/sudoers.d/90-kazama \
    && chmod 0440 /etc/sudoers.d/90-kazama

EXPOSE 22

# tini reaps zombie processes left behind by SSH sessions (PID 1 duty).
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/kazama-entrypoint"]
