#!/usr/bin/env bash
set -euo pipefail

HWGREP_BASE_URL="https://linux-hardware.org"
FILTER_URL=""
TYPE=""
VENDOR=""
MODEL_LIKE=""
YEAR=""
LOG_NAME="dmesg"
GREP_PATTERN=""
SLEEP_SEC=1
MAX_PROBES=0
MAX_COMPUTERS=5
VERBOSE=0
DRY_RUN=0
DEBUG_HTML=0

usage() {
  cat <<EOF
Usage:
  $(basename "$0") [options]

Filters:
  --type TYPE           Computer type e.g notebook, desktop, server, etc
  --vendor VENDOR       Vendor name, e.g. Lenovo, Dell
  --model-like STR      Model substring, e.g. "ThinkPad E14 Gen 7"
  --year YEAR           Mfg. year filter e.g. --year 2025 --year all
                        Default: current year from "date +%Y"

  --filter-url URL      Full ?view=computers URL. If this is set,
                        --type/--vendor/--model-like/--year are ignored.

Logs:
  --log NAME            Log to fetch default: dmesg
  --grep REGEX          Case-insensitive regex to filter log lines
  --sleep SECONDS       Pause between probe log fetches default: 1
  --max-probes N        Stop after N probes 0 = unlimited
  --max-computers N     Stop after N computers 0 = unlimited
                        Default: 5

Other:
  --dry-run             Only list computer IDs and probe IDs
  --verbose             Extra debug output to stderr
  --debug-html          Save HTML to /tmp/hwgrep.*.html for inspection
  -h, --help            Show this help
EOF
}

logv() {
  if [ "$VERBOSE" -eq 1 ]; then
    printf '[hwgrep] %s\n' "$*" >&2
  fi
}

encode_spaces_as_plus() {
  printf '%s\n' "$1" | sed 's/ /+/g'
}

fetch_page() {
  local url="$1"
  local dbg="${2:-}"

  logv "Fetching URL: $url"
  if [ "$DEBUG_HTML" -eq 1 ] && [ -n "$dbg" ]; then
    curl -sL --compressed \
      -A 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36' \
      "$url" | tee "$dbg"
  else
    curl -sL --compressed \
      -A 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36' \
      "$url"
  fi
}

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --type)
      TYPE="${2:-}"
      shift 2
      ;;
    --vendor)
      VENDOR="${2:-}"
      shift 2
      ;;
    --model-like)
      MODEL_LIKE="${2:-}"
      shift 2
      ;;
    --year)
      YEAR="${2:-}"
      shift 2
      ;;
    --log)
      LOG_NAME="${2:-}"
      shift 2
      ;;
    --grep)
      GREP_PATTERN="${2:-}"
      shift 2
      ;;
    --filter-url)
      FILTER_URL="${2:-}"
      shift 2
      ;;
    --sleep)
      SLEEP_SEC="${2:-}"
      shift 2
      ;;
    --max-probes)
      MAX_PROBES="${2:-}"
      shift 2
      ;;
    --max-computers)
      MAX_COMPUTERS="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    --debug-html)
      DEBUG_HTML=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$FILTER_URL" ]; then
  if [ -z "$TYPE" ] || [ -z "$VENDOR" ] || [ -z "$MODEL_LIKE" ]; then
    echo "Error: either --filter-url OR all of --type/--vendor/--model-like are required" >&2
    exit 1
  fi

  if [ -z "$YEAR" ]; then
    YEAR="$(date +%Y)"
  fi

  enc_type=$(encode_spaces_as_plus "$TYPE")
  enc_vendor=$(encode_spaces_as_plus "$VENDOR")
  enc_model_like=$(encode_spaces_as_plus "$MODEL_LIKE")

  FILTER_URL="${HWGREP_BASE_URL}/?view=computers&type=${enc_type}&vendor=${enc_vendor}&model_like=${enc_model_like}"

  if [ "$YEAR" != "all" ] && [ "$YEAR" != "ALL" ]; then
    enc_year=$(printf '%s\n' "$YEAR" | sed 's/[^0-9]//g')
    [ -n "$enc_year" ] || enc_year="$YEAR"
    FILTER_URL="${FILTER_URL}&year=${enc_year}"
  fi
fi

logv "FILTER_URL = $FILTER_URL"
echo "Using computers URL:"
echo "  $FILTER_URL"
echo

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry-run mode: will list computer IDs and probe IDs only"
fi

computers_html_dbg=""
[ "$DEBUG_HTML" -eq 1 ] && computers_html_dbg="/tmp/hwgrep.computers.html"

COMPUTER_IDS=$(
  fetch_page "$FILTER_URL" "$computers_html_dbg" \
    | sed -n 's/.*computer=\([0-9A-Fa-f]\{8,16\}\).*/\1/p' \
    | tr 'A-F' 'a-f' \
    | sort -u
)

if [ -z "$COMPUTER_IDS" ]; then
  echo "No computer IDs found in computers page" >&2
  if [ "$DEBUG_HTML" -eq 1 ] && [ -n "$computers_html_dbg" ]; then
    echo "Saved HTML to $computers_html_dbg for inspection" >&2
  fi
  exit 1
fi

if [ "$MAX_COMPUTERS" -gt 0 ]; then
  COMPUTER_IDS=$(printf '%s\n' "$COMPUTER_IDS" | head -n "$MAX_COMPUTERS")
fi

echo "Found computers, showing up to $MAX_COMPUTERS:"
echo "$COMPUTER_IDS" | sed 's/^/  computer=/'
echo

probe_count=0

echo "$COMPUTER_IDS" | while read -r COMPUTER_ID; do
  [ -n "$COMPUTER_ID" ] || continue

  comp_url="${HWGREP_BASE_URL}/?computer=${COMPUTER_ID}"
  echo "*******************************"
  echo "Computer ID: ${COMPUTER_ID}"
  echo "URL:        ${comp_url}"
  echo "*******************************"

  comp_html_dbg=""
  [ "$DEBUG_HTML" -eq 1 ] && comp_html_dbg="/tmp/hwgrep.computer.${COMPUTER_ID}.html"

  PROBE_IDS=$(
    fetch_page "$comp_url" "$comp_html_dbg" \
      | sed -n 's/.*probe=\([0-9A-Fa-f]\{8,16\}\).*/\1/p' \
      | tr 'A-F' 'a-f' \
      | sort -u
  )

  if [ -z "$PROBE_IDS" ]; then
    echo "  No probes found for this computer"
    echo
    continue
  fi

  echo "  Probes:"
  echo "$PROBE_IDS" | sed 's/^/    /'
  echo

  echo "$PROBE_IDS" | while read -r PROBE_ID; do
    [ -n "$PROBE_ID" ] || continue

    probe_count=$((probe_count + 1))
    if [ "$MAX_PROBES" -gt 0 ] && [ "$probe_count" -gt "$MAX_PROBES" ]; then
      echo "Probe limit reached (MAX_PROBES = ${MAX_PROBES}). Stopping."
      exit 0
    fi

    echo "Probe: ${PROBE_ID}"

    if [ "$DRY_RUN" -eq 1 ]; then
      echo
      continue
    fi

    log_url="${HWGREP_BASE_URL}/?log=${LOG_NAME}&probe=${PROBE_ID}"
    logv "Fetching log: ${log_url}"

    if [ -n "$GREP_PATTERN" ]; then
      fetch_page "$log_url" "" \
        | sed 's/<[^>]*>//g' \
        | grep -Ei "$GREP_PATTERN" || echo "  no matches"
    else
      fetch_page "$log_url" ""
    fi

    echo
    sleep "$SLEEP_SEC"
  done

  echo
done
