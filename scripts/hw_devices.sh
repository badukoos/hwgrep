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
      cat <<EOF
Usage: $(basename "$0") --probe PROBE_ID
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "${PROBE_ID:-}" ]; then
  echo "Error: --probe PROBE_ID is required" >&2
  exit 1
fi

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  COLOR_FLAG=1
else
  COLOR_FLAG=0
fi

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
printf "    %-4s %-26s %-22s %-30s %-10s %-12s %-8s %-30s\n" \
  "BUS" "ID/Class" "Vendor" "Device" "Type" "Driver" "Status" "Notes"
printf "    %-4s %-26s %-22s %-30s %-10s %-12s %-8s %-30s\n" \
  "----" "------------------------" "----------------------" \
  "------------------------------" "--------" "------------" \
  "------" "----------------------------"

printf '%s\n' "$devices_block" \
  | awk -v w_bus=4 -v w_id=26 -v w_vendor=22 -v w_dev=30 \
        -v w_type=10 -v w_drv=12 -v w_status=8 -v w_notes=30 \
        -v enable_color="$COLOR_FLAG" '
      function trim(s) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
        return s
      }
      function wrap(str, width, out, i, n) {
        for (i in out) delete out[i]
        if (str == "") { out[1] = ""; return 1 }
        n = int((length(str) + width - 1) / width)
        for (i = 1; i <= n; i++) {
          out[i] = substr(str, (i - 1) * width + 1, width)
        }
        return n
      }
      function join_range(arr, s, e, res, i) {
        res = ""
        for (i = s; i <= e; i++) {
          if (res == "")
            res = arr[i]
          else
            res = res " " arr[i]
        }
        return res
      }
      function emit_row(bus, id, i, start_vd,
                        idx_status, idx_drv, idx_type, idx_notes_start,
                        vendor, device, type, driver, status, notes,
                        first_vd, vd_end, vd_count,
                        bus_w, id_w, vend_w, dev_w, type_w, drv_w, stat_w, notes_w,
                        nb, ni, nv, nd, nt, ndv, ns, nn, n_lines,
                        color_start, color_end) {
        if (row_n == 0) return
        bus = row[1]
        id = row[2]
        i = 3
        while (i <= row_n && row[i] ~ /^\/ /) {
          id = id " " row[i]
          i++
        }
        start_vd = i
        idx_status = 0
        for (i = row_n; i >= start_vd; i--) {
          if (row[i] ~ /^(works|detected|malfunc|failed|disabled|unknown|n\/a)$/) {
            idx_status = i
            break
          }
        }
        if (!idx_status) {
          idx_status = row_n
        }
        idx_drv  = idx_status - 1
        idx_type = idx_status - 2
        if (idx_type < start_vd) {
          idx_type = start_vd
          idx_drv  = start_vd
        }

        type   = (idx_type >= start_vd && idx_type <= row_n) ? row[idx_type] : ""
        driver = (idx_drv  >  idx_type && idx_drv  <= row_n) ? row[idx_drv]  : ""
        status = row[idx_status]

        idx_notes_start = idx_status + 1
        if (idx_notes_start <= row_n) {
          notes = join_range(row, idx_notes_start, row_n)
        } else {
          notes = ""
        }

        first_vd = start_vd
        vd_end   = idx_type - 1
        vd_count = vd_end - first_vd + 1

        vendor = ""
        device = ""
        if (vd_count == 1) {
          device = row[first_vd]
        } else if (vd_count >= 2) {
          vendor = row[first_vd]
          if (vd_count > 1) {
            device = join_range(row, first_vd + 1, vd_end)
          }
        }

        color_start = ""
        color_end   = ""
        if (enable_color == 1) {
          if (status == "works") {
            color_start = "\033[32m"
          } else if (status == "malfunc") {
            color_start = "\033[33m"
          } else if (status == "failed") {
            color_start = "\033[31m"
          }
          if (color_start != "") {
            color_end = "\033[0m"
          }
        }

        nb  = wrap(bus,    w_bus,    bus_w)
        ni  = wrap(id,     w_id,     id_w)
        nv  = wrap(vendor, w_vendor, vend_w)
        nd  = wrap(device, w_dev,    dev_w)
        nt  = wrap(type,   w_type,   type_w)
        ndv = wrap(driver, w_drv,    drv_w)
        ns  = wrap(status, w_status, stat_w)
        nn  = wrap(notes,  w_notes,  notes_w)

        n_lines = nb
        if (ni  > n_lines) n_lines = ni
        if (nv  > n_lines) n_lines = nv
        if (nd  > n_lines) n_lines = nd
        if (nt  > n_lines) n_lines = nt
        if (ndv > n_lines) n_lines = ndv
        if (ns  > n_lines) n_lines = ns
        if (nn  > n_lines) n_lines = nn

        for (i = 1; i <= n_lines; i++) {
          printf("%s    %-*s %-*s %-*s %-*s %-*s %-*s %-*s %-*s%s\n",
                 color_start,
                 w_bus,    bus_w[i],
                 w_id,     id_w[i],
                 w_vendor, vend_w[i],
                 w_dev,    dev_w[i],
                 w_type,   type_w[i],
                 w_drv,    drv_w[i],
                 w_status, stat_w[i],
                 w_notes,  notes_w[i],
                 color_end)
        }

        for (i in row) delete row[i]
        row_n = 0
      }

      BEGIN {
        row_n = 0
        seen_bus = 0
      }

      {
        line = trim($0)
        if (line == "") next

        if (line == "BUS"    || line == "ID"      || line == "Vendor" ||
            line == "Device" || line == "Type"   || line == "Driver" ||
            line == "Status") next
        if (line ~ /^-+$/) next

        if (line ~ /^(PCI|USB|SYS|PS\/2|NVME|SATA|I2C|LPC|SERIAL|VIRTIO)$/) {
          if (seen_bus && row_n > 0) emit_row()
          row_n = 0
          row[++row_n] = line
          seen_bus = 1
          next
        }

        if (!seen_bus) next
        row[++row_n] = line
      }

      END {
        if (seen_bus && row_n > 0) emit_row()
      }
    '
echo
