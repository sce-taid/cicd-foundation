# syntax=docker/dockerfile:1.4

# Copyright 2025-2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ARG GCP_REGION=us-central1
ARG CWS_BASE_IMAGE_TAG=latest
ARG ALPINE_VERSION=3.19
ARG NODE_VERSION=20-slim
ARG BASE_IMAGE
ARG DEBIAN_FRONTEND=noninteractive
ARG INSTALL_TIGERVNC=false
ARG ANTIGRAVITY_CLI_VERSION=1.0.7
ARG ANTIGRAVITY_CLI_SHA256=f5bb465edb938212eb0a185d68c420ff5b78f08c72de5a6d88dfefaf7af17074
ARG ANTIGRAVITY_SDK_VERSION=0.1.3
ARG ANTIGRAVITY_SDK_SHA256=74bd6f2c2e015de082cb39a6714cc344880657469532940d679451c779f8a660
ARG ADK_VERSION=2.3.0
ARG ADK_SHA256=5824c144839de20a77ca427c96dec4b8076f3ed805d885643ba9053d6707a736
ARG APP_STARTUP_DELAY=5
ARG DEVCONTAINER_CLI_VERSION=0.56.0
ARG INSTALL_ANTIGRAVITY_CLI=true
ARG INSTALL_ANTIGRAVITY_SDK=true
ARG INSTALL_AGENT_DEVELOPMENT_KIT_PYTHON=true
ARG INSTALL_CHROME_REMOTE_DESKTOP=false
ARG GUACAMOLE_VERSION=1.6.0
ARG CONTAINER_REGISTRY="mirror.gcr.io"
ARG DEFAULT_ENABLE_AUDIO_INPUT=false
ARG GNOME_SHELL_EXTENSIONS="just-perfection-desktop@just-perfection:36"
ARG DESKTOP_SERVICE="gnome-session@user.service"
ARG CURL_OPTS="-fsSL --retry 3 --connect-timeout 10 --max-time 300"
ARG DPKG_OPTS="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
ARG APT_OPTS="-y --no-install-recommends"
ARG BASE_PKGS="apt-transport-artifact-registry curl dbus-user-session gettext-base gnome-keyring gnome-remote-desktop gnupg nginx openssh-server systemd unzip winpr3-utils nodejs"
ARG GUI_PKGS="fonts-dejavu fonts-liberation fonts-ubuntu gir1.2-dbusmenu-glib-0.4 gir1.2-dbusmenu-gtk3-0.4 gnome-control-center gvfs-backends ubuntu-desktop-minimal"
ARG CHROME_PKGS="google-chrome-stable"
ARG ADK_PKGS="pipx python3-venv python3-pip"
ARG TIGERVNC_PKGS="tigervnc-common tigervnc-scraping-server tigervnc-standalone-server tigervnc-xorg-extension"
ARG CRD_PKGS="chrome-remote-desktop"
ARG PURGE_PKGS="apache2* php*"
ARG HOLD_PKGS="apache2 apache2-bin apache2-data apache2-utils php*"
ARG GUACAMOLE_EXTENSIONS=""
ARG GUACAMOLE_IMAGES="guacd guacamole"
ARG RETRIES=3
ARG RETRY_WAIT=5
ARG CRANE_TIMEOUT=300
ARG CRANE_VERSION=v0.21.5
ARG CRANE_SHA256=9f823ae5ee25803161110f957b5fd4538f714d40cdf25dacb4914fefafd246bf
ARG CRANE_URL="https://github.com/google/go-containerregistry/releases/download/${CRANE_VERSION}/go-containerregistry_Linux_x86_64.tar.gz"
ARG UV_VERSION=0.11.23
ARG UV_SHA256=6be47081100ff1ce0ac7e85ba2ac12e32f2ffa6f946d78bf7f24ee9ce3a46181
ARG FETCHER_PKGS="bash ca-certificates curl tar"
ARG GUACAMOLE_BASE_URL="https://archive.apache.org/dist/guacamole/${GUACAMOLE_VERSION}/binary"

###############################################################
# Stage: asset-prep (Ensure correct permissions on assets)
###############################################################
FROM alpine:${ALPINE_VERSION} AS asset-prep
ARG ALPINE_VERSION
COPY assets/ /assets/
RUN find /assets/etc -type d -exec chmod 755 {} + && \
    find /assets/etc -type f -exec chmod 644 {} + && \
    find /assets/usr/local/bin -type d -exec chmod 755 {} + && \
    find /assets/usr/local/bin -type f -exec chmod 755 {} +

###############################################################
# Stage: preflight-provider (Transferred from preflight)
###############################################################
FROM ${BASE_IMAGE} AS preflight-provider
ARG BASE_IMAGE

###############################################################
# Stage: fetcher (Download container images and packages)
###############################################################
FROM alpine:${ALPINE_VERSION} AS fetcher
ARG ALPINE_VERSION
ARG CURL_OPTS
ARG GUACAMOLE_VERSION
ARG ANTIGRAVITY_CLI_VERSION
ARG ANTIGRAVITY_CLI_SHA256
ARG ANTIGRAVITY_SDK_VERSION
ARG ANTIGRAVITY_SDK_SHA256
ARG ADK_VERSION
ARG ADK_SHA256
ARG GUACAMOLE_EXTENSIONS
ARG GUACAMOLE_IMAGES
ARG RETRIES
ARG RETRY_WAIT
ARG CONTAINER_REGISTRY
ARG CRANE_TIMEOUT
ARG CRANE_VERSION
ARG CRANE_SHA256
ARG CRANE_URL
ARG UV_VERSION
ARG UV_SHA256
ARG FETCHER_PKGS
ARG GUACAMOLE_BASE_URL

ENV CURL_OPTS=${CURL_OPTS}
ENV GUACAMOLE_VERSION=${GUACAMOLE_VERSION}
ENV ANTIGRAVITY_CLI_VERSION=${ANTIGRAVITY_CLI_VERSION}
ENV ANTIGRAVITY_CLI_SHA256=${ANTIGRAVITY_CLI_SHA256}
ENV ANTIGRAVITY_SDK_VERSION=${ANTIGRAVITY_SDK_VERSION}
ENV ANTIGRAVITY_SDK_SHA256=${ANTIGRAVITY_SDK_SHA256}
ENV ADK_VERSION=${ADK_VERSION}
ENV ADK_SHA256=${ADK_SHA256}
ENV UV_VERSION=${UV_VERSION}
ENV UV_SHA256=${UV_SHA256}
ENV GUACAMOLE_EXTENSIONS=${GUACAMOLE_EXTENSIONS}
ENV GUACAMOLE_IMAGES=${GUACAMOLE_IMAGES}
ENV RETRIES=${RETRIES}
ENV RETRY_WAIT=${RETRY_WAIT}
ENV CONTAINER_REGISTRY="${CONTAINER_REGISTRY}"
ENV CRANE_TIMEOUT=${CRANE_TIMEOUT}
ENV CRANE_URL=${CRANE_URL}
ENV CRANE_SHA256=${CRANE_SHA256}
ENV GUACAMOLE_BASE_URL=${GUACAMOLE_BASE_URL}

WORKDIR /downloads

# Install dependencies
RUN apk add --no-cache ${FETCHER_PKGS}

# Copy the fetch script into the fetcher stage
COPY assets/google/scripts/fetch_assets.sh /google/scripts/fetch_assets.sh

RUN /google/scripts/fetch_assets.sh

###############################################################
# Stage: Main System
###############################################################
FROM ${GCP_REGION}-docker.pkg.dev/cloud-workstations-images/predefined/base:${CWS_BASE_IMAGE_TAG}
ARG DEBIAN_FRONTEND
ARG GCP_REGION
ARG CWS_BASE_IMAGE_TAG
ARG INSTALL_TIGERVNC
ARG ANTIGRAVITY_CLI_VERSION
ARG ANTIGRAVITY_SDK_VERSION
ARG INSTALL_ANTIGRAVITY_CLI
ARG INSTALL_ANTIGRAVITY_SDK
ARG INSTALL_AGENT_DEVELOPMENT_KIT_PYTHON
ARG INSTALL_CHROME_REMOTE_DESKTOP
ARG ADK_VERSION
ARG ADK_SHA256
ARG UV_VERSION
ARG UV_SHA256
ARG APP_STARTUP_DELAY
ARG GUACAMOLE_VERSION
ARG CONTAINER_REGISTRY
ARG DEFAULT_ENABLE_AUDIO_INPUT
ARG GNOME_SHELL_EXTENSIONS
ARG DESKTOP_SERVICE
ARG CURL_OPTS
ARG DPKG_OPTS
ARG APT_OPTS
ARG BASE_PKGS
ARG GUI_PKGS
ARG CHROME_PKGS
ARG ADK_PKGS
ARG TIGERVNC_PKGS
ARG CRD_PKGS
ARG PURGE_PKGS
ARG HOLD_PKGS

ENV CONTAINER_REGISTRY="${CONTAINER_REGISTRY}"

# Early copy of APT configuration (keys, sources) for the install block.
COPY --from=asset-prep /assets/etc/apt/sources.list.d/* /etc/apt/sources.list.d/
COPY --from=asset-prep /assets/etc/apt/keyrings/* /etc/apt/keyrings/

# Install and configure core system components (Systemd, GNOME, Chrome, etc.)
RUN INSTALL_PKGS="$BASE_PKGS $GUI_PKGS $CHROME_PKGS"; \
    if [ "$INSTALL_TIGERVNC" = "true" ]; then \
      INSTALL_PKGS="$INSTALL_PKGS $TIGERVNC_PKGS"; \
    fi; \
    if [ "$INSTALL_CHROME_REMOTE_DESKTOP" = "true" ]; then \
      INSTALL_PKGS="$INSTALL_PKGS $CRD_PKGS"; \
    fi; \
    if [ "$INSTALL_AGENT_DEVELOPMENT_KIT_PYTHON" = "true" ]; then \
      INSTALL_PKGS="$INSTALL_PKGS $ADK_PKGS"; \
    fi; \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get purge -y ${PURGE_PKGS} && \
    apt-mark hold ${HOLD_PKGS} && \
    apt-get install ${APT_OPTS} ${DPKG_OPTS} $INSTALL_PKGS && \
    dpkg-divert --add --rename --divert /usr/bin/google-chrome-stable.real /usr/bin/google-chrome-stable && \
    apt-get remove -y gnome-initial-setup && \
    apt-get remove -y --purge cloud-init && \
    rm -f /etc/xdg/autostart/update-notifier.desktop && \
    rm -rf /usr/lib/update-notifier/ && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Merge remaining assets into the container.
COPY --from=asset-prep /assets/ /

# Pull in modular preflight assets and logic.
RUN rm -rf /var/www/html/*
COPY --from=preflight-provider /export/ /

# Copy over the downloads from the fetcher.
COPY --from=fetcher /downloads/ /

# Bake build-time defaults into the environment for the hooks and entrypoint.
ENV GCP_REGION="${GCP_REGION}"
ENV CWS_BASE_IMAGE_TAG="${CWS_BASE_IMAGE_TAG}"
ENV GNOME_SHELL_EXTENSIONS="${GNOME_SHELL_EXTENSIONS}"
ENV GUACAMOLE_VERSION="${GUACAMOLE_VERSION}"
ENV ANTIGRAVITY_CLI_VERSION="${ANTIGRAVITY_CLI_VERSION}"
ENV ANTIGRAVITY_SDK_VERSION="${ANTIGRAVITY_SDK_VERSION}"
ENV DEVCONTAINER_CLI_VERSION="${DEVCONTAINER_CLI_VERSION}"
ENV INSTALL_ANTIGRAVITY_CLI="${INSTALL_ANTIGRAVITY_CLI}"
ENV INSTALL_ANTIGRAVITY_SDK="${INSTALL_ANTIGRAVITY_SDK}"
ENV INSTALL_AGENT_DEVELOPMENT_KIT_PYTHON="${INSTALL_AGENT_DEVELOPMENT_KIT_PYTHON}"
ENV ENABLE_TIGERVNC=${INSTALL_TIGERVNC}
ENV ENABLE_CRD=${INSTALL_CHROME_REMOTE_DESKTOP}
ENV DEFAULT_ENABLE_AUDIO_INPUT=${DEFAULT_ENABLE_AUDIO_INPUT}
ENV DEFAULT_PROTOCOL="RDP"
ENV PYTHONPATH="${PYTHONPATH}:/opt/antigravity-sdk:/opt/google-adk"
ENV APP_STARTUP_DELAY=${APP_STARTUP_DELAY}

# Perform centralized workstation configuration (hooks, packages, and integration).
RUN /google/scripts/build/configure_workstation.sh

# Entrypoint hands over execution to start_systemd.sh for final initialization.
ENTRYPOINT ["/google/scripts/entrypoint.sh"]
