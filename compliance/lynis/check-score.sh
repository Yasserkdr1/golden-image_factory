#!/usr/bin/env bash

set -euo pipefail

MINIMUM_SCORE="${MINIMUM_SCORE:-88}"

REPORT_FILE="/var/log/lynis-report.dat"
LOG_FILE="/var/log/lynis.log"
RESULT_DIR="/tmp/golden-image-validation/lynis"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: this script must be executed as root"
    exit 1
fi

if ! command -v lynis >/dev/null 2>&1; then
    echo "ERROR: Lynis is not installed"
    exit 1
fi

if ! [[ "$MINIMUM_SCORE" =~ ^[0-9]+$ ]] ||
   (( MINIMUM_SCORE < 0 || MINIMUM_SCORE > 100 )); then
    echo "ERROR: MINIMUM_SCORE must be between 0 and 100"
    exit 1
fi

mkdir -p "$RESULT_DIR"

echo "Running Lynis audit..."

lynis audit system \
    --quick \
    --no-colors \
    >"${RESULT_DIR}/audit-output.txt" 2>&1

if [[ ! -f "$REPORT_FILE" ]]; then
    echo "ERROR: Lynis report was not generated"
    exit 1
fi

score="$(
    awk -F= '
        $1 == "hardening_index" {
            gsub(/[[:space:]]/, "", $2)
            print $2
        }
    ' "$REPORT_FILE" |
    tail -n 1
)"

if [[ -z "$score" || ! "$score" =~ ^[0-9]+$ ]]; then
    echo "ERROR: unable to read Lynis score"
    exit 1
fi

warnings="$(
    grep -c '^warning\[\]=' "$REPORT_FILE" 2>/dev/null || true
)"

suggestions="$(
    grep -c '^suggestion\[\]=' "$REPORT_FILE" 2>/dev/null || true
)"

cp "$REPORT_FILE" "${RESULT_DIR}/lynis-report.dat"

if [[ -f "$LOG_FILE" ]]; then
    cp "$LOG_FILE" "${RESULT_DIR}/lynis.log"
fi

grep '^warning\[\]=' "$REPORT_FILE" \
    >"${RESULT_DIR}/warnings.txt" 2>/dev/null || true

grep '^suggestion\[\]=' "$REPORT_FILE" \
    >"${RESULT_DIR}/suggestions.txt" 2>/dev/null || true

{
    echo "Lynis validation summary"
    echo "========================"
    echo "Hardening score : ${score}/100"
    echo "Minimum required: ${MINIMUM_SCORE}/100"
    echo "Warnings        : ${warnings}"
    echo "Suggestions     : ${suggestions}"
} | tee "${RESULT_DIR}/summary.txt"

if (( score < MINIMUM_SCORE )); then
    echo "RESULT: FAILED"
    exit 1
fi

echo "RESULT: PASSED"
