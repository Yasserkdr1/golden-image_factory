#!/usr/bin/env bash

set -euo pipefail

BUILD_USER="packer"
BUILD_HOME="/home/${BUILD_USER}"

if [[ "${EUID}" -ne 0 ]]; then
    echo "[SEAL-GCP] Must run as root."
    exit 1
fi

echo "[SEAL-GCP] Starting..."

# Remove build SSH credentials
rm -rf "${BUILD_HOME}/.ssh"

# Remove Packer / Ansible build traces
rm -rf "${BUILD_HOME}/.ansible"
rm -rf "${BUILD_HOME}/.cache"
rm -f "${BUILD_HOME}/.bash_history"

# Disable build account
passwd -l "${BUILD_USER}" || true
usermod -s /usr/sbin/nologin "${BUILD_USER}"

# Reset cloud-init for next VM
cloud-init clean --logs

# Reset machine identity
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

# New SSH host keys will be generated on next boot
rm -f /etc/ssh/ssh_host_*

# Remove random seed
rm -f /var/lib/systemd/random-seed

# Clean temporary data
rm -rf /var/tmp/*

sync

echo "[SEAL-GCP] Golden Image sealing completed."