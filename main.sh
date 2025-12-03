#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/scripts/hw_common.sh"

HW_HOSTINFO_SCRIPT="${SCRIPT_DIR}/scripts/hw_hostinfo.sh"
HW_DEVICES_SCRIPT="${SCRIPT_DIR}/scripts/hw_devices.sh"
HW_LOGS_SCRIPT="${SCRIPT_DIR}/scripts/hw_logs.sh"

HWGREP_BASE_URL="https://linux-hardware.org"
FILTER_URL=""
TYPE=""
VENDOR=""
MODEL_LIKE=""
YEAR=""
LOG_NAME=""
GREP_PATTERN=""
SLEEP_SEC=1
MAX_PROBES=0
MAX_COMPUTERS=5
VERBOSE=0
DRY_RUN=0
HOST_INFO=0
LIST_DEVICES=0
DEBUG_HTML=0
AVAILABLE_LOGS=0
LOG_EXPLICIT=0
SKIP_LOGS=0

usage() {
  cat <<EOF
Usage:
  $(basename "$0") [options]

Filters:
  --type TYPE           Computer type e.g notebook, desktop, server, etc
  --vendor VENDOR       Vendor name, e.g. Lenovo
  --model-like STR      Model substring, e.g. "ThinkPad E14 Gen 7"
  --year YEAR           Mfg. year filter e.g. --year 2025 or --year all
                        Default: current year from "date +%Y"

  --filter-url URL      Full ?view=computers, ?computer= or ?probe= URL. If this
                        is set, --type/--vendor/--model-like/--year are ignored.

Logs:
  --log NAME            Log to fetch (default: dmesg unless host/devices-only)
  --grep REGEX          Case-insensitive regex to filter log lines
  --sleep SECONDS       Pause between probe log fetches (default: 1)
  --max-probes N        Stop after N probes (0 = unlimited)
  --max-computers N     Stop after N computers (0 = unlimited, default: 5)
  --available-logs      List available logs

Other:
  --dry-run             Only list computer IDs and probe IDs
  --host-info           Show Host summary
  --list-devices        Show Devices table
  --verbose             Extra debug output to stderr
  --debug-html          Save HTML to /tmp/hwgrep.*.html for inspection
  -h, --help            Show this help
EOF
}

encode_spaces_as_plus() {
  printf '%s\n' "$1" | sed 's/ /+/g'
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
      LOG_EXPLICIT=1
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
    --available-logs)
      AVAILABLE_LOGS=1
      shift
      ;;
    --host-info)
      HOST_INFO=1
      shift
      ;;
    --list-devices|--devices-info)
      LIST_DEVICES=1
      shift
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

if [ "$HOST_INFO" -eq 1 ] || [ "$LIST_DEVICES" -eq 1 ]; then
  if [ "$AVAILABLE_LOGS" -eq 0 ] && [ "$LOG_EXPLICIT" -eq 0 ] && [ -z "$GREP_PATTERN" ]; then
    SKIP_LOGS=1
  fi
fi

if [ -z "$LOG_NAME" ] && [ "$SKIP_LOGS" -eq 0 ]; then
  LOG_NAME="dmesg"
fi

if [ -n "$FILTER_URL" ] && printf '%s\n' "$FILTER_URL" | grep -q 'probe='; then
  PROBE_ID="$(
    printf '%s\n' "$FILTER_URL" \
      | sed -n 's/.*probe=\([0-9A-Fa-f]\{8,16\}\).*/\1/p' \
      | tr 'A-F' 'a-f' \
      | head -n 1
  )"

  if [ -z "$PROBE_ID" ]; then
    echo "Error: could not extract probe ID from --filter-url" >&2
    exit 1
  fi

  echo "Probe: ${PROBE_ID}"
  echo "URL:   ${HWGREP_BASE_URL}/?probe=${PROBE_ID}"

  if [ "$DRY_RUN" -eq 1 ]; then
    exit 0
  fi

  if [ "$HOST_INFO" -eq 1 ]; then
    HWGREP_BASE_URL="$HWGREP_BASE_URL" \
    DEBUG_HTML="$DEBUG_HTML" \
    VERBOSE="$VERBOSE" \
      "$HW_HOSTINFO_SCRIPT" \
        --probe "$PROBE_ID"
  fi

  if [ "$LIST_DEVICES" -eq 1 ]; then
    HWGREP_BASE_URL="$HWGREP_BASE_URL" \
    DEBUG_HTML="$DEBUG_HTML" \
    VERBOSE="$VERBOSE" \
      "$HW_DEVICES_SCRIPT" \
        --probe "$PROBE_ID"
  fi


  if [ "$AVAILABLE_LOGS" -eq 1 ]; then
    HWGREP_BASE_URL="$HWGREP_BASE_URL" \
    DEBUG_HTML="$DEBUG_HTML" \
    VERBOSE="$VERBOSE" \
      "$HW_LOGS_SCRIPT" \
        --probe "$PROBE_ID"
    exit 0
  fi

  if [ "$SKIP_LOGS" -eq 1 ] || [ -z "$LOG_NAME" ]; then
    exit 0
  fi

  log_url="${HWGREP_BASE_URL}/?log=${LOG_NAME}&probe=${PROBE_ID}"
  hw_logv "Fetching log: ${log_url}"

  if [ -n "$GREP_PATTERN" ]; then
    hw_fetch_page "$log_url" "" \
      | hw_html_to_text \
      | grep -Ei "$GREP_PATTERN" || echo "  no matches"
  else
    hw_fetch_page "$log_url" "" \
      | hw_html_to_text
  fi


  echo
  exit 0
fi

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

hw_logv "FILTER_URL = $FILTER_URL"
echo "Using computers URL:"
echo "  $FILTER_URL"
echo

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry-run mode: will list computer IDs and probe IDs only"
fi

computers_html_dbg=""
[ "$DEBUG_HTML" -eq 1 ] && computers_html_dbg="/tmp/hwgrep.computers.html"

COMPUTER_IDS=$(
  hw_fetch_page "$FILTER_URL" "$computers_html_dbg" \
    | sed -n 's/.*computer=\([0-9A-Fa-f]\{8,16\}\).*/\1/p' \
    | tr 'A-F' 'a-f' \
    | sort -u
)

if [ -z "$COMPUTER_IDS" ]; then
  echo "No computer IDs found" >&2
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
  echo "Computer ID: ${COMPUTER_ID}"
  echo "URL:        ${comp_url}"

  comp_html_dbg=""
  [ "$DEBUG_HTML" -eq 1 ] && comp_html_dbg="/tmp/hwgrep.computer.${COMPUTER_ID}.html"

  PROBE_IDS=$(
    hw_fetch_page "$comp_url" "$comp_html_dbg" \
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

    if [ "$DRY_RUN" -eq 1 ] || [ "$SKIP_LOGS" -eq 1 ] && [ "$HOST_INFO" -eq 0 ] && [ "$LIST_DEVICES" -eq 0 ]; then
      echo
      continue
    fi

    if [ "$HOST_INFO" -eq 1 ]; then
      HWGREP_BASE_URL="$HWGREP_BASE_URL" \
      DEBUG_HTML="$DEBUG_HTML" \
      VERBOSE="$VERBOSE" \
        "$HW_HOSTINFO_SCRIPT" \
          --probe "$PROBE_ID"
    fi

    if [ "$LIST_DEVICES" -eq 1 ]; then
      HWGREP_BASE_URL="$HWGREP_BASE_URL" \
      DEBUG_HTML="$DEBUG_HTML" \
      VERBOSE="$VERBOSE" \
        "$HW_DEVICES_SCRIPT" \
          --probe "$PROBE_ID"
    fi

    if [ "$AVAILABLE_LOGS" -eq 1 ]; then
      HWGREP_BASE_URL="$HWGREP_BASE_URL" \
      DEBUG_HTML="$DEBUG_HTML" \
      VERBOSE="$VERBOSE" \
        "$HW_LOGS_SCRIPT" \
          --probe "$PROBE_ID"
      continue
    fi

    if [ "$SKIP_LOGS" -eq 1 ] || [ -z "$LOG_NAME" ]; then
      echo
      continue
    fi

    log_url="${HWGREP_BASE_URL}/?log=${LOG_NAME}&probe=${PROBE_ID}"
    hw_logv "Fetching log: ${log_url}"

    if [ -n "$GREP_PATTERN" ]; then
      hw_fetch_page "$log_url" "" \
        | hw_html_to_text \
        | grep -Ei "$GREP_PATTERN" || echo "  no matches"
    else
      hw_fetch_page "$log_url" "" \
        | hw_html_to_text
    fi

    echo
    sleep "$SLEEP_SEC"
  done

  echo
done
