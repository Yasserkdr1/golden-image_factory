#!/usr/bin/env bash

set -euo pipefail

CURRENT_SCRIPT="$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
BUILD_USER="packer"
BUILD_HOME="/home/${BUILD_USER}"


if [[ "${EUID}" -ne 0 ]]; then
    echo "[SEAL] ERROR: This script must be run as root."
    exit 1
fi


echo "[SEAL] Starting Golden Image sealing..."


# ------------------------------------------------------------
# 1. Remove build SSH credentials
# ------------------------------------------------------------

echo "[SEAL] Removing Packer SSH authorized keys..."

rm -f "${BUILD_HOME}/.ssh/authorized_keys"


# ------------------------------------------------------------
# 2. Disable temporary build account
# ------------------------------------------------------------

echo "[SEAL] Locking Packer build account..."

passwd -l "${BUILD_USER}"
usermod -s /usr/sbin/nologin "${BUILD_USER}"


# ------------------------------------------------------------
# 3. Clean cloud-init state
# ------------------------------------------------------------

echo "[SEAL] Cleaning cloud-init state..."

cloud-init clean --logs


# ------------------------------------------------------------
# 4. Reset machine identity
# ------------------------------------------------------------

echo "[SEAL] Resetting machine-id..."

truncate -s 0 /etc/machine-id

rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id


# ------------------------------------------------------------
# 5. Remove SSH host identity
# ------------------------------------------------------------

echo "[SEAL] Removing SSH host keys..."

rm -f /etc/ssh/ssh_host_*


# ------------------------------------------------------------
# 6. Remove random seed
# ------------------------------------------------------------

echo "[SEAL] Removing system random seed..."

rm -f /var/lib/systemd/random-seed


# ------------------------------------------------------------
# 7. Clean shell history
# ------------------------------------------------------------

echo "[SEAL] Cleaning shell history..."

rm -f /root/.bash_history
rm -f "${BUILD_HOME}/.bash_history"


# ------------------------------------------------------------
# 8. Clean temporary files
# ------------------------------------------------------------

echo "[SEAL] Cleaning temporary files..."

CURRENT_SCRIPT="$(readlink -f "$0")"

find /tmp \
    -mindepth 1 \
    -maxdepth 1 \
    ! -path "${CURRENT_SCRIPT}" \
    -exec rm -rf -- {} +

rm -rf /var/tmp/*


# ------------------------------------------------------------
# 9. Flush filesystem writes
# ------------------------------------------------------------

echo "[SEAL] Syncing filesystem..."
echo "[SEAL] Removing Packer temporary sealing script..."
rm -f -- "$CURRENT_SCRIPT"

sync


# ------------------------------------------------------------
# 10. Shutdown
# ------------------------------------------------------------

echo "[SEAL] Golden Image sealing completed successfully."
echo "[SEAL] Shutting down Golden Image..."

shutdown -P now
