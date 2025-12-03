#!/usr/bin/env bash
set -euo pipefail

HWGREP_BASE_URL="https://linux-hardware.org"
FILTER_URL=""
TYPE=""
VENDOR=""
MODEL_LIKE=""
YEAR=""
LOG_NAME=""
GREP_PATTERN=""
SLEEP_SEC=1
MAX_PROBES=0
MAX_COMPUTERS=5
VERBOSE=0
DRY_RUN=0
HOST_INFO=0
LIST_DEVICES=0
DEBUG_HTML=0
AVAILABLE_LOGS=0
LOG_EXPLICIT=0
SKIP_LOGS=0

usage() {
  cat <<EOF
Usage:
  $(basename "$0") [options]

Filters:
  --type TYPE           Computer type e.g notebook, desktop, server, etc
  --vendor VENDOR       Vendor name, e.g. Lenovo
  --model-like STR      Model substring, e.g. "ThinkPad E14 Gen 7"
  --year YEAR           Mfg. year filter e.g. --year 2025 or --year all
                        Default: current year from "date +%Y"

  --filter-url URL      Full ?view=computers, ?computer= or ?probe= URL. If this
                        is set, --type/--vendor/--model-like/--year are ignored.

Logs:
  --log NAME            Log to fetch (default: dmesg unless host/devices-only)
  --grep REGEX          Case-insensitive regex to filter log lines
  --sleep SECONDS       Pause between probe log fetches (default: 1)
  --max-probes N        Stop after N probes (0 = unlimited)
  --max-computers N     Stop after N computers (0 = unlimited, default: 5)
  --available-logs      List available logs

Other:
  --dry-run             Only list computer IDs and probe IDs
  --host-info           Show Host summary
  --list-devices        Show Devices table
  --verbose             Extra debug output to stderr
  --debug-html          Save HTML to /tmp/hwgrep.*.html for inspection
  -h, --help            Show this help
EOF
}

logv() {
  if [ "$VERBOSE" -eq 1 ]; then
    printf '[hwgrep] %s\n' "$*" >&2
  fi
}

encode_spaces_as_plus() {
  printf '%s\n' "$1" | sed 's/ /+/g'
}

fetch_page() {
  local url="$1"
  local dbg="${2:-}"

  logv "Fetching URL: $url"
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

print_probe_info() {
  local probe_id="$1"
  local probe_url="${HWGREP_BASE_URL}/?probe=${probe_id}"
  local probe_dbg=""
  [ "$DEBUG_HTML" -eq 1 ] && probe_dbg="/tmp/hwgrep.probe.${probe_id}.html"

  local text
  text="$(
    fetch_page "$probe_url" "$probe_dbg" \
      | sed '/<script/,/<\/script>/d; /<style/,/<\/style>/d' \
      | sed -E 's/<[Bb][Rr][[:space:]]*\/?>/\n/g' \
      | sed 's/&nbsp;/ /g' \
      | sed -E 's/&[A-Za-z0-9#]+;//g' \
      | sed 's/<[^>]*>//g' \
      | sed '/^[[:space:]]*$/d'
  )"

  local host_block
  host_block="$(
    printf '%s\n' "$text" \
      | awk '
          $0 ~ /^Host[[:space:]]*$/ {inhost=1; next}
          inhost && $0 ~ /^Devices[[:space:]]*\(/ {exit}
          inhost
        '
  )"

  if [ "$HOST_INFO" -eq 1 ]; then
    echo "  Host summary:"
    printf '%s\n' "$host_block" \
      | awk '
          BEGIN { cur = "" }
          {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
            if ($0 == "" || $0 == "Host" || $0 == "Devices" || $0 == "Logs") next

            if ($0 ~ /^(System|Arch|Kernel|Vendor|Model|Year|HWid|Type|DE)$/) {
              cur = $0
              if (!(cur in seen)) {
                order[++n] = cur
                seen[cur] = 1
              }
              next
            }

            if (cur != "") {
              if (val[cur] != "") {
                val[cur] = val[cur] " " $0
              } else {
                val[cur] = $0
              }
            }
          }
          END {
            for (i = 1; i <= n; i++) {
              k = order[i]
              if (val[k] != "") {
                printf("    %-7s : %s\n", k, val[k])
              }
            }
          }
        '
    echo
  fi

  if [ "$LIST_DEVICES" -eq 1 ]; then
    local devices_block
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
              # Clear the previous buffer contents
              for (i in out) {
                  delete out[i]
              }

              # Now fill fresh wrapped segments
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

          # Skip noise
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

            # Start new row when a new BUS type appears
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
  fi
}

print_available_logs() {
  local probe_id="$1"
  local logs_url="${HWGREP_BASE_URL}/?probe=${probe_id}"

  logv "Fetching available logs list from: ${logs_url}"
  echo "  Available logs for probe ${probe_id}:"

  fetch_page "$logs_url" "" \
    | awk '
        /<a name='\''Logs'\''>/ {inlogs=1; next}
        !inlogs {next}

        /<span class='\''category'\''>/ {
          if (match($0, /<span class='\''category'\''>([^<]+)<\/span>/, m)) {
            category = m[1]
            cat_order[++cat_count] = category
          }
          next
        }

        /class='\''pointer'\''/ && /log=/ {
          logname=""
          label=""

          if (match($0, /log=([^'\''&]+)['\''&]/, m)) {
            logname = m[1]
          }
          if (match($0, />[^<]+<\/a>/, m2)) {
            label = m2[0]
            sub(/^>/, "", label)
            sub(/<\/a>$/, "", label)
          } else {
            label = logname
          }

          if (category != "" && logname != "") {
            logs[category][++count[category]] = label
          }
          next
        }

        END {
          for (i = 1; i <= cat_count; i++) {
            c = cat_order[i]
            print "[" c "]"
            for (j = 1; j <= count[c]; j++) {
              printf("    %s\n", logs[c][j])
            }
            print ""
          }
        }
      '

  echo
}

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --type)
      TYPE="${2:-}"
      shift 2
      ;;
    --vendor)
      VENDOR="${2:-}"
      shift 2
      ;;
    --model-like)
      MODEL_LIKE="${2:-}"
      shift 2
      ;;
    --year)
      YEAR="${2:-}"
      shift 2
      ;;
    --log)
      LOG_NAME="${2:-}"
      LOG_EXPLICIT=1
      shift 2
      ;;
    --grep)
      GREP_PATTERN="${2:-}"
      shift 2
      ;;
    --filter-url)
      FILTER_URL="${2:-}"
      shift 2
      ;;
    --sleep)
      SLEEP_SEC="${2:-}"
      shift 2
      ;;
    --max-probes)
      MAX_PROBES="${2:-}"
      shift 2
      ;;
    --max-computers)
      MAX_COMPUTERS="${2:-}"
      shift 2
      ;;
    --available-logs)
      AVAILABLE_LOGS=1
      shift
      ;;
    --host-info)
      HOST_INFO=1
      shift
      ;;
    --list-devices|--devices-info)
      LIST_DEVICES=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    --debug-html)
      DEBUG_HTML=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ "$HOST_INFO" -eq 1 ] || [ "$LIST_DEVICES" -eq 1 ]; then
  if [ "$AVAILABLE_LOGS" -eq 0 ] && [ "$LOG_EXPLICIT" -eq 0 ] && [ -z "$GREP_PATTERN" ]; then
    SKIP_LOGS=1
  fi
fi

if [ -z "$LOG_NAME" ] && [ "$SKIP_LOGS" -eq 0 ]; then
  LOG_NAME="dmesg"
fi

if [ -n "$FILTER_URL" ] && printf '%s\n' "$FILTER_URL" | grep -q 'probe='; then
  PROBE_ID="$(
    printf '%s\n' "$FILTER_URL" \
      | sed -n 's/.*probe=\([0-9A-Fa-f]\{8,16\}\).*/\1/p' \
      | tr 'A-F' 'a-f' \
      | head -n 1
  )"

  if [ -z "$PROBE_ID" ]; then
    echo "Error: could not extract probe ID from --filter-url" >&2
    exit 1
  fi

  echo "*******************************"
  echo "Probe: ${PROBE_ID}"
  echo "URL:   ${HWGREP_BASE_URL}/?probe=${PROBE_ID}"
  echo "*******************************"

  if [ "$DRY_RUN" -eq 1 ]; then
    exit 0
  fi

  if [ "$HOST_INFO" -eq 1 ] || [ "$LIST_DEVICES" -eq 1 ]; then
    print_probe_info "$PROBE_ID"
  fi

  if [ "$AVAILABLE_LOGS" -eq 1 ]; then
    print_available_logs "$PROBE_ID"
    exit 0
  fi

  if [ "$SKIP_LOGS" -eq 1 ] || [ -z "$LOG_NAME" ]; then
    exit 0
  fi

  log_url="${HWGREP_BASE_URL}/?log=${LOG_NAME}&probe=${PROBE_ID}"
  logv "Fetching log: ${log_url}"

  if [ -n "$GREP_PATTERN" ]; then
    fetch_page "$log_url" "" \
      | sed '/<script/,/<\/script>/d; /<style/,/<\/style>/d' \
      | sed -E 's/<[Bb][Rr][[:space:]]*\/?>/\n/g' \
      | sed 's/&nbsp;/ /g' \
      | sed -E 's/&[A-Za-z0-9#]+;//g' \
      | sed 's/<[^>]*>//g' \
      | sed '/^[[:space:]]*$/d' \
      | grep -Ei "$GREP_PATTERN" || echo "  no matches"
  else
    fetch_page "$log_url" "" \
      | sed '/<script/,/<\/script>/d; /<style/,/<\/style>/d' \
      | sed -E 's/<[Bb][Rr][[:space:]]*\/?>/\n/g' \
      | sed 's/&nbsp;/ /g' \
      | sed -E 's/&[A-Za-z0-9#]+;//g' \
      | sed 's/<[^>]*>//g' \
      | sed '/^[[:space:]]*$/d'
  fi

  echo
  exit 0
fi

if [ -z "$FILTER_URL" ]; then
  if [ -z "$TYPE" ] || [ -z "$VENDOR" ] || [ -z "$MODEL_LIKE" ]; then
    echo "Error: either --filter-url OR all of --type/--vendor/--model-like are required" >&2
    exit 1
  fi

  if [ -z "$YEAR" ]; then
    YEAR="$(date +%Y)"
  fi

  enc_type=$(encode_spaces_as_plus "$TYPE")
  enc_vendor=$(encode_spaces_as_plus "$VENDOR")
  enc_model_like=$(encode_spaces_as_plus "$MODEL_LIKE")

  FILTER_URL="${HWGREP_BASE_URL}/?view=computers&type=${enc_type}&vendor=${enc_vendor}&model_like=${enc_model_like}"

  if [ "$YEAR" != "all" ] && [ "$YEAR" != "ALL" ]; then
    enc_year=$(printf '%s\n' "$YEAR" | sed 's/[^0-9]//g')
    [ -n "$enc_year" ] || enc_year="$YEAR"
    FILTER_URL="${FILTER_URL}&year=${enc_year}"
  fi
fi

logv "FILTER_URL = $FILTER_URL"
echo "Using computers URL:"
echo "  $FILTER_URL"
echo

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry-run mode: will list computer IDs and probe IDs only"
fi

computers_html_dbg=""
[ "$DEBUG_HTML" -eq 1 ] && computers_html_dbg="/tmp/hwgrep.computers.html"

COMPUTER_IDS=$(
  fetch_page "$FILTER_URL" "$computers_html_dbg" \
    | sed -n 's/.*computer=\([0-9A-Fa-f]\{8,16\}\).*/\1/p' \
    | tr 'A-F' 'a-f' \
    | sort -u
)

if [ -z "$COMPUTER_IDS" ]; then
  echo "No computer IDs found" >&2
  if [ "$DEBUG_HTML" -eq 1 ] && [ -n "$computers_html_dbg" ]; then
    echo "Saved HTML to $computers_html_dbg for inspection" >&2
  fi
  exit 1
fi

if [ "$MAX_COMPUTERS" -gt 0 ]; then
  COMPUTER_IDS=$(printf '%s\n' "$COMPUTER_IDS" | head -n "$MAX_COMPUTERS")
fi

echo "Found computers, showing up to $MAX_COMPUTERS:"
echo "$COMPUTER_IDS" | sed 's/^/  computer=/'
echo

probe_count=0

echo "$COMPUTER_IDS" | while read -r COMPUTER_ID; do
  [ -n "$COMPUTER_ID" ] || continue

  comp_url="${HWGREP_BASE_URL}/?computer=${COMPUTER_ID}"
  echo "*******************************"
  echo "Computer ID: ${COMPUTER_ID}"
  echo "URL:        ${comp_url}"
  echo "*******************************"

  comp_html_dbg=""
  [ "$DEBUG_HTML" -eq 1 ] && comp_html_dbg="/tmp/hwgrep.computer.${COMPUTER_ID}.html"

  PROBE_IDS=$(
    fetch_page "$comp_url" "$comp_html_dbg" \
      | sed -n 's/.*probe=\([0-9A-Fa-f]\{8,16\}\).*/\1/p' \
      | tr 'A-F' 'a-f' \
      | sort -u
  )

  if [ -z "$PROBE_IDS" ]; then
    echo "  No probes found for this computer"
    echo
    continue
  fi

  echo "  Probes:"
  echo "$PROBE_IDS" | sed 's/^/    /'
  echo

  echo "$PROBE_IDS" | while read -r PROBE_ID; do
    [ -n "$PROBE_ID" ] || continue

    probe_count=$((probe_count + 1))
    if [ "$MAX_PROBES" -gt 0 ] && [ "$probe_count" -gt "$MAX_PROBES" ]; then
      echo "Probe limit reached (MAX_PROBES = ${MAX_PROBES}). Stopping."
      exit 0
    fi

    echo "Probe: ${PROBE_ID}"

    if [ "$DRY_RUN" -eq 1 ] || [ "$SKIP_LOGS" -eq 1 ] && [ "$HOST_INFO" -eq 0 ] && [ "$LIST_DEVICES" -eq 0 ]; then
      echo
      continue
    fi

    if [ "$HOST_INFO" -eq 1 ] || [ "$LIST_DEVICES" -eq 1 ]; then
      print_probe_info "$PROBE_ID"
    fi

    if [ "$AVAILABLE_LOGS" -eq 1 ]; then
      print_available_logs "$PROBE_ID"
      continue
    fi

    if [ "$SKIP_LOGS" -eq 1 ] || [ -z "$LOG_NAME" ]; then
      echo
      continue
    fi

    log_url="${HWGREP_BASE_URL}/?log=${LOG_NAME}&probe=${PROBE_ID}"
    logv "Fetching log: ${log_url}"

    if [ -n "$GREP_PATTERN" ]; then
      fetch_page "$log_url" "" \
        | sed '/<script/,/<\/script>/d; /<style/,/<\/style>/d' \
        | sed -E 's/<[Bb][Rr][[:space:]]*\/?>/\n/g' \
        | sed 's/&nbsp;/ /g' \
        | sed -E 's/&[A-Za-z0-9#]+;//g' \
        | sed 's/<[^>]*>//g' \
        | sed '/^[[:space:]]*$/d' \
        | grep -Ei "$GREP_PATTERN" || echo "  no matches"
    else
      fetch_page "$log_url" "" \
        | sed '/<script/,/<\/script>/d; /<style/,/<\/style>/d' \
        | sed -E 's/<[Bb][Rr][[:space:]]*\/?>/\n/g' \
        | sed 's/&nbsp;/ /g' \
        | sed -E 's/&[A-Za-z0-9#]+;//g' \
        | sed 's/<[^>]*>//g' \
        | sed '/^[[:space:]]*$/d'
    fi

    echo
    sleep "$SLEEP_SEC"
  done

  echo
done
