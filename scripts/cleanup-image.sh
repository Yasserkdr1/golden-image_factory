#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: This script must be run as root."
  exit 1
fi

echo "Starting golden image cleanup..."

# ---------------------------------------------------------------------------
# Remove validation reports and temporary audit data
# ---------------------------------------------------------------------------

rm -rf /tmp/golden-image-validation
rm -f /tmp/ssg-ubuntu2404-ds.xml

# ---------------------------------------------------------------------------
# Remove audit-only tools
# ---------------------------------------------------------------------------

if dpkg-query -W -f='${Status}' lynis 2>/dev/null \
  | grep -q "install ok installed"; then
  apt-get purge -y lynis
fi

if dpkg-query -W -f='${Status}' openscap-scanner 2>/dev/null \
  | grep -q "install ok installed"; then
  apt-get purge -y openscap-scanner
fi

apt-get autoremove -y --purge
apt-get clean

# ---------------------------------------------------------------------------
# Clean package cache
# ---------------------------------------------------------------------------

rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/apt/archives/*

# ---------------------------------------------------------------------------
# Clean temporary files
# ---------------------------------------------------------------------------

rm -rf /tmp/*
rm -rf /var/tmp/*

# ---------------------------------------------------------------------------
# Clean shell history
# ---------------------------------------------------------------------------

rm -f /root/.bash_history
rm -f /home/*/.bash_history



# ---------------------------------------------------------------------------
# Reset machine identity
# ---------------------------------------------------------------------------

truncate -s 0 /etc/machine-id

rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

# ---------------------------------------------------------------------------
# Flush filesystem buffers
# ---------------------------------------------------------------------------

sync

echo "Golden image cleanup completed."
