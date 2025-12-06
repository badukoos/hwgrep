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

hw_cache_init() {
  mkdir -p "${HW_CACHE_DIR}"
}

hw_cache_key_for_url() {
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
  cache_file="$(hw_cache_key_for_url "$url")"

  mkdir -p "$(dirname "$cache_file")"
  mv "$tmp_file" "$cache_file"
  hw_logv "cache store: $url -> $cache_file"
}

hw_fetch_page() {
  local url="$1"
  local dbg="${2:-}"

  hw_cache_init

  local cache_file
  cache_file="$(hw_cache_key_for_url "$url")"

  if [ "${HW_CACHE_DISABLE:-0}" -eq 0 ] && [ "${HW_CACHE_REFRESH:-0}" -eq 0 ]; then
    if [ -f "$cache_file" ]; then
      hw_logv "cache hit: $url -> $cache_file"
      if [ "$DEBUG_HTML" -eq 1 ] && [ -n "$dbg" ]; then
        tee "$dbg" <"$cache_file"
      else
        cat "$cache_file"
      fi
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
      if [ "$DEBUG_HTML" -eq 1 ] && [ -n "$dbg" ]; then
        tee "$dbg" <"$cache_file"
      else
        cat "$cache_file"
      fi
      rm -f "$tmp"
      return 0
    fi

    rm -f "$tmp"
    return 1
  fi

  if [ "${HW_CACHE_DISABLE:-0}" -eq 0 ]; then
    hw_cache_put "$url" "$tmp"
    if [ "$DEBUG_HTML" -eq 1 ] && [ -n "$dbg" ]; then
      tee "$dbg" <"$cache_file"
    else
      cat "$cache_file"
    fi
  else
    if [ "$DEBUG_HTML" -eq 1 ] && [ -n "$dbg" ]; then
      tee "$dbg" <"$tmp"
    else
      cat "$tmp"
    fi
    rm -f "$tmp"
  fi
}

hw_html_to_text() {
  sed '/<script/,/<\/script>/d; /<style/,/<\/style>/d' \
  | sed -E 's/<[Bb][Rr][[:space:]]*\/?>/\n/g' \
  | sed 's/&nbsp;/ /g' \
  | sed -E 's/&[A-Za-z0-9#]+;//g' \
  | sed 's/<[^>]*>//g' \
  | sed '/^[[:space:]]*$/d'
}

hw_probe_text() {
  local probe_id="$1"
  local probe_url="${HWGREP_BASE_URL}/?probe=${probe_id}"
  local dbg=""
  if [ "$DEBUG_HTML" -eq 1 ]; then
    dbg="/tmp/hwgrep.probe.${probe_id}.html"
  fi

  hw_fetch_page "$probe_url" "$dbg" \
    | hw_html_to_text
}

hw_probe_system() {
  local probe_id="${1:-}"

  if [ -z "$probe_id" ]; then
    printf 'hw_probe_system: missing probe_id\n' >&2
    return 1
  fi

  hw_probe_text "$probe_id" \
    | awk '
        $0 ~ /^Host[[:space:]]*$/ { inhost = 1; next }
        inhost && $0 ~ /^Devices[[:space:]]*\(/ { exit }
        inhost {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
          if ($0 == "" || $0 == "Host" || $0 == "Devices" || $0 == "Logs") next
          if ($0 ~ /^System$/) {
            if (getline) {
              gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
              print $0
            }
            exit
          }
        }
      '
}
