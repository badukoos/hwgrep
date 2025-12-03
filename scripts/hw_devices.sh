#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/hw_common.sh"

PROBE_ID=""

while [ $# -gt 0 ]; do
  case "$1" in
    --probe)
      PROBE_ID="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") --probe PROBE_ID"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

[ -n "$PROBE_ID" ] || { echo "Error: --probe required" >&2; exit 1; }

text="$(hw_probe_text "$PROBE_ID")"

devices_block="$(
  printf '%s\n' "$text" \
    | awk '
        $0 ~ /^Devices[[:space:]]*\(/ {indev=1; next}
        indev && /^Logs/ {exit}
        indev && /^Issues/ {exit}
        indev && /^Computer/ {exit}
        indev
      '
)"

echo "  Devices:"
printf "    %-5s %-26s %-24s %-38s %-16s %-16s %s\n" \
  "BUS" "ID/Class" "Vendor" "Device" "Type" "Driver" "Status"
printf "    %-5s %-26s %-24s %-38s %-16s %-16s %s\n" \
  "-----" "--------------------------" "------------------------" \
  "--------------------------------------" "----------------" "----------------" "------"

printf '%s\n' "$devices_block" \
  | awk -v w_bus=5 -v w_id=26 -v w_vendor=24 -v w_dev=38 -v w_type=16 -v w_drv=16 -v w_status=10 '
      function trim(s) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
        return s
      }
      function wrap(str, width, out, i, n) {
          for (i in out) {
              delete out[i]
          }
          n = int((length(str)+width-1)/width)
          for (i=1; i<=n; i++) {
              out[i] = substr(str, ((i-1)*width)+1, width)
          }
          return n
      }
      function flush_row() {
        if (bus == "") return
        n_bus = wrap(bus, w_bus, bus_w)
        n_id  = wrap(idclass, w_id, id_w)
        n_vend= wrap(vendor, w_vendor, vend_w)
        n_dev = wrap(device, w_dev, dev_w)
        n_type= wrap(type, w_type, type_w)
        n_drv = wrap(driver, w_drv, drv_w)
        n_stat= wrap(status, w_status, stat_w)
        n_lines = n_bus
        if (n_id  > n_lines) n_lines = n_id
        if (n_vend> n_lines) n_lines = n_vend
        if (n_dev > n_lines) n_lines = n_dev
        if (n_type> n_lines) n_lines = n_type
        if (n_drv > n_lines) n_lines = n_drv
        if (n_stat> n_lines) n_lines = n_stat
        for (i=1; i<=n_lines; i++) {
          printf("    %-*s %-*s %-*s %-*s %-*s %-*s %-*s\n",
           w_bus,  bus_w[i],
           w_id,   id_w[i],
           w_vendor, vend_w[i],
           w_dev,  dev_w[i],
           w_type, type_w[i],
           w_drv,  drv_w[i],
           w_status, stat_w[i])
        }
        bus = idclass = vendor = device = type = driver = status = ""
      }
      BEGIN {
        bus = idclass = vendor = device = type = driver = status = ""
      }
      /^Devices/ { next }
      /^BUS$/ { next }
      /^ID/ { next }
      /^Vendor$/ { next }
      /^Device$/ { next }
      /^Type$/ { next }
      /^Driver$/ { next }
      /^Status$/ { next }
      /^Logs/ { next }
      /^[0-9]+x$/ { next }
      {
        line = trim($0)
        if (line == "") next
        if (bus != "" && line ~ /^(PCI|USB|EISA|SYS|PS\/2|NVME|SERIAL)$/) {
          flush_row()
        }
        if (bus == "") {
          bus = line
          next
        }
        if (idclass == "") {
          idclass = line
          next
        }
        if (substr(line,1,2) == "/ " && vendor == "") {
          idclass = idclass " " line
          next
        }
        if (vendor == "") {
          vendor = line
          next
        }
        if (device == "") {
          device = line
          next
        }
        if (type == "") {
          type = line
          next
        }
        if (driver == "") {
          driver = line
          next
        }
        if (status == "") {
          status = line
          flush_row()
          next
        }
      }
      END {
        flush_row()
      }
    '
echo
