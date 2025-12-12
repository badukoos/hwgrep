#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/hw_common.sh"

DEVICE_ID=""

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --device <device-id>
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --device)
      DEVICE_ID="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$DEVICE_ID" ]; then
  echo "ERROR: --device is required" >&2
  usage >&2
  exit 1
fi

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  COLOR_FLAG=1
else
  COLOR_FLAG=0
fi

html="$(hw_device_html "$DEVICE_ID" || true)"

if [ -z "$html" ]; then
  echo "WARNING: no HTML fetched for $DEVICE_ID" >&2
fi

echo
printf '%s\n' "$html" |
  awk -f "$SCRIPT_DIR/hw_html_common.awk" \
      -f "$SCRIPT_DIR/hw_header_layout.awk" \
      -f "$SCRIPT_DIR/hw_device_summary.awk"

echo
printf '%s\n' "$html" |
  awk -f "$SCRIPT_DIR/hw_html_common.awk" \
      -f "$SCRIPT_DIR/hw_header_layout.awk" \
      -f "$SCRIPT_DIR/hw_device_kernel_drivers.awk"

echo
printf '%s\n' "$html" |
  awk -f "$SCRIPT_DIR/hw_html_common.awk" \
      -f "$SCRIPT_DIR/hw_header_layout.awk" \
      -f "$SCRIPT_DIR/hw_device_other_drivers.awk"

echo
printf '%s\n' "$html" |
  awk -v enable_color="$COLOR_FLAG" \
      -f "$SCRIPT_DIR/hw_html_common.awk" \
      -f "$SCRIPT_DIR/hw_header_layout.awk" \
      -f "$SCRIPT_DIR/hw_device_status.awk"
