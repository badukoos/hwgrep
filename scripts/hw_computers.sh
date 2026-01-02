#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/hw_init_env.sh"
hw_init_env
. "${SCRIPTS_DIR}/hw_common.sh"

COMPUTER_ID=""

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --computer-id <computer-id>
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --computer-id)
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
  echo "ERROR: --computer-id is required" >&2
  usage >&2
  exit 1
fi

tmp_html="$(mktemp)"
trap 'rm -f "$tmp_html"' EXIT

hw_computer_html "$COMPUTER_ID" >"$tmp_html" || true

if [ ! -s "$tmp_html" ]; then
  echo "WARNING: no HTML fetched for computer $COMPUTER_ID" >&2
fi

echo
awk -v COMPUTER_ID="$COMPUTER_ID" \
    -f "$LIB_DIR/shared/hw_common.awk" \
    -f "$LIB_DIR/computer/hw_computer_info.awk" \
    -f "$LIB_DIR/computer/hw_computer_probes.awk" \
    -f "$LIB_DIR/computer/hw_computer_render.awk" \
    <"$tmp_html"
