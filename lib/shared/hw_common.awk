BEGIN {
  SEP = "\034"

  CP_W_ID   = 10
  CP_W_SRC  = 8
  CP_W_SYS  = 12
  CP_W_DATE = 14

  DEV_W_BUS    = 4
  DEV_W_ID     = 26
  DEV_W_VENDOR = 22
  DEV_W_DEV    = 30
  DEV_W_TYPE   = 10
  DEV_W_DRV    = 12
  DEV_W_STATUS = 8
  DEV_W_NOTES  = 30

  KD_W_VER = 18
  KD_W_SRC = 40
  KD_W_CFG = 30
  KD_W_ID  = 16
  KD_W_CLS = 10

  ST_W_HWID   = 12
  ST_W_TYPE   = 10
  ST_W_VM     = 30
  ST_W_PROBES = 7
  ST_W_SYS    = 14
  ST_W_STATUS = 10
  ST_W_NOTES  = 30

}

function trim(s) {
  gsub(/^[ \t]+|[ \t]+$/, "", s)
  return s
}

function clean_ws(s) {
  gsub(/\r/, " ", s)
  gsub(/\n/, " ", s)
  gsub(/\t/, " ", s)
  s = trim(s)
  gsub(/[[:space:]]+/, " ", s)
  return s
}

function is_none(s, t) {
  t = tolower(trim(s))
  return (t == "" || t == "<none>" || t == "none")
}

function clean_inline(s) {
  gsub(/<br[[:space:]]*\/?>/, " ", s)
  gsub(/<[^>]*>/, "", s)
  gsub(/&nbsp;/, " ", s)
  gsub(/&[^;]+;/, "", s)
  gsub(/[[:space:]]+/, " ", s)
  return trim(s)
}

function clean_cell(raw, v, span, title) {
  v = raw

  while (match(v, /<span[^>]*title=["\047][^"\047]*["\047][^>]*>[^<]*<\/span>/)) {
    span = substr(v, RSTART, RLENGTH)

    title = span
    sub(/.*title=["\047]/, "", title)
    sub(/["\047].*$/, "", title)

    v = substr(v, 1, RSTART - 1) " " title " " substr(v, RSTART + RLENGTH)
  }

  gsub(/<br[[:space:]]*\/?>/, " ", v)
  gsub(/<[^>]*>/, "", v)
  gsub(/&nbsp;/, " ", v)
  gsub(/&[^;]+;/, "", v)
  gsub(/[[:space:]]+/, " ", v)

  return trim(v)
}

function extract_cells(row, cells,
                       start, pos, open, gt_rel, gt,
                       c_start, tmp, clos_rel, c_end,
                       raw, n) {
  start = 1
  n = 0

  while (1) {
    pos = index(substr(row, start), "<td")
    if (pos == 0) break

    open = start + pos - 1
    gt_rel = index(substr(row, open), ">")
    if (gt_rel == 0) break

    gt = open + gt_rel - 1
    c_start = gt + 1

    tmp = substr(row, c_start)
    clos_rel = index(tmp, "</td>")
    if (clos_rel == 0) break

    c_end = c_start + clos_rel - 2
    raw = substr(row, c_start, c_end - c_start + 1)

    n++
    cells[n] = clean_cell(raw)

    start = c_end + 5
  }

  return n
}

function wrap(str, width, out,
              i, n, words, w, wlen,
              line, len, idx) {

  for (i in out) delete out[i]

  str = trim(str)
  if (str == "") {
    out[1] = ""
    return 1
  }

  n = split(str, words, /[[:space:]]+/)
  line = ""
  len = 0
  idx = 1

  for (i = 1; i <= n; i++) {
    w = words[i]
    wlen = length(w)

    if (len == 0) {
      if (wlen <= width) {
        line = w
        len = wlen
      } else {
        while (wlen > width) {
          out[idx++] = substr(w, 1, width)
          w    = substr(w, width + 1)
          wlen = length(w)
        }
        if (wlen > 0) {
          line = w
          len = wlen
        }
      }
    } else {
      if (len + 1 + wlen <= width) {
        line = line " " w
        len  = len + 1 + wlen
      } else {
        out[idx++] = line
        line = ""
        len = 0
        i--
      }
    }
  }

  if (len > 0)
    out[idx++] = line

  return idx - 1
}

function pick_color(status, enable_color, color_start) {
  if (enable_color != 1) return ""

  if (status == "failed") color_start = "\033[31m"
  else if (status == "works") color_start = "\033[32m"
  else if (status == "malfunc") color_start = "\033[33m"
  else if (status == "fixed") color_start = "\033[36m"
  else if (status == "limited") color_start = "\033[38;2;110;95;29m"
  else color_start = ""

  return color_start
}

function clean_field(s) {
  return clean_ws(s)
}

function parse_status(status_raw, note_cell, out_note,
                      status, rest) {

  status_raw = clean_cell(status_raw)
  note_cell  = clean_cell(note_cell)

  status = ""
  out_note = note_cell
  rest = ""

  if (status_raw != "") {
    if (match(status_raw, /(works|detected|fixed|limited|malfunc|failed|disabled|unknown|n\/a)\b/)) {
      status = substr(status_raw, RSTART, RLENGTH)
      rest   = trim(substr(status_raw, RSTART + RLENGTH + 1))
      if (out_note == "" && rest != "")
        out_note = rest
    } else {
      status = status_raw
    }
  }

  if (status == "") status = "<none>"
  if (out_note == "") out_note = "<none>"

  ps_note = out_note

  return status
}

function dashes(n, s) {
  s = sprintf("%" n "s", "")
  gsub(/ /, "-", s)
  return s
}

function print_cols(indent, widths, labels, underline, prefix, suffix, w, t, n, i) {
  n = split(widths, w, SEP)
  split(labels, t, SEP)

  if (prefix == "") prefix = ""
  if (suffix == "") suffix = ""
  printf("%s%s", indent, prefix)
  for (i = 1; i <= n; i++) {
    if (i > 1) printf(" ")
    printf("%-*s", w[i], (underline ? dashes(w[i]) : t[i]))
  }
  printf("%s\n", suffix)
}

# ?computer=xxxxx
function probes_print_header(desc) {
  print "Probes:"
  if (desc != "")
    printf("  %s\n", desc)

  print_cols("  ",
    CP_W_ID SEP CP_W_SRC SEP CP_W_SYS SEP CP_W_DATE,
    "ID" SEP "Source" SEP "System" SEP "Date",
    0)
  print_cols("  ",
    CP_W_ID SEP CP_W_SRC SEP CP_W_SYS SEP CP_W_DATE,
    "", 1)
}

# ?probe=xxxxx
function dev_print_header(include_notes) {
  print "Devices:"

  if (include_notes) {
    print_cols("  ",
      DEV_W_BUS SEP DEV_W_ID SEP DEV_W_VENDOR SEP DEV_W_DEV SEP DEV_W_TYPE SEP DEV_W_DRV SEP DEV_W_STATUS SEP DEV_W_NOTES,
      "BUS" SEP "ID/Class" SEP "Vendor" SEP "Device" SEP "Type" SEP "Driver" SEP "Status" SEP "Comments",
      0)
    print_cols("  ",
      DEV_W_BUS SEP DEV_W_ID SEP DEV_W_VENDOR SEP DEV_W_DEV SEP DEV_W_TYPE SEP DEV_W_DRV SEP DEV_W_STATUS SEP DEV_W_NOTES,
      "", 1)
  } else {
    print_cols("  ",
      DEV_W_BUS SEP DEV_W_ID SEP DEV_W_VENDOR SEP DEV_W_DEV SEP DEV_W_TYPE SEP DEV_W_DRV SEP DEV_W_STATUS,
      "BUS" SEP "ID/Class" SEP "Vendor" SEP "Device" SEP "Type" SEP "Driver" SEP "Status",
      0)
    print_cols("  ",
      DEV_W_BUS SEP DEV_W_ID SEP DEV_W_VENDOR SEP DEV_W_DEV SEP DEV_W_TYPE SEP DEV_W_DRV SEP DEV_W_STATUS,
      "", 1)
  }
}

# ?id=xxxxx
function kd_print_header(desc) {
  print "Kernel drivers:"
  if (desc != "")
    printf("  %s\n", desc)

  print_cols("  ",
    KD_W_VER SEP KD_W_SRC SEP KD_W_CFG SEP KD_W_ID SEP KD_W_CLS,
    "Version" SEP "Source" SEP "Config" SEP "ID" SEP "Class",
    0)
  print_cols("  ",
    KD_W_VER SEP KD_W_SRC SEP KD_W_CFG SEP KD_W_ID SEP KD_W_CLS,
    "", 1)
}

function status_print_header(desc, include_notes) {
  print "Status:"
  if (desc != "")
    printf("  %s\n", desc)

  if (include_notes) {
    print_cols("  ",
      ST_W_HWID SEP ST_W_TYPE SEP ST_W_VM SEP ST_W_PROBES SEP ST_W_SYS SEP ST_W_STATUS SEP ST_W_NOTES,
      "HWid" SEP "Type" SEP "Vendor/Model" SEP "Probes" SEP "System" SEP "Status" SEP "Comments",
      0)
    print_cols("  ",
      ST_W_HWID SEP ST_W_TYPE SEP ST_W_VM SEP ST_W_PROBES SEP ST_W_SYS SEP ST_W_STATUS SEP ST_W_NOTES,
      "", 1)
  } else {
    print_cols("  ",
      ST_W_HWID SEP ST_W_TYPE SEP ST_W_VM SEP ST_W_PROBES SEP ST_W_SYS SEP ST_W_STATUS,
      "HWid" SEP "Type" SEP "Vendor/Model" SEP "Probes" SEP "System" SEP "Status",
      0)
    print_cols("  ",
      ST_W_HWID SEP ST_W_TYPE SEP ST_W_VM SEP ST_W_PROBES SEP ST_W_SYS SEP ST_W_STATUS,
      "", 1)
  }
}
