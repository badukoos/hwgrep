#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/hw_common.sh"

COMPUTER_ID=""

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --computer <computer-id>
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --computer)
      COMPUTER_ID="${2:-}"
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

if [ -z "$COMPUTER_ID" ]; then
  echo "ERROR: --computer is required" >&2
  usage >&2
  exit 1
fi

html="$(hw_computer_html "$COMPUTER_ID" || true)"

if [ -z "$html" ]; then
  echo "WARNING: no HTML fetched for computer $COMPUTER_ID" >&2
fi

echo
printf '%s\n' "$html" \
  | awk -f "$SCRIPT_DIR/hw_text_common.awk" \
        -f "$SCRIPT_DIR/hw_html_cells.awk" \
        -f "$SCRIPT_DIR/hw_computer_summary.awk"

echo
printf '%s\n' "$html" \
  | awk -f "$SCRIPT_DIR/hw_text_common.awk" \
        -f "$SCRIPT_DIR/hw_html_cells.awk" \
        -f "$SCRIPT_DIR/hw_table_common.awk" \
        -f "$SCRIPT_DIR/hw_header_layout.awk" \
        -f "$SCRIPT_DIR/hw_computer_probes.awk"
