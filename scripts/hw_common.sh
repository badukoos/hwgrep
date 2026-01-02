#!/usr/bin/env bash
set -euo pipefail

HWGREP_BASE_URL="${HWGREP_BASE_URL:-https://linux-hardware.org}"
HWGREP_VERBOSE="${HWGREP_VERBOSE:-0}"

HWGREP_DUMP_HTML="${HWGREP_DUMP_HTML:-0}"

HWGREP_CACHE_DIR="${HWGREP_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/hwgrep}"
HWGREP_CACHE_DISABLE="${HWGREP_CACHE_DISABLE:-0}"
HWGREP_CACHE_REFRESH="${HWGREP_CACHE_REFRESH:-0}"
HWGREP_CACHE_OFFLINE="${HWGREP_CACHE_OFFLINE:-0}"

export HWGREP_BASE_URL \
       HWGREP_VERBOSE HWGREP_DUMP_HTML \
       HWGREP_CACHE_DIR HWGREP_CACHE_DISABLE \
       HWGREP_CACHE_REFRESH HWGREP_CACHE_OFFLINE

: "${LIB_DIR:?LIB_DIR must be set}"

hw_logv() {
  if [ "${HWGREP_VERBOSE:-0}" -eq 1 ]; then
    printf '[hw_common] %s\n' "$*" >&2
  fi
}

hw_dump_html_enabled() {
  [ "${HWGREP_DUMP_HTML:-0}" -eq 1 ]
}

hw_clean_name() {
  local s="${1:-}"
  s="${s//[^A-Za-z0-9._-]/_}"
  printf '%s' "$s"
}

hw_dump_html_file() {
  local type="${1:-page}"
  local id="${2:-}"

  if ! hw_dump_html_enabled; then
    return 0
  fi

  if [ -z "$id" ]; then
    printf '/tmp/hwgrep.%s.html' "$type"
    return 0
  fi

  printf '/tmp/hwgrep.%s.%s.html' "$type" "$(hw_clean_name "$id")"
}

hw_cache_init() {
  mkdir -p "${HWGREP_CACHE_DIR}"
}

hw_cache_key() {
  local url="${1:-}"
  [ -n "$url" ] || return 1

  local hash
  hash="$(printf '%s' "$url" | sha256sum | awk '{print $1}')"
  printf '%s/page-%s.html' "$HWGREP_CACHE_DIR" "$hash"
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

hw_dump_stream() {
  local src="$1"
  local dump_path="${2:-}"

  if hw_dump_html_enabled && [ -n "$dump_path" ]; then
    tee "$dump_path" <"$src"
  else
    cat "$src"
  fi
}

hw_fetch_page() {
  local url="$1"
  local dump_path="${2:-}"

  hw_cache_init

  local cache_file
  cache_file="$(hw_cache_key "$url")"

  if [ "${HWGREP_CACHE_DISABLE:-0}" -eq 0 ] &&
     [ "${HWGREP_CACHE_REFRESH:-0}" -eq 0 ]; then
    if [ -f "$cache_file" ]; then
      hw_logv "cache hit: $url -> $cache_file"
      hw_dump_stream "$cache_file" "$dump_path"
      return 0
    fi
  fi

  if [ "${HWGREP_CACHE_OFFLINE:-0}" -eq 1 ]; then
    echo "hwgrep: offline mode and cache miss for $url" >&2
    return 1
  fi

  hw_logv "fetching URL: $url"

  local tmp
  tmp="$(mktemp "${HWGREP_CACHE_DIR}/hwgrep.XXXXXX")"

  if ! curl -sL --compressed \
      -A 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.7444.175 Safari/537.36' \
      "$url" >"$tmp"; then
    hw_logv "network fetch failed for $url"

    if [ "${HWGREP_CACHE_DISABLE:-0}" -eq 0 ] && [ -f "$cache_file" ]; then
      hw_logv "using stale cache for $url"
      rm -f "$tmp"
      hw_dump_stream "$cache_file" "$dump_path"
      return 0
    fi

    rm -f "$tmp"
    return 1
  fi

  if [ "${HWGREP_CACHE_DISABLE:-0}" -eq 0 ]; then
    hw_cache_put "$url" "$tmp"
    hw_dump_stream "$cache_file" "$dump_path"
  else
    hw_dump_stream "$tmp" "$dump_path"
    rm -f "$tmp"
  fi
}

hw_html_to_text() {
  awk -f "${LIB_DIR}/shared/hw_html_text.awk"
}

hw_color_logs() {
  if [ -n "${NO_COLOR:-}" ]; then
    cat
    return 0
  fi
  awk -f "${LIB_DIR}/shared/hw_color_logs.awk"
}

hw_fetch_type_page() {
  local type="$1"
  local id="$2"
  local page="${3:-1}"
  local want_page_suffix="${4:-0}"

  local url=""
  local dump_id="$id"

  case "$type" in
    probe)
      url="${HWGREP_BASE_URL}/?probe=${id}"
      ;;
    device)
      local dev_query="$id"
      case "$dev_query" in
        *:*) ;;
        *) dev_query="pci:${dev_query}" ;;
      esac

      local encoded="${dev_query//:/%3A}"
      url="${HWGREP_BASE_URL}/?id=${encoded}"
      dump_id="$encoded"
      ;;
    computer)
      url="${HWGREP_BASE_URL}/?computer=${id}"
      ;;
    *)
      echo "hw_fetch_type_page: invalid type: $type" >&2
      return 1
      ;;
  esac

  if [ "${page:-1}" -gt 1 ]; then
    url="${url}&page=${page}"
  fi

  if [ "${want_page_suffix:-0}" -eq 1 ]; then
    dump_id="${dump_id}.p${page}"
  fi

  hw_fetch_page "$url" "$(hw_dump_html_file "$type" "$dump_id")"
}

hw_probe_html() {
  local probe_id="$1"
  hw_fetch_type_page probe "$probe_id" 1 0
}

hw_probe_text() {
  local probe_id="$1"
  hw_probe_html "$probe_id" | hw_html_to_text
}

hw_device_html() {
  local dev_id="$1"
  hw_fetch_type_page device "$dev_id" 1 0
}

hw_device_text() {
  local dev_id="$1"
  hw_device_html "$dev_id" | hw_html_to_text
}

hw_computer_html() {
  local computer_id="$1"
  hw_fetch_type_page computer "$computer_id" 1 0
}

hw_device_html_page() {
  local dev_id="$1"
  local page="${2:-1}"
  hw_fetch_type_page device "$dev_id" "$page" 1
}

hw_probe_html_page() {
  local probe_id="$1"
  local page="${2:-1}"
  hw_fetch_type_page probe "$probe_id" "$page" 1
}
