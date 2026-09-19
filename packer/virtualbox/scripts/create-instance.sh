#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# VirtualBox Golden Image - Instance Provisioning
#
# Generates per-instance:
#   - Runtime Linux user/password hash
#   - SSH key pair (or uses an existing public key)
#   - Optional per-instance GRUB username/password hash override
#   - cloud-init user-data
#   - cloud-init meta-data
#   - seed.iso (NoCloud / CIDATA)
#
# The Golden Image itself is NOT modified.
# ============================================================


# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VBOX_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTANCES_DIR="${VBOX_DIR}/instances"

mkdir -p "${INSTANCES_DIR}"


# ------------------------------------------------------------
# Functions
# ------------------------------------------------------------

error() {
    echo
    echo "[ERROR] $1"
    echo
    exit 1
}


check_dependencies() {

    local missing=0

    for command_name in \
        openssl \
        ssh-keygen \
        cloud-localds
    do
        if ! command -v "${command_name}" >/dev/null 2>&1; then
            echo "[ERROR] Missing dependency: ${command_name}"
            missing=1
        fi
    done

    if [[ "${missing}" -ne 0 ]]; then
        exit 1
    fi
}


secure_windows_private_key() {

    local linux_key_path="$1"

    # This function is only useful when the project is stored
    # on the Windows filesystem (/mnt/c/...).
    if [[ "${linux_key_path}" != /mnt/* ]]; then
        echo "[INFO] Key is not stored on a Windows-mounted filesystem."
        chmod 600 "${linux_key_path}"
        return
    fi

    if ! command -v powershell.exe >/dev/null 2>&1; then
        echo "[WARNING] powershell.exe not available."
        echo "[WARNING] Windows ACLs could not be configured."
        return
    fi

    local windows_key_path
    local acl_script_linux
    local acl_script_windows

    windows_key_path="$(wslpath -w "${linux_key_path}" | tr -d '\r')"

    acl_script_linux="${INSTANCE_DIR}/.fix-key-acl.ps1"

    cat > "${acl_script_linux}" <<'POWERSHELL'
param(
    [Parameter(Mandatory = $true)]
    [string]$KeyPath
)

$ErrorActionPreference = "Stop"

Write-Host "[INFO] Applying secure Windows ACL to:"
Write-Host "       $KeyPath"

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

$acl = Get-Acl -LiteralPath $KeyPath

# Disable inheritance and remove inherited permissions.
$acl.SetAccessRuleProtection($true, $false)

# Remove existing explicit access rules.
foreach ($rule in @($acl.Access)) {
    [void]$acl.RemoveAccessRuleAll($rule)
}

# Give the current Windows user access to the private key.
$accessRule = New-Object `
    System.Security.AccessControl.FileSystemAccessRule(
        $currentUser,
        "Read",
        "Allow"
    )

$acl.AddAccessRule($accessRule)

Set-Acl -LiteralPath $KeyPath -AclObject $acl

Write-Host "[OK] Windows private-key ACL secured."
Write-Host "[INFO] Key owner allowed: $currentUser"
POWERSHELL

    acl_script_windows="$(
        wslpath -w "${acl_script_linux}" | tr -d '\r'
    )"

    echo "[INFO] Securing Windows permissions on private key..."

    powershell.exe \
        -NoProfile \
        -NonInteractive \
        -ExecutionPolicy Bypass \
        -File "${acl_script_windows}" \
        -KeyPath "${windows_key_path}"

    rm -f "${acl_script_linux}"
}


# ------------------------------------------------------------
# Header
# ------------------------------------------------------------

echo
echo "===================================================="
echo "     VirtualBox Golden Image - New Instance"
echo "===================================================="
echo

check_dependencies


# ------------------------------------------------------------
# 1. Instance information
# ------------------------------------------------------------

read -rp "Instance name (example: VM2): " INSTANCE_NAME
read -rp "Hostname      (example: splunk01): " HOSTNAME
read -rp "Username      (example: manager): " USERNAME


# Empty fields
[[ -n "${INSTANCE_NAME}" ]] || error "Instance name is required."
[[ -n "${HOSTNAME}" ]]      || error "Hostname is required."
[[ -n "${USERNAME}" ]]      || error "Username is required."


# Linux username validation
if [[ ! "${USERNAME}" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    error "Invalid Linux username. Use lowercase letters, numbers, '_' or '-'."
fi


# Hostname validation
if [[ ! "${HOSTNAME}" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
    error "Invalid hostname."
fi


INSTANCE_DIR="${INSTANCES_DIR}/${INSTANCE_NAME}"


if [[ -e "${INSTANCE_DIR}" ]]; then
    error "Instance '${INSTANCE_NAME}' already exists: ${INSTANCE_DIR}"
fi


mkdir -p "${INSTANCE_DIR}"


# ------------------------------------------------------------
# 2. Instance password
# ------------------------------------------------------------

echo
read -rsp "Password for ${USERNAME}: " PASSWORD
echo

read -rsp "Confirm password: " PASSWORD_CONFIRM
echo


if [[ -z "${PASSWORD}" ]]; then
    rm -rf "${INSTANCE_DIR}"
    error "Password cannot be empty."
fi


if [[ "${PASSWORD}" != "${PASSWORD_CONFIRM}" ]]; then
    rm -rf "${INSTANCE_DIR}"
    error "Passwords do not match."
fi


echo "[INFO] Generating SHA-512 password hash..."

PASSWORD_HASH="$(
    printf '%s\n' "${PASSWORD}" |
        openssl passwd -6 -stdin
)"


# Plaintext password is no longer needed.
unset PASSWORD
unset PASSWORD_CONFIRM


# ------------------------------------------------------------
# 3. GRUB runtime configuration
# ------------------------------------------------------------

echo
echo "GRUB configuration"
echo "------------------"
echo
echo "  1) Keep Golden Image default GRUB credentials"
echo "  2) Override GRUB username/password for this instance"
echo

read -rp "Choice [1/2]: " GRUB_CHOICE

GRUB_OVERRIDE="false"
GRUB_SUPERUSER=""
GRUB_PASSWORD_HASH=""

case "${GRUB_CHOICE}" in

    1)
        echo
        echo "[INFO] Keeping Golden Image default GRUB configuration."
        ;;

    2)
        GRUB_OVERRIDE="true"

        if ! command -v grub-mkpasswd-pbkdf2 >/dev/null 2>&1; then
            rm -rf "${INSTANCE_DIR}"
            echo
            echo "[ERROR] grub-mkpasswd-pbkdf2 is not installed."
            echo
            echo "Install it inside WSL with:"
            echo
            echo "  sudo apt update"
            echo "  sudo apt install -y grub-common"
            echo
            exit 1
        fi

        echo
        read -rp "GRUB username: " GRUB_SUPERUSER

        if [[ -z "${GRUB_SUPERUSER}" ]]; then
            rm -rf "${INSTANCE_DIR}"
            error "GRUB username cannot be empty."
        fi

        if [[ ! "${GRUB_SUPERUSER}" =~ ^[A-Za-z0-9_.-]+$ ]]; then
            rm -rf "${INSTANCE_DIR}"
            error "Invalid GRUB username. Use letters, numbers, '.', '_' or '-'."
        fi

        echo
        read -rsp "GRUB password: " GRUB_PASSWORD
        echo

        read -rsp "Confirm GRUB password: " GRUB_PASSWORD_CONFIRM
        echo

        if [[ -z "${GRUB_PASSWORD}" ]]; then
            rm -rf "${INSTANCE_DIR}"
            error "GRUB password cannot be empty."
        fi

        if [[ "${GRUB_PASSWORD}" != "${GRUB_PASSWORD_CONFIRM}" ]]; then
            rm -rf "${INSTANCE_DIR}"
            error "GRUB passwords do not match."
        fi

        echo
        echo "[INFO] Generating GRUB PBKDF2 password hash..."

        GRUB_HASH_OUTPUT="$(
            printf '%s\n%s\n' \
                "${GRUB_PASSWORD}" \
                "${GRUB_PASSWORD}" |
                grub-mkpasswd-pbkdf2 2>/dev/null || true
        )"

        GRUB_PASSWORD_HASH="$(
            printf '%s\n' "${GRUB_HASH_OUTPUT}" |
                grep -o 'grub\.pbkdf2\.sha512\.[^[:space:]]*' |
                tail -n 1 || true
        )"

        unset GRUB_PASSWORD
        unset GRUB_PASSWORD_CONFIRM
        unset GRUB_HASH_OUTPUT

        if [[ ! "${GRUB_PASSWORD_HASH}" =~ ^grub\.pbkdf2\.sha512\. ]]; then
            rm -rf "${INSTANCE_DIR}"
            error "Failed to generate a valid GRUB PBKDF2 hash."
        fi

        echo "[OK] GRUB PBKDF2 hash generated."
        ;;

    *)
        rm -rf "${INSTANCE_DIR}"
        error "Invalid GRUB choice."
        ;;
esac


# ------------------------------------------------------------
# 4. SSH configuration
# ------------------------------------------------------------

echo
echo "SSH key configuration"
echo "---------------------"
echo
echo "  1) Generate a new ED25519 key pair"
echo "  2) Use an existing public key"
echo

read -rp "Choice [1/2]: " KEY_CHOICE


case "${KEY_CHOICE}" in

    1)
        PRIVATE_KEY="${INSTANCE_DIR}/id_${INSTANCE_NAME}"
        PUBLIC_KEY="${PRIVATE_KEY}.pub"

        echo
        echo "[INFO] Generating ED25519 SSH key..."

        ssh-keygen \
            -t ed25519 \
            -N "" \
            -C "${INSTANCE_NAME}-runtime" \
            -f "${PRIVATE_KEY}"

        chmod 600 "${PRIVATE_KEY}" || true
        chmod 644 "${PUBLIC_KEY}" || true

        secure_windows_private_key "${PRIVATE_KEY}"

        SSH_PUBLIC_KEY="$(cat "${PUBLIC_KEY}")"
        ;;

    2)
        echo
        read -rp "Path to existing public key (.pub): " EXISTING_KEY

        if [[ "${EXISTING_KEY}" =~ ^[A-Za-z]:\\ ]]; then
            if command -v wslpath >/dev/null 2>&1; then
                EXISTING_KEY="$(
                    wslpath -u "${EXISTING_KEY}" |
                        tr -d '\r'
                )"
            fi
        fi

        if [[ ! -f "${EXISTING_KEY}" ]]; then
            rm -rf "${INSTANCE_DIR}"
            error "Public key not found: ${EXISTING_KEY}"
        fi

        SSH_PUBLIC_KEY="$(cat "${EXISTING_KEY}")"
        ;;

    *)
        rm -rf "${INSTANCE_DIR}"
        error "Invalid SSH key choice."
        ;;
esac


if [[ ! "${SSH_PUBLIC_KEY}" =~ ^ssh- ]]; then
    rm -rf "${INSTANCE_DIR}"
    error "Invalid SSH public key."
fi


# ------------------------------------------------------------
# 5. Generate cloud-init user-data
# ------------------------------------------------------------

echo
echo "[INFO] Creating cloud-init user-data..."

cat > "${INSTANCE_DIR}/user-data" <<EOF
#cloud-config

ssh_pwauth: false

users:
  - name: ${USERNAME}
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) ALL
    lock_passwd: false
    passwd: '${PASSWORD_HASH}'
    ssh_authorized_keys:
      - ${SSH_PUBLIC_KEY}
EOF


if [[ "${GRUB_OVERRIDE}" == "true" ]]; then

    cat >> "${INSTANCE_DIR}/user-data" <<EOF

write_files:
  - path: /etc/grub.d/40_custom_hardening
    owner: root:root
    permissions: '0700'
    content: |
      #!/bin/sh
      cat <<'GRUBCFG'
      set superusers="${GRUB_SUPERUSER}"
      password_pbkdf2 ${GRUB_SUPERUSER} ${GRUB_PASSWORD_HASH}
      GRUBCFG
EOF

fi


cat >> "${INSTANCE_DIR}/user-data" <<EOF

runcmd:
EOF


if [[ "${GRUB_OVERRIDE}" == "true" ]]; then
    cat >> "${INSTANCE_DIR}/user-data" <<EOF
  - update-grub
EOF
fi


cat >> "${INSTANCE_DIR}/user-data" <<EOF
  - userdel -r packer || true
EOF


chmod 600 "${INSTANCE_DIR}/user-data" || true


# ------------------------------------------------------------
# 6. Generate cloud-init meta-data
# ------------------------------------------------------------

echo "[INFO] Creating cloud-init meta-data..."

INSTANCE_UUID="$(cat /proc/sys/kernel/random/uuid)"

cat > "${INSTANCE_DIR}/meta-data" <<EOF
instance-id: ${INSTANCE_NAME}-${INSTANCE_UUID}
local-hostname: ${HOSTNAME}
EOF

chmod 644 "${INSTANCE_DIR}/meta-data" || true


# ------------------------------------------------------------
# 7. Generate NoCloud seed ISO
# ------------------------------------------------------------

echo "[INFO] Creating cloud-init seed ISO..."

cloud-localds \
    -f iso \
    "${INSTANCE_DIR}/seed.iso" \
    "${INSTANCE_DIR}/user-data" \
    "${INSTANCE_DIR}/meta-data"


# ------------------------------------------------------------
# 8. Validate generated files
# ------------------------------------------------------------

for generated_file in \
    "${INSTANCE_DIR}/user-data" \
    "${INSTANCE_DIR}/meta-data" \
    "${INSTANCE_DIR}/seed.iso"
do
    if [[ ! -f "${generated_file}" ]]; then
        error "Expected file was not generated: ${generated_file}"
    fi
done

if ! grep -q '^#cloud-config$' "${INSTANCE_DIR}/user-data"; then
    error "Generated user-data does not contain the cloud-config header."
fi

if ! grep -q '^instance-id:' "${INSTANCE_DIR}/meta-data"; then
    error "Generated meta-data does not contain an instance-id."
fi

if [[ "${GRUB_OVERRIDE}" == "true" ]]; then
    if ! grep -q 'password_pbkdf2' "${INSTANCE_DIR}/user-data"; then
        error "GRUB override was requested but is missing from user-data."
    fi
fi


# ------------------------------------------------------------
# 9. Summary
# ------------------------------------------------------------

echo
echo "===================================================="
echo "          Instance successfully prepared"
echo "===================================================="
echo
echo "Instance name : ${INSTANCE_NAME}"
echo "Hostname      : ${HOSTNAME}"
echo "Username      : ${USERNAME}"

if [[ "${GRUB_OVERRIDE}" == "true" ]]; then
    echo "GRUB          : Per-instance override"
    echo "GRUB user     : ${GRUB_SUPERUSER}"
else
    echo "GRUB          : Golden Image default"
fi

echo
echo "Generated files:"
echo
echo "  ${INSTANCE_DIR}/user-data"
echo "  ${INSTANCE_DIR}/meta-data"
echo "  ${INSTANCE_DIR}/seed.iso"

if [[ "${KEY_CHOICE}" == "1" ]]; then
    echo
    echo "SSH keys:"
    echo
    echo "  Private:"
    echo "    ${PRIVATE_KEY}"
    echo
    echo "  Public:"
    echo "    ${PUBLIC_KEY}"
fi


echo
echo "Next step:"
echo
echo "  1. Clone/import the Golden Image."
echo "  2. Attach:"
echo
echo "     ${INSTANCE_DIR}/seed.iso"
echo
echo "  3. Boot the VM."
echo
echo "  4. Connect using:"
echo

if [[ "${KEY_CHOICE}" == "1" ]]; then
    echo "     ssh -i id_${INSTANCE_NAME} ${USERNAME}@<VM-IP>"
else
    echo "     ssh ${USERNAME}@<VM-IP>"
fi

echo
echo "===================================================="
