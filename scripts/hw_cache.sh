#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/hw_common.sh"

cmd="${1:-}"

case "$cmd" in
  ls)
    echo "Cache dir: $HW_CACHE_DIR"
    find "$HW_CACHE_DIR" -type f 2>/dev/null || true
    ;;

  clear)
    echo "Clearing cache at $HW_CACHE_DIR"
    rm -rf "$HW_CACHE_DIR"
    mkdir -p "$HW_CACHE_DIR"
    ;;

  path)
    probe="${2:-}"
    if [ -z "$probe" ]; then
      echo "Usage: $0 path <probe-id>" >&2
      exit 1
    fi
    url="${HWGREP_BASE_URL}/?probe=${probe}"
    hw_cache_key_for_url "$url"
    ;;

  prime)
    shift
    if [ "$#" -eq 0 ]; then
      echo "Usage: $0 prime <probe-id> [probe-id...]" >&2
      exit 1
    fi
    for probe in "$@"; do
      url="${HWGREP_BASE_URL}/?probe=${probe}"
      echo "Priming cache for probe ${probe} (${url})"
      HW_CACHE_REFRESH=1 hw_fetch_page "$url" >/dev/null
    done
    ;;

  stats)
    echo "Cache dir: $HW_CACHE_DIR"
    files=$(find "$HW_CACHE_DIR" -type f 2>/dev/null | wc -l || echo 0)
    echo "Files: $files"
    if [ -d "$HW_CACHE_DIR" ]; then
      size=$(du -sh "$HW_CACHE_DIR" 2>/dev/null | awk '{print $1}')
      echo "Size:  $size"
    fi
    ;;

  *)
    cat <<EOF
Usage: $0 <command>

Commands:
  ls            List cached pages
  clear         Delete all cache
  path ID       Show cache file path for a probe ID
  prime IDs     Refresh cache for probes
  stats         Show cache stats
EOF
    ;;
esac
