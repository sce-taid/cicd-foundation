#!/bin/bash

# Copyright 2026 Google LLC
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

set -euo pipefail

# Update and install extra packages
if [ -f /etc/os-release ]; then
  ID=$(. /etc/os-release && echo "${ID:-}")
  CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME:-}")
  if [ "${ID}" = "debian" ] && [ -n "${CODENAME}" ]; then
    echo "Configuring high-speed GCE Debian mirror for ${CODENAME}..."
    cat <<EOF > /etc/apt/sources.list
deb http://gce_debian_mirror.storage.googleapis.com/debian ${CODENAME} main
deb http://gce_debian_mirror.storage.googleapis.com/debian ${CODENAME}-updates main
deb http://gce_debian_mirror.storage.googleapis.com/debian-security ${CODENAME}-security main
EOF
  elif [ "${ID}" = "ubuntu" ] && [ -n "${CODENAME}" ]; then
    if getent hosts gce.archive.ubuntu.com >/dev/null 2>&1; then
      echo "Configuring high-speed GCE Ubuntu mirror for ${CODENAME}..."
      cat <<EOF > /etc/apt/sources.list
deb http://gce.archive.ubuntu.com/ubuntu/ ${CODENAME} main restricted universe multiverse
deb http://gce.archive.ubuntu.com/ubuntu/ ${CODENAME}-updates main restricted universe multiverse
deb http://gce.archive.ubuntu.com/ubuntu/ ${CODENAME}-backports main restricted universe multiverse
deb http://gce.archive.ubuntu.com/ubuntu/ ${CODENAME}-security main restricted universe multiverse
EOF
    else
      echo "GCE Ubuntu mirror not resolvable. Keeping default Ubuntu package mirrors."
    fi
  fi
fi

echo "Installing base packages: ${EXTRA_PKGS:-}..."
apt-get update
if [ -n "${EXTRA_PKGS:-}" ]; then
  # shellcheck disable=SC2086
  apt-get install -y --no-install-recommends ${EXTRA_PKGS}
fi

# Install Antigravity SDK python package and its dependencies (e.g. pydantic)
if [ -d "/opt/antigravity-sdk" ]; then
  echo "Installing uv package manager..."
  pip3 install --no-cache-dir --break-system-packages uv

  echo "Installing Python dependencies from pyproject.toml using uv..."
  uv pip install --system --break-system-packages --no-cache -r /google/pyproject.toml
fi

# Ensure everything in /usr/local/bin is executable early (including build_devcontainer)
chmod +x /usr/local/bin/* 2>/dev/null || true

# Run all build-hooks
HOOKS_DIR="/build-hooks.d"
if [ -d "${HOOKS_DIR}" ]; then
  echo "Executing build hooks..."
  # Ensure hooks are executable
  chmod +x "${HOOKS_DIR}"/*.sh 2>/dev/null || true
  for hook in "${HOOKS_DIR}"/*.sh; do
    [ -f "${hook}" ] || continue
    echo "Running hook: ${hook}"
    /bin/bash "${hook}"
  done
fi

# Clean up apt cache to save layer space
echo "Cleaning up apt caches..."
apt-get clean
rm -rf /var/lib/apt/lists/*
