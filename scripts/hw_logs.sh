#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/hw_common.sh"

PROBE_ID=""

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --probe PROBE_ID

Environment:
  HWGREP_BASE_URL   Base URL (default: https://linux-hardware.org)
  DEBUG_HTML        If 1, save HTML to /tmp/hwgrep.logs.PROBE_ID.html
  VERBOSE           If 1, extra debug output to stderr
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
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$PROBE_ID" ]; then
  echo "Error: --probe PROBE_ID is required" >&2
  usage
  exit 1
fi

logs_url="${HWGREP_BASE_URL}/?probe=${PROBE_ID}"
dbg=""
[ "${DEBUG_HTML:-0}" -eq 1 ] && dbg="/tmp/hwgrep.logs.${PROBE_ID}.html"

hw_logv "Fetching available logs list from: ${logs_url}"
echo "  Available logs for probe ${PROBE_ID}:"

hw_fetch_page "$logs_url" "$dbg" \
  | awk '
      /<a name='\''Logs'\''>/ {inlogs=1; next}
      !inlogs {next}

      /<span class='\''category'\''>/ {
        if (match($0, /<span class='\''category'\''>([^<]+)<\/span>/, m)) {
          category = m[1]
          cat_order[++cat_count] = category
        }
        next
      }

      /class='\''pointer'\''/ && /log=/ {
        logname=""
        label=""

        if (match($0, /log=([^'\''&]+)['\''&]/, m)) {
          logname = m[1]
        }
        if (match($0, />[^<]+<\/a>/, m2)) {
          label = m2[0]
          sub(/^>/, "", label)
          sub(/<\/a>$/, "", label)
        } else {
          label = logname
        }

        if (category != "" && logname != "") {
          logs[category][++count[category]] = label
        }
        next
      }

      END {
        for (i = 1; i <= cat_count; i++) {
          c = cat_order[i]
          print "[" c "]"
          for (j = 1; j <= count[c]; j++) {
            printf("    %s\n", logs[c][j])
          }
          print ""
        }
      }
    '

echo
