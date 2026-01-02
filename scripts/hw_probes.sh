#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/hw_init_env.sh"
hw_init_env
. "${SCRIPTS_DIR}/hw_common.sh"

PROBE_ID=""
MAX_RESULTS=0

FILTERS=()

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --probe-id <probe-id> [--max-results N] [--filter-device key=val]
EOF
}

extract_devices_tbl() {
  local f="$1"
  sed -n '/<table[^>]*dev_info[^>]*highlight[^>]*>/,/<\/table>/p' "$f"
}

count_devices_rows() {
  local f="$1"
  local n

  n="$(sed -n '/<table[^>]*dev_info[^>]*highlight[^>]*>/,/<\/table>/p' "$f" | grep -c '</tr>' || true)"
  if [ "${n:-0}" -le 0 ]; then
    echo 0
    return 0
  fi

  n=$((n - 1))
  if [ "$n" -lt 0 ]; then
    n=0
  fi

  echo "$n"
}

cap_results() {
  local n="${1:-0}"
  local HARD_CAP=250

  if [ "$n" -le 0 ]; then
    echo 0
    return 0
  fi

  if [ "$n" -gt "$HARD_CAP" ]; then
    echo "$HARD_CAP"
    return 0
  fi

  echo "$n"
}

has_probe_page_link() {
  local f="$1"
  local p="$2"
  grep -Eq "([?&]page=${p})([^0-9]|$)" "$f"
}

add_filter_clause() {
  local s="${1:-}"
  local k v

  case "$s" in
    *=*)
      k="${s%%=*}"
      v="${s#*=}"
      ;;
    *)
      echo "ERROR: --filter-device expects key=val, got: $s" >&2
      exit 1
      ;;
  esac

  k="${k#"${k%%[![:space:]]*}"}"
  k="${k%"${k##*[![:space:]]}"}"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"

  [ -n "$k" ] || { echo "ERROR: --filter-device key is empty" >&2; exit 1; }
  [ -n "$v" ] || { echo "ERROR: --filter-device value is empty" >&2; exit 1; }

  FILTERS+=("${k}=${v}")
}

while [ $# -gt 0 ]; do
  case "$1" in
    --probe-id)
      PROBE_ID="${2:-}"
      shift 2
      ;;
    --max-results)
      MAX_RESULTS="${2:-}"
      [ -n "$MAX_RESULTS" ] || { echo "ERROR: --max-results requires a value" >&2; exit 1; }
      case "$MAX_RESULTS" in
        ''|*[!0-9]*)
          echo "ERROR: --max-results must be >= 0" >&2
          exit 1
          ;;
      esac
      shift 2
      ;;
    --filter-device)
      add_filter_clause "${2:-}"
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

ROW_FILTER=""
if [ "${#FILTERS[@]}" -gt 0 ]; then
  ROW_FILTER="$(printf '%s\n' "${FILTERS[@]}")"
fi

if [ -z "$PROBE_ID" ]; then
  echo "ERROR: --probe-id is required" >&2
  usage >&2
  exit 1
fi

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  COLOR_FLAG=1
else
  COLOR_FLAG=0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

tmp_html="${tmpdir}/probe.html"
: >"$tmp_html"

limit="$(cap_results "$MAX_RESULTS")"

paginate=0
if [ "$limit" -gt 0 ]; then
  paginate=1
fi

if [ "$paginate" -eq 1 ]; then
  page1_file="${tmpdir}/page.1.html"
  page1_block="${tmpdir}/devices.1.html"

  hw_probe_html_page "$PROBE_ID" 1 >"$page1_file" || true
  if [ -s "$page1_file" ]; then
    cat "$page1_file" >>"$tmp_html"
    extract_devices_tbl "$page1_file" >"$page1_block" || true
  fi

  need="$limit"
  got="$(count_devices_rows "$page1_block")"
  if [ "${got:-0}" -gt 0 ]; then
    if [ "$got" -ge "$need" ]; then
      need=0
    else
      need=$((need - got))
    fi
  else
    need=0
  fi

  if [ "$need" -gt 0 ] && ! has_probe_page_link "$page1_file" 2; then
    need=0
  fi

  prev_hash=""
  if [ -s "$page1_block" ]; then
    prev_hash="$(sha256sum "$page1_block" | awk '{print $1}')"
  fi

  page=2
  max_pages=5

  while [ "$page" -le "$max_pages" ] && [ "$need" -gt 0 ]; do
    page_file="${tmpdir}/page.${page}.html"
    block_file="${tmpdir}/devices.${page}.html"

    hw_probe_html_page "$PROBE_ID" "$page" >"$page_file" || true
    if [ ! -s "$page_file" ]; then
      break
    fi

    extract_devices_tbl "$page_file" >"$block_file" || true
    if [ ! -s "$block_file" ]; then
      break
    fi

    cur_hash="$(sha256sum "$block_file" | awk '{print $1}')"
    if [ -n "$prev_hash" ] && [ "$cur_hash" = "$prev_hash" ]; then
      break
    fi
    prev_hash="$cur_hash"

    cat "$block_file" >>"$tmp_html"

    got="$(count_devices_rows "$block_file")"
    if [ "${got:-0}" -le 0 ]; then
      break
    fi

    if [ "$got" -ge "$need" ]; then
      need=0
      break
    fi

    need=$((need - got))
    page=$((page + 1))
  done
else
  hw_probe_html "$PROBE_ID" >"$tmp_html" || true
fi

if [ ! -s "$tmp_html" ]; then
  echo "WARNING: no HTML fetched for probe $PROBE_ID" >&2
fi

echo
awk -v enable_color="$COLOR_FLAG" \
    -v devices_multipage="$paginate" \
    -v max_results="$limit" \
    -v row_filter="$ROW_FILTER" \
    -f "$LIB_DIR/shared/hw_common.awk" \
    -f "$LIB_DIR/shared/hw_row_filter.awk" \
    -f "$LIB_DIR/probe/hw_probe_host.awk" \
    -f "$LIB_DIR/probe/hw_probe_devices.awk" \
    -f "$LIB_DIR/probe/hw_probe_render.awk" \
    <"$tmp_html"

echo
awk -f "$LIB_DIR/shared/hw_html_text.awk" <"$tmp_html" \
  | awk -f "$LIB_DIR/shared/hw_common.awk" \
        -f "$LIB_DIR/probe/hw_probe_logs.awk"
