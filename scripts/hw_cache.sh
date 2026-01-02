#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/hw_init_env.sh"
hw_init_env
. "${SCRIPTS_DIR}/hw_common.sh"

cmd="${1:-}"

usage() {
  cat <<EOF
Usage: $0 <command>
  ls     List cached pages
  clear  Delete all cache
  path   Show cache file path for hw-id, probe-id or device-id
  prime  Refresh cache for hw-id, probe-id or device-id
  stats  Show cache stats
EOF
}

cache_require_file() {
  local f="$1"
  if [ ! -s "$f" ]; then
    echo "ERROR: url not cached $f" >&2
    exit 1
  fi
}

cache_print_path() {
  local url="$1"
  local f
  f="$(hw_cache_key "$url")"
  cache_require_file "$f"
  printf '%s\n' "$f"
}

probe_make_url() {
  local probe_id="$1"
  printf '%s/?probe=%s\n' "$HWGREP_BASE_URL" "$probe_id"
}

computer_make_url() {
  local comp_id="$1"
  printf '%s/?computer=%s\n' "$HWGREP_BASE_URL" "$comp_id"
}

device_make_url() {
  local dev_id="$1"
  local dev_query="$dev_id"
  local encoded

  case "$dev_query" in
    *:*) ;;
    *)
      echo "ERROR: device IDs must include a prefix like pci: or usb: or board: etc, got $dev_id" >&2
      exit 1
      ;;
  esac

  encoded="${dev_query//:/%3A}"
  printf '%s/?id=%s\n' "$HWGREP_BASE_URL" "$encoded"
}

ref_parse_type() {
  local s="${1:-}"
  REF_TYPE=""
  REF_ID=""

  case "$s" in
    probe:*)
      REF_TYPE="probe"
      REF_ID="${s#probe:}"
      ;;
    computer:*)
      REF_TYPE="computer"
      REF_ID="${s#computer:}"
      ;;
    device:*)
      REF_TYPE="device"
      REF_ID="${s#device:}"
      ;;
    *)
      echo "ERROR: expected computer:<computer-id>, probe:<probe-id> or device:<device-id>, got: $s" >&2
      exit 1
      ;;
  esac

  if [ -z "$REF_ID" ]; then
    echo "ERROR: missing ID after '${REF_TYPE}:'" >&2
    exit 1
  fi
}

ref_make_url() {
  local type="$1"
  local id="$2"
  case "$type" in
    probe) probe_make_url "$id" ;;
    computer) computer_make_url "$id" ;;
    device) device_make_url "$id" ;;
    *)
      echo "ERROR: invalid ref type: $type" >&2
      exit 1
      ;;
  esac
}

case "$cmd" in
  ls)
    echo "Cache dir: $HWGREP_CACHE_DIR"
    find "$HWGREP_CACHE_DIR" -type f 2>/dev/null || true
    ;;

  clear)
    echo "Clearing cache at $HWGREP_CACHE_DIR"
    rm -rf "$HWGREP_CACHE_DIR"
    mkdir -p "$HWGREP_CACHE_DIR"
    ;;

  path)
    ref="${2:-}"
    if [ -z "$ref" ]; then
      echo "Usage: $0 path probe:<probe-id>|computer:<computer-id>|device:<device-id>" >&2
      exit 1
    fi

    ref_parse_type "$ref"
    url="$(ref_make_url "$REF_TYPE" "$REF_ID")"
    cache_print_path "$url"
    ;;

  prime)
    shift

    if [ "${HWGREP_CACHE_OFFLINE:-0}" -eq 1 ]; then
      echo "ERROR: cannot prime cache in offline mode" >&2
      exit 1
    fi

    if [ "$#" -eq 0 ]; then
      echo "Usage: $0 prime probe:<probe-id>|computer:<computer-id>|device:<device-id>" >&2
      exit 1
    fi

    for ref in "$@"; do
      [ -n "$ref" ] || continue
      ref_parse_type "$ref"
      url="$(ref_make_url "$REF_TYPE" "$REF_ID")"
      echo "Priming cache ${url}"
      HWGREP_CACHE_REFRESH=1 hw_fetch_page "$url" >/dev/null
    done
    ;;

  stats)
    echo "Cache dir: $HWGREP_CACHE_DIR"
    files=$(find "$HWGREP_CACHE_DIR" -type f 2>/dev/null | wc -l || echo 0)
    echo "Files: $files"
    if [ -d "$HWGREP_CACHE_DIR" ]; then
      size=$(du -sh "$HWGREP_CACHE_DIR" 2>/dev/null | awk '{print $1}')
      echo "Size:  $size"
    fi
    ;;

  -h|--help|"")
    usage
    ;;

  *)
    usage
    exit 1
    ;;
esac
