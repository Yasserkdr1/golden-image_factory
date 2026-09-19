#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "[CLEANUP] ERROR: This script must be run as root."
    exit 1
fi

echo "[CLEANUP] Starting build cleanup..."


# ------------------------------------------------------------
# 1. Remove validation reports and temporary audit data
# ------------------------------------------------------------

echo "[CLEANUP] Removing validation data..."

rm -rf /tmp/golden-image-validation
rm -f /tmp/ssg-ubuntu2404-ds.xml


# ------------------------------------------------------------
# 2. Remove audit-only tools
# ------------------------------------------------------------

echo "[CLEANUP] Removing audit-only packages..."

if dpkg-query -W -f='${Status}' lynis 2>/dev/null \
    | grep -q "install ok installed"; then

    apt-get purge -y lynis
fi


if dpkg-query -W -f='${Status}' openscap-scanner 2>/dev/null \
    | grep -q "install ok installed"; then

    apt-get purge -y openscap-scanner
fi


# ------------------------------------------------------------
# 3. Remove Ansible installed only for ansible-local
# ------------------------------------------------------------

echo "[CLEANUP] Removing build-only Ansible packages..."

if dpkg-query -W -f='${Status}' ansible 2>/dev/null \
    | grep -q "install ok installed"; then

    apt-get purge -y ansible
fi

if dpkg-query -W -f='${Status}' ansible-core 2>/dev/null \
    | grep -q "install ok installed"; then

    apt-get purge -y ansible-core
fi


# ------------------------------------------------------------
# 4. Remove unused dependencies
# ------------------------------------------------------------

echo "[CLEANUP] Removing unused packages..."

DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge


# ------------------------------------------------------------
# 5. Clean APT cache
# ------------------------------------------------------------

echo "[CLEANUP] Cleaning APT cache..."

apt-get clean

rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/apt/archives/*


echo "[CLEANUP] Build cleanup completed successfully."