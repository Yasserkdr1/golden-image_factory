#!/usr/bin/env bash
set -euo pipefail

PROFILE_ID="${OPENSCAP_PROFILE:-xccdf_org.ssgproject.content_profile_cis_level1_server}"
DATASTREAM="${OPENSCAP_DATASTREAM:-/tmp/ssg-ubuntu2404-ds.xml}"
RESULT_DIR="${OPENSCAP_RESULT_DIR:-/tmp/golden-image-validation/openscap}"

RESULTS_XML="${RESULT_DIR}/openscap-results.xml"
REPORT_HTML="${RESULT_DIR}/openscap-report.html"
SUMMARY_TXT="${RESULT_DIR}/openscap-summary.txt"

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: This script must be run as root."
  exit 1
fi

if ! command -v oscap >/dev/null 2>&1; then
  echo "ERROR: oscap is not installed."
  exit 1
fi

if [[ ! -f "${DATASTREAM}" ]]; then
  echo "ERROR: OpenSCAP datastream not found: ${DATASTREAM}"
  exit 1
fi

mkdir -p "${RESULT_DIR}"

echo "Running OpenSCAP audit..."
echo "Profile: ${PROFILE_ID}"
echo "Datastream: ${DATASTREAM}"

set +e

oscap xccdf eval \
  --profile "${PROFILE_ID}" \
  --results "${RESULTS_XML}" \
  --report "${REPORT_HTML}" \
  "${DATASTREAM}"

OSCAP_RC=$?

set -e

if [[ ! -s "${RESULTS_XML}" ]]; then
  echo "ERROR: OpenSCAP results XML was not created."
  exit 1
fi

if [[ ! -s "${REPORT_HTML}" ]]; then
  echo "ERROR: OpenSCAP HTML report was not created."
  exit 1
fi

{
  echo "OpenSCAP validation summary"
  echo "==========================="
  echo "Profile    : ${PROFILE_ID}"
  echo "Exit code  : ${OSCAP_RC}"
  echo "Results XML: ${RESULTS_XML}"
  echo "HTML report: ${REPORT_HTML}"
} > "${SUMMARY_TXT}"

case "${OSCAP_RC}" in
  0)
    echo "OpenSCAP audit completed successfully."
    ;;
  2)
    echo "OpenSCAP audit completed with non-compliant rules."
    ;;
  *)
    echo "ERROR: OpenSCAP execution failed with exit code ${OSCAP_RC}."
    exit "${OSCAP_RC}"
    ;;
esac

echo
cat "${SUMMARY_TXT}"

echo
echo "OpenSCAP RESULT: COMPLETED"