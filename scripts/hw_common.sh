#!/usr/bin/env bash
set -euo pipefail

HWGREP_BASE_URL="${HWGREP_BASE_URL:-https://linux-hardware.org}"
DEBUG_HTML="${DEBUG_HTML:-0}"
VERBOSE="${VERBOSE:-0}"

hw_logv() {
  if [ "${VERBOSE:-0}" -eq 1 ]; then
    printf '[hw_common] %s\n' "$*" >&2
  fi
}

hw_fetch_page() {
  local url="$1"
  local dbg="${2:-}"

  hw_logv "Fetching URL: $url"
  if [ "$DEBUG_HTML" -eq 1 ] && [ -n "$dbg" ]; then
    curl -sL --compressed \
      -A 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.7444.175 Safari/537.36' \
      "$url" | tee "$dbg"
  else
    curl -sL --compressed \
      -A 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.7444.175 Safari/537.36' \
      "$url"
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
  [ "$DEBUG_HTML" -eq 1 ] && dbg="/tmp/hwgrep.probe.${probe_id}.html"

  hw_fetch_page "$probe_url" "$dbg" \
    | hw_html_to_text
}
