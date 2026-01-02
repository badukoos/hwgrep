#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/scripts/hw_init_env.sh"
hw_init_env
. "${SCRIPTS_DIR}/hw_common.sh"

COMPUTERS_SCRIPT="${SCRIPTS_DIR}/hw_computers.sh"
PROBES_SCRIPT="${SCRIPTS_DIR}/hw_probes.sh"
DEVICE_DETAILS_SCRIPT="${SCRIPTS_DIR}/hw_device_details.sh"

FILTER_URL=""
COMPUTER_ID=""
PROBE_ID=""
DEVICE_ID=""

TYPE=""
VENDOR=""
MODEL_LIKE=""
MFG_YEAR=""
OS_NAME=""

LIST_COMPUTERS=0
LIST_PROBES=0

LOG_NAME=""
GREP_PATTERN=""

USE_BSD=0

MAX_RESULTS=0
FILTER_DEVICE=()

usage() {
  cat <<EOF
Usage:
  $(basename "$0") [options]

  --computer-id    Computer ID, value of ?computer=... on linux-hardware.org
  --probe-id       Probe ID, value of ?probe=... on linux-hardware.org
  --device-id      Device ID, value of ?id=... on linux-hardware.org

  --type           Computer type e.g. notebook, desktop, server, etc
  --vendor         Vendor name e.g. Lenovo
  --model-like     Model substring e.g. "ThinkPad E14 Gen 7"
  --mfg-year       Computer mfg. year filter e.g. --mfg-year 2025, default: all
  --os-name        OS filter e.g. "Fedora 42", "Ubuntu 24.04" etc

  --filter-url     Full linux-hardware.org or bsd-hardware.info URL
                   This flag is exclusive of other parameters

  --log-name       Log to fetch e.g. dmesg, hwinfo etc
  --grep           Regex to filter log lines

  --list-computers Print computer URLs
  --list-probes    Print probe URLs per computer

  --max-results    Limit number of results per list, 0 is usually max results on a single page

  --filter-device  Row filter key=val for device(s) and (device)status tables

  --offline        Use offline cache
  --no-cache       Get data from network
  --refresh-cache  Re-fetch and overwrite cache

  --bsd            Use bsd-hardware.info instead of linux-hardware.org

  -h, --help       Show this help
EOF
}

error() {
  echo "ERROR: $*" >&2
  exit 1
}

url_encode_ws() {
  local s=$1
  s=${s// /+}
  printf '%s' "$s"
}

_extract_hex_ids() {
  local param="$1"
  local strict="${2:-0}"
  local dedupe="${3:-1}"
  local re

  if [ "$strict" -eq 1 ]; then
    re="[?&]${param}="
  else
    re="${param}="
  fi

  if [ "$dedupe" -eq 1 ]; then
    sed -n "s/.*${re}\([0-9A-Fa-f]\{8,16\}\).*/\1/p" \
      | tr 'A-F' 'a-f' \
      | sort -u
  else
    sed -n "s/.*${re}\([0-9A-Fa-f]\{8,16\}\).*/\1/p" \
      | tr 'A-F' 'a-f'
  fi
}

_extract_device_ids() {
  local param="$1"
  sed -n "s/.*[?&]${param}=\([^&#]*\).*/\1/p"
}

parse_computer_ids() {
  _extract_hex_ids computer 0 1
}

extract_computer_id_url() {
  _extract_hex_ids computer 1 0
}

parse_probe_ids() {
  _extract_hex_ids probe 0 1
}

extract_probe_id_url() {
  _extract_hex_ids probe 1 0
}

parse_device_ids() {
  _extract_device_ids id | sort -u
}

run_computer() {
  local comp_id=$1
  "$COMPUTERS_SCRIPT" --computer-id "$comp_id"
}

run_probes() {
  local probe_id=$1
  local cmd=("$PROBES_SCRIPT" --probe-id "$probe_id")
  local f

  if [ "$MAX_RESULTS" -gt 0 ]; then
    cmd+=("--max-results" "$MAX_RESULTS")
  fi

  if [ "${#FILTER_DEVICE[@]}" -gt 0 ]; then
    for f in "${FILTER_DEVICE[@]}"; do
      cmd+=("--filter-device" "$f")
    done
  fi

  "${cmd[@]}"
}

run_device() {
  local device_id=$1
  local cmd=("$DEVICE_DETAILS_SCRIPT" --device-id "$device_id")
  local f

  if [ "$MAX_RESULTS" -gt 0 ]; then
    cmd+=("--max-results" "$MAX_RESULTS")
  fi

  if [ "${#FILTER_DEVICE[@]}" -gt 0 ]; then
    for f in "${FILTER_DEVICE[@]}"; do
      cmd+=("--filter-device" "$f")
    done
  fi

  "${cmd[@]}"
}

handle_url_mode() {
  local url=$1

  if grep -Eq '[?&]probe=' <<<"$url"; then
    if [ "$LIST_COMPUTERS" -eq 1 ] || [ "$LIST_PROBES" -eq 1 ]; then
      error "--list-computers/--list-probes are only supported for computers URLs, not probe URLs"
    fi

    local probe_ids
    probe_ids="$(extract_probe_id_url <<<"$url")"
    [ -n "$probe_ids" ] || error "No probe IDs found in --filter-url"

    while IFS= read -r pid; do
      [ -n "$pid" ] || continue
      if [ -n "$LOG_NAME" ]; then
        echo "Probe: ${pid}"
        fetch_probe_log "$pid"
      else
        run_probes "$pid"
      fi
      echo
    done <<< "$probe_ids"

    return 0
  fi

  if grep -Eq '[?&]id=' <<<"$url"; then
    if [ "$LIST_COMPUTERS" -eq 1 ] || [ "$LIST_PROBES" -eq 1 ]; then
      error "--list-computers/--list-probes are only supported for computers URLs, not device URLs"
    fi
    if [ -n "$LOG_NAME" ] || [ -n "$GREP_PATTERN" ]; then
      error "--log-name/--grep are only supported for probe/computer queries, not device details"
    fi

    local device_ids
    device_ids="$(parse_device_ids <<<"$url")"
    [ -n "$device_ids" ] || error "No device IDs found in --filter-url"

    while IFS= read -r did; do
      [ -n "$did" ] || continue
      run_device "$did"
      echo
    done <<< "$device_ids"

    return 0
  fi

  return 1
}

list_computer_probes() {
  local comp_id="$1"
  local comp_url="${HWGREP_BASE_URL}/?computer=${comp_id}"

  local cache_file
  cache_file="$(hw_cache_key "$comp_url")"

  local html=""
  if [ -f "$cache_file" ]; then
    html="$(cat "$cache_file")"
  else
    html="$(hw_fetch_page "$comp_url" "")"
  fi

  local probe_ids=""

  if [ -n "${OS_NAME:-}" ]; then
    local AWK_COMMON="${LIB_DIR}/shared/hw_common.awk"
    local AWK_COMP_PROBES="${LIB_DIR}/computer/hw_computer_probes.awk"
    [ -f "$AWK_COMMON" ] || error "Missing: $AWK_COMMON"
    [ -f "$AWK_COMP_PROBES" ] || error "Missing: $AWK_COMP_PROBES"

    probe_ids="$(
      printf '%s\n' "$html" \
        | awk -v comp_mode=index \
              -v os_name="${OS_NAME:-}" \
              -f "$AWK_COMMON" \
              -f "$AWK_COMP_PROBES"
    )"
  fi

  if [ -z "$probe_ids" ]; then
    probe_ids="$(printf '%s\n' "$html" | parse_probe_ids)"
  fi

  [ -n "$probe_ids" ] || return 0

  if [ "$MAX_RESULTS" -gt 0 ]; then
    probe_ids="$(printf '%s\n' "$probe_ids" | head -n "$MAX_RESULTS")"
  fi

  printf '%s\n' "$probe_ids" | sed '/^$/d'
}

fetch_probe_log() {
  local probe_id="$1"
  [ -n "$LOG_NAME" ] || return 0

  local log_url="${HWGREP_BASE_URL}/?log=${LOG_NAME}&probe=${probe_id}"
  hw_logv "Fetching log: ${log_url}"

  local AWK_HTML_TO_TEXT="${LIB_DIR}/shared/hw_html_text.awk"
  local AWK_COLOR_LOGS="${LIB_DIR}/shared/hw_color_logs.awk"

  [ -f "$AWK_HTML_TO_TEXT" ] || error "Missing: $AWK_HTML_TO_TEXT"
  [ -f "$AWK_COLOR_LOGS" ] || error "Missing: $AWK_COLOR_LOGS"

  if [ -n "$GREP_PATTERN" ]; then
    hw_fetch_page "$log_url" "" \
      | awk -v hw_mode=log -f "$AWK_HTML_TO_TEXT" \
      | grep -Ei "$GREP_PATTERN" \
      | awk -f "$AWK_COLOR_LOGS" || echo "  no matches"
  else
    hw_fetch_page "$log_url" "" \
      | awk -v hw_mode=log -f "$AWK_HTML_TO_TEXT" \
      | awk -f "$AWK_COLOR_LOGS"
  fi
}

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --computer-id)
      COMPUTER_ID="${2:-}"
      [ -n "$COMPUTER_ID" ] || error "--computer-id requires a value"
      shift 2
      ;;
    --probe-id)
      PROBE_ID="${2:-}"
      [ -n "$PROBE_ID" ] || error "--probe-id requires a value"
      shift 2
      ;;
    --device-id)
      DEVICE_ID="${2:-}"
      [ -n "$DEVICE_ID" ] || error "--device-id requires a value"
      shift 2
      ;;
    --type)
      TYPE="${2:-}"
      [ -n "$TYPE" ] || error "--type requires a value"
      shift 2
      ;;
    --vendor)
      VENDOR="${2:-}"
      [ -n "$VENDOR" ] || error "--vendor requires a value"
      shift 2
      ;;
    --model-like)
      MODEL_LIKE="${2:-}"
      [ -n "$MODEL_LIKE" ] || error "--model-like requires a value"
      shift 2
      ;;
    --mfg-year)
      MFG_YEAR="${2:-}"
      [ -n "$MFG_YEAR" ] || error "--mfg-year requires a value"
      shift 2
      ;;
    --os-name)
      OS_NAME="${2:-}"
      [ -n "$OS_NAME" ] || error "--os-name requires a value"
      shift 2
      ;;
    --filter-url)
      FILTER_URL="${2:-}"
      [ -n "$FILTER_URL" ] || error "--filter-url requires a value"
      shift 2
      ;;
    --filter-device)
      [ -n "${2:-}" ] || error "--filter-device requires a value"
      case "${2}" in
        *=*)
        FILTER_DEVICE+=("${2}") ;;
        *) error "--filter-device expects key=val, got: ${2}" ;;
      esac
      shift 2
      ;;
    --list-computers)
      LIST_COMPUTERS=1
      shift
      ;;
    --list-probes)
      LIST_PROBES=1
      shift
      ;;
    --max-results)
      MAX_RESULTS="${2:-}"
      [ -n "$MAX_RESULTS" ] || error "--max-results requires a value"
      case "$MAX_RESULTS" in
        ''|*[!0-9]*)
          error "--max-results must be >= 0"
          ;;
      esac
      shift 2
      ;;
    --log-name)
      LOG_NAME="${2:-}"
      [ -n "$LOG_NAME" ] || error "--log-name requires a value"
      shift 2
      ;;
    --grep)
      GREP_PATTERN="${2:-}"
      [ -n "$GREP_PATTERN" ] || error "--grep requires a value"
      shift 2
      ;;
    --offline)
      HWGREP_CACHE_OFFLINE=1
      shift
      ;;
    --no-cache)
      HWGREP_CACHE_DISABLE=1
      shift
      ;;
    --refresh-cache)
      HWGREP_CACHE_REFRESH=1
      shift
      ;;
    --bsd)
      USE_BSD=1
      shift
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

if [ "$USE_BSD" -eq 1 ]; then
  HWGREP_BASE_URL="https://bsd-hardware.info"
fi

[ -x "$COMPUTERS_SCRIPT" ] || error "hw_computers.sh not found or not executable at $COMPUTERS_SCRIPT"
[ -x "$PROBES_SCRIPT" ] || error "hw_probes.sh not found or not executable at $PROBES_SCRIPT"
[ -x "$DEVICE_DETAILS_SCRIPT" ] || error "hw_device_details.sh not found or not executable at $DEVICE_DETAILS_SCRIPT"

if [ -n "$COMPUTER_ID" ] && { [ -n "$PROBE_ID" ] || [ -n "$DEVICE_ID" ]; }; then
  error "Cannot use --computer-id with --probe-id or --device-id"
fi

if [ -n "$PROBE_ID" ] && [ -n "$DEVICE_ID" ]; then
  error "Cannot use --probe-id and --device-id together"
fi

if [ -n "$FILTER_URL" ]; then
  if [ -n "$COMPUTER_ID" \
     ] || [ -n "$PROBE_ID" ] \
     || [ -n "$DEVICE_ID" ] \
     || [ -n "$TYPE" ] \
     || [ -n "$VENDOR" ] \
     || [ -n "$MODEL_LIKE" ] \
     || [ -n "$MFG_YEAR" ] \
     || [ -n "$OS_NAME" ]; then
    error "--filter-url cannot be combined with --computer-id/--probe-id/--device-id or any filter flags"
  fi
fi

if [ -n "$LOG_NAME" ] && { [ "$LIST_COMPUTERS" -eq 1 ] || [ "$LIST_PROBES" -eq 1 ]; }; then
  error "--log-name/--grep cannot be combined with --list-computers/--list-probes"
fi

MODE=""

if [ -n "$COMPUTER_ID" ]; then
  MODE="computer-single"
elif [ -n "$PROBE_ID" ]; then
  MODE="probe-single"
elif [ -n "$DEVICE_ID" ]; then
  MODE="device-single"
elif [ -n "$FILTER_URL" ]; then
  MODE="url"
else
  if [ -n "$TYPE" ] || [ -n "$VENDOR" ] || [ -n "$MODEL_LIKE" ]; then
    if [ -z "$TYPE" ] || [ -z "$VENDOR" ] || [ -z "$MODEL_LIKE" ]; then
      error "When using filters without --computer-id, --probe-id, --device-id, --filter-url you must set --type, --vendor and --model-like"
    fi
    MODE="search"
  fi
fi

if [ -z "$MODE" ]; then
  error "You must specify either --computer-id, --probe-id, --device-id, --filter-url, or all of --type, --vendor and --model-like"
fi

if [ "$MODE" = "probe-single" ]; then
  if [ "$LIST_COMPUTERS" -eq 1 ] || [ "$LIST_PROBES" -eq 1 ]; then
    error "--list-computers and --list-probes are only supported for computers IDs, not probe IDs"
  fi

  if [ -n "$LOG_NAME" ]; then
    echo "Probe: ${PROBE_ID}"
    fetch_probe_log "$PROBE_ID"
  else
    run_probes "$PROBE_ID"
  fi
  exit 0
fi

if [ "$MODE" = "device-single" ]; then
  if [ -n "$LOG_NAME" ] || [ -n "$GREP_PATTERN" ]; then
    error "--log-name and --grep are only supported for probe/computer queries, not device details"
  fi

  run_device "$DEVICE_ID"
  exit 0
fi

if [ "$MODE" = "url" ]; then
  if handle_url_mode "$FILTER_URL"; then
    exit 0
  fi
fi

if [ "$MODE" = "search" ]; then
  year_val="$MFG_YEAR"
  if [ -z "$year_val" ]; then
    year_val="all"
  fi

  enc_type=$(url_encode_ws "$TYPE")
  enc_vendor=$(url_encode_ws "$VENDOR")
  enc_model_like=$(url_encode_ws "$MODEL_LIKE")

  os_filter=""
  if [ -n "$OS_NAME" ]; then
    enc_os_name=$(url_encode_ws "$OS_NAME")
    os_filter="&f=os_name&v=${enc_os_name}"
  fi

  FILTER_URL="${HWGREP_BASE_URL}/?view=computers${os_filter}&type=${enc_type}&vendor=${enc_vendor}&model_like=${enc_model_like}"

  if [ "$year_val" != "all" ] && [ "$year_val" != "ALL" ]; then
    enc_year=$(printf '%s\n' "$year_val" | sed 's/[^0-9]//g')
    [ -n "$enc_year" ] || enc_year="$year_val"
    FILTER_URL="${FILTER_URL}&year=${enc_year}"
  fi

  hw_logv "FILTER_URL = $FILTER_URL"
  echo "Using computers URL:"
  echo "  $FILTER_URL"
  echo
fi

COMPUTER_IDS=""

case "$MODE" in
  computer-single)
    COMPUTER_IDS="$COMPUTER_ID"
    ;;
  url|search)
    if grep -Eq '[?&]computer=' <<<"$FILTER_URL"; then
      COMPUTER_IDS="$(extract_computer_id_url <<<"$FILTER_URL")"
    else
      COMPUTER_IDS="$(hw_fetch_page "$FILTER_URL" "" | parse_computer_ids)"
      [ -n "$COMPUTER_IDS" ] || error "No computer IDs found from FILTER_URL"
    fi
    ;;
esac

if [ -n "$COMPUTER_IDS" ] && [ "$MAX_RESULTS" -gt 0 ]; then
  COMPUTER_IDS="$(printf '%s\n' "$COMPUTER_IDS" | head -n "$MAX_RESULTS")"
fi

[ -n "$COMPUTER_IDS" ] || error "No computer IDs found"

if [ "$LIST_COMPUTERS" -eq 1 ] || [ "$LIST_PROBES" -eq 1 ]; then
  if [ "$LIST_COMPUTERS" -eq 1 ] && [ "$LIST_PROBES" -eq 0 ]; then
    while IFS= read -r comp_id; do
      [ -n "$comp_id" ] || continue
      printf '%s/?computer=%s\n' "$HWGREP_BASE_URL" "$comp_id"
    done <<< "$COMPUTER_IDS"
    exit 0
  fi

  if [ "$LIST_PROBES" -eq 1 ] && [ "$LIST_COMPUTERS" -eq 0 ]; then
    while IFS= read -r comp_id; do
      [ -n "$comp_id" ] || continue
      probes="$(list_computer_probes "$comp_id" || true)"
      [ -z "${probes:-}" ] && continue
      while IFS= read -r pid; do
        [ -n "$pid" ] || continue
        printf '%s:%s/?probe=%s\n' "$comp_id" "$HWGREP_BASE_URL" "$pid"
      done <<< "$probes"
    done <<< "$COMPUTER_IDS"
    exit 0
  fi

  if [ "$LIST_COMPUTERS" -eq 1 ] && [ "$LIST_PROBES" -eq 1 ]; then
    while IFS= read -r comp_id; do
      [ -n "$comp_id" ] || continue
      printf '%s/?computer=%s\n' "$HWGREP_BASE_URL" "$comp_id"
      probes="$(list_computer_probes "$comp_id" || true)"
      if [ -n "${probes:-}" ]; then
        while IFS= read -r pid; do
          [ -n "$pid" ] || continue
          printf '  %s/?probe=%s\n' "$HWGREP_BASE_URL" "$pid"
        done <<< "$probes"
      fi
      echo
    done <<< "$COMPUTER_IDS"
    exit 0
  fi
fi

while IFS= read -r comp_id; do
  [ -n "$comp_id" ] || continue

  run_computer "$comp_id"
  printf '  '
  printf '%*s\n' 47 '' | tr ' ' '-'

  if [ -n "$LOG_NAME" ]; then
    probes="$(list_computer_probes "$comp_id" || true)"
    if [ -n "${probes:-}" ]; then
      while IFS= read -r pid; do
        [ -n "$pid" ] || continue
        echo "Probe: ${pid}"
        fetch_probe_log "$pid"
        echo
      done <<< "$probes"
    fi
  fi
done <<< "$COMPUTER_IDS"
