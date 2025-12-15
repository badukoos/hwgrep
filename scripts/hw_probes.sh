#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/hw_common.sh"

PROBE_ID=""

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --probe <probe-id>
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --probe)
      PROBE_ID="${2:-}"
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

if [ -z "$PROBE_ID" ]; then
  echo "ERROR: --probe is required" >&2
  usage >&2
  exit 1
fi

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  COLOR_FLAG=1
else
  COLOR_FLAG=0
fi

html="$(hw_probe_html "$PROBE_ID" || true)"

if [ -z "$html" ]; then
  echo "WARNING: no HTML fetched for probe $PROBE_ID" >&2
fi

echo
printf '%s\n' "$html" \
  | awk -f "$SCRIPT_DIR/hw_text_common.awk" \
        -f "$SCRIPT_DIR/hw_html_cells.awk" \
        -f "$SCRIPT_DIR/hw_probe_host.awk"

echo
printf '%s\n' "$html" \
  | awk -v enable_color="$COLOR_FLAG" \
        -f "$SCRIPT_DIR/hw_text_common.awk" \
        -f "$SCRIPT_DIR/hw_html_cells.awk" \
        -f "$SCRIPT_DIR/hw_table_common.awk" \
        -f "$SCRIPT_DIR/hw_status_common.awk" \
        -f "$SCRIPT_DIR/hw_header_layout.awk" \
        -f "$SCRIPT_DIR/hw_probe_devices.awk"

echo
hw_probe_text "$PROBE_ID" \
  | awk -f "$SCRIPT_DIR/hw_text_common.awk" \
        -f "$SCRIPT_DIR/hw_probe_logs.awk"
