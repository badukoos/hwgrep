#!/usr/bin/env bash
set -euo pipefail

HWGREP_BASE_URL="${HWGREP_BASE_URL:-https://linux-hardware.org}"
DEBUG_HTML="${DEBUG_HTML:-0}"
VERBOSE="${VERBOSE:-0}"

HW_CACHE_DIR="${HW_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/hwgrep}"
HW_CACHE_DISABLE="${HW_CACHE_DISABLE:-0}"
HW_CACHE_REFRESH="${HW_CACHE_REFRESH:-0}"
HW_CACHE_OFFLINE="${HW_CACHE_OFFLINE:-0}"

hw_logv() {
  if [ "${VERBOSE:-0}" -eq 1 ]; then
    printf '[hw_common] %s\n' "$*" >&2
  fi
}

hw_dbg_enabled() {
  [ "${DEBUG_HTML:-0}" -eq 1 ]
}

hw_clean_name() {
  local s="${1:-}"
  s="${s//[^A-Za-z0-9._-]/_}"
  printf '%s' "$s"
}

hw_dbg_file() {
  local kind="${1:-page}"
  local id="${2:-}"
  if ! hw_dbg_enabled; then
    return 0
  fi

  if [ -z "$id" ]; then
    printf '/tmp/hwgrep.%s.html' "$kind"
    return 0
  fi

  printf '/tmp/hwgrep.%s.%s.html' "$kind" "$(hw_clean_name "$id")"
}

hw_cache_init() {
  mkdir -p "${HW_CACHE_DIR}"
}

hw_cache_key() {
  local url="${1:-}"
  if [ -z "$url" ]; then
    return 1
  fi

  local hash
  hash="$(printf '%s' "$url" | sha256sum | awk '{print $1}')"
  printf '%s/page-%s.html' "$HW_CACHE_DIR" "$hash"
}

hw_cache_put() {
  local url="$1"
  local tmp_file="$2"

  local cache_file
  cache_file="$(hw_cache_key "$url")"

  mkdir -p "$(dirname "$cache_file")"
  mv "$tmp_file" "$cache_file"
  hw_logv "cache store: $url -> $cache_file"
}

hw_dump_file() {
  local src="$1"
  local dbg="${2:-}"

  if hw_dbg_enabled && [ -n "$dbg" ]; then
    tee "$dbg" <"$src"
  else
    cat "$src"
  fi
}

hw_fetch_page() {
  local url="$1"
  local dbg="${2:-}"

  hw_cache_init

  local cache_file
  cache_file="$(hw_cache_key "$url")"

  if [ "${HW_CACHE_DISABLE:-0}" -eq 0 ] && [ "${HW_CACHE_REFRESH:-0}" -eq 0 ]; then
    if [ -f "$cache_file" ]; then
      hw_logv "cache hit: $url -> $cache_file"
      hw_dump_file "$cache_file" "$dbg"
      return 0
    fi
  fi

  if [ "${HW_CACHE_OFFLINE:-0}" -eq 1 ]; then
    echo "hwgrep: offline mode and cache miss for $url" >&2
    return 1
  fi

  hw_logv "fetching URL: $url"

  local tmp
  tmp="$(mktemp "${HW_CACHE_DIR}/hwgrep.XXXXXX")"

  if ! curl -sL --compressed \
      -A 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.7444.175 Safari/537.36' \
      "$url" >"$tmp"; then
    hw_logv "network fetch failed for $url"

    if [ "${HW_CACHE_DISABLE:-0}" -eq 0 ] && [ -f "$cache_file" ]; then
      hw_logv "using stale cache for $url"
      rm -f "$tmp"
      hw_dump_file "$cache_file" "$dbg"
      return 0
    fi

    rm -f "$tmp"
    return 1
  fi

  if [ "${HW_CACHE_DISABLE:-0}" -eq 0 ]; then
    hw_cache_put "$url" "$tmp"
    hw_dump_file "$cache_file" "$dbg"
  else
    hw_dump_file "$tmp" "$dbg"
    rm -f "$tmp"
  fi
}

hw_html_to_text() {
  awk -f "${SCRIPT_DIR}/hw_html_text.awk"
}

hw_probe_html() {
  local probe_id="$1"
  local url="${HWGREP_BASE_URL}/?probe=${probe_id}"
  hw_fetch_page "$url" "$(hw_dbg_file probe "$probe_id")"
}

hw_probe_text() {
  local probe_id="$1"
  hw_probe_html "$probe_id" | hw_html_to_text
}

hw_probe_system() {
  local probe_id="${1:?probe id required}"
  hw_probe_text "$probe_id" | awk -f "${SCRIPT_DIR}/hw_probe_system.awk"
}

hw_color_logs() {
  if [ -n "${NO_COLOR:-}" ]; then
    cat
    return 0
  fi
  awk -f "${SCRIPT_DIR}/hw_color_logs.awk"
}

hw_device_html() {
  local dev_id="$1"
  local dev_query="$dev_id"

  case "$dev_query" in
    *:*) ;;
    *) dev_query="pci:${dev_query}" ;;
  esac

  local encoded="${dev_query//:/%3A}"
  local url="${HWGREP_BASE_URL}/?id=${encoded}"

  hw_fetch_page "$url" "$(hw_dbg_file device "$encoded")"
}

hw_device_text() {
  local dev_id="$1"
  hw_device_html "$dev_id" | hw_html_to_text
}

hw_computer_html() {
  local computer_id="$1"
  local url="${HWGREP_BASE_URL}/?computer=${computer_id}"
  hw_fetch_page "$url" "$(hw_dbg_file computer "$computer_id")"
}
