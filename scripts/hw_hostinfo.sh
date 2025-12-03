#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/hw_common.sh"

PROBE_ID=""

while [ $# -gt 0 ]; do
  case "$1" in
    --probe)
      PROBE_ID="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") --probe PROBE_ID"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

[ -n "$PROBE_ID" ] || { echo "Error: --probe required" >&2; exit 1; }

text="$(hw_probe_text "$PROBE_ID")"

host_block="$(
  printf '%s\n' "$text" \
    | awk '
        $0 ~ /^Host[[:space:]]*$/ {inhost=1; next}
        inhost && $0 ~ /^Devices[[:space:]]*\(/ {exit}
        inhost
      '
)"

echo "  Host summary:"
printf '%s\n' "$host_block" \
  | awk '
      BEGIN { cur = "" }
      {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
        if ($0 == "" || $0 == "Host" || $0 == "Devices" || $0 == "Logs") next

        if ($0 ~ /^(System|Arch|Kernel|Vendor|Model|Year|HWid|Type|DE)$/) {
          cur = $0
          if (!(cur in seen)) {
            order[++n] = cur
            seen[cur] = 1
          }
          next
        }

        if (cur != "") {
          if (val[cur] != "") {
            val[cur] = val[cur] " " $0
          } else {
            val[cur] = $0
          }
        }
      }
      END {
        for (i = 1; i <= n; i++) {
          k = order[i]
          if (val[k] != "") {
            printf("    %-7s : %s\n", k, val[k])
          }
        }
      }
    '
echo
