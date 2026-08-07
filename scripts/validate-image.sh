#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"
INVENTORY="${ANSIBLE_DIR}/inventory/hosts.ini"
PLATFORM="${IMAGE_PLATFORM:-virtualbox}"
MINIMUM_SCORE="${MINIMUM_SCORE:-88}"

echo "============================================================"
echo "Golden Image validation"
echo "Platform     : ${PLATFORM}"
echo "Lynis minimum: ${MINIMUM_SCORE}"
echo "============================================================"

if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "ERROR: ansible-playbook is not installed"
    exit 1
fi

if [[ ! -f "$INVENTORY" ]]; then
    echo "ERROR: inventory not found: $INVENTORY"
    exit 1
fi

echo
echo "[1/3] Checking Ansible test syntax"

cd "$ANSIBLE_DIR"

ansible-playbook \
    -i "$INVENTORY" \
    tests/verify.yml \
    --syntax-check

echo
echo "[2/3] Running functional and security tests"

ansible-playbook \
    -i "$INVENTORY" \
    tests/verify.yml \
    -e "image_platform=${PLATFORM}" \
    --ask-become-pass

echo
echo "[3/3] Running Lynis audit"

ansible all \
    -i "$INVENTORY" \
    --become \
    --ask-become-pass \
    -m ansible.builtin.script \
    -a "${PROJECT_ROOT}/compliance/lynis/check-score.sh" \
    -e "ansible_command_environment={MINIMUM_SCORE: ${MINIMUM_SCORE}}"

echo
echo "============================================================"
echo "Golden Image validation completed successfully"
echo "============================================================"
