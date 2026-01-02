function device_status_init() {
  if (st_init) return
  st_init = 1

  if (max_results == "") max_results = 0

  row_filter_init()
  device_status_reset()
}

function device_status_reset() {
  st_in_table      = 0
  st_in_tr         = 0
  st_row           = ""
  st_printed_any   = 0
  st_hdr_printed   = 0
  st_desc          = ""
  st_reached_limit = 0
  st_nrows         = 0

  delete st_cells
}

function device_status_print_header(include_notes) {
  if (st_hdr_printed) return

  if (!st_printed_any) {
    print ""
    st_printed_any = 1
  }

  status_print_header(st_desc, include_notes)
  st_hdr_printed = 1
}

function device_status_print_row(hwid, type, vm, probes, sys, status, note, include_notes,
                       nh, nt, nv, np, ns, nst, nn, max_lines, i,
                       col_hwid, col_type, col_vm, col_probes, col_sys, col_status,
                       col_note, color_start, color_end) {

  nh  = wrap(hwid,   ST_W_HWID,   col_hwid)
  nt  = wrap(type,   ST_W_TYPE,   col_type)
  nv  = wrap(vm,     ST_W_VM,     col_vm)
  np  = wrap(probes, ST_W_PROBES, col_probes)
  ns  = wrap(sys,    ST_W_SYS,    col_sys)
  nst = wrap(status, ST_W_STATUS, col_status)

  nn = 0
  if (include_notes) {
    nn = wrap(note, ST_W_NOTES, col_note)
  }

  max_lines = nh
  if (nt  > max_lines) max_lines = nt
  if (nv  > max_lines) max_lines = nv
  if (np  > max_lines) max_lines = np
  if (ns  > max_lines) max_lines = ns
  if (nst > max_lines) max_lines = nst
  if (include_notes && nn > max_lines) max_lines = nn

  color_start = pick_color(status, enable_color)
  color_end   = (color_start != "" ? "\033[0m" : "")

  for (i = 1; i <= max_lines; i++) {
    if (include_notes) {
      print_cols("  ",
        ST_W_HWID SEP ST_W_TYPE SEP ST_W_VM SEP ST_W_PROBES SEP ST_W_SYS SEP ST_W_STATUS SEP ST_W_NOTES,
        col_hwid[i] SEP col_type[i] SEP col_vm[i] SEP col_probes[i] SEP col_sys[i] SEP col_status[i] SEP col_note[i],
        0,
        color_start, color_end)
    } else {
      print_cols("  ",
        ST_W_HWID SEP ST_W_TYPE SEP ST_W_VM SEP ST_W_PROBES SEP ST_W_SYS SEP ST_W_STATUS,
        col_hwid[i] SEP col_type[i] SEP col_vm[i] SEP col_probes[i] SEP col_sys[i] SEP col_status[i],
        0,
        color_start, color_end)
    }
  }
}

function device_status_handle_row(n, hwid, type, vm, probes, sys,
                        status_raw, status, note_cell, note, i,
                        short_hwid, full_hwid, vm_html, model_title, prefix, m) {

  if (st_row == "") return
  if (index(st_row, "<th") > 0) return

  n = extract_cells(st_row, st_cells)
  if (n < 6) {
    for (i = 1; i <= n; i++) delete st_cells[i]
    st_row = ""
    return
  }

  short_hwid = clean_field(st_cells[1])
  full_hwid  = ""

  if (match(st_row, /hwid=([0-9A-Fa-f]{12})/, m)) {
    full_hwid = tolower(m[1])
  }

  hwid = (full_hwid != "" ? full_hwid : short_hwid)
  type = clean_field(st_cells[2])

  vm_html = st_cells[3]
  vm = clean_field(vm_html)

  model_title = ""
  if (match(st_row, /<span[^>]*title=['"]([^'"]*)['"][^>]*>\.\.\.<\/span>/, m)) {
    model_title = clean_inline(m[1])
  }

  if (model_title != "") {
    prefix = ""
    if (match(vm, /^([^\/]*\/)[[:space:]]*/, m)) {
      prefix = clean_inline(m[1])
    }
    if (prefix != "") vm = prefix " " model_title
    else vm = model_title
  }

  probes = clean_field(st_cells[4])
  sys    = clean_field(st_cells[5])

  status_raw = clean_field(st_cells[6])
  note_cell  = (n >= 7 ? clean_field(st_cells[7]) : "")

  if (hwid   == "") hwid   = "<none>"
  if (type   == "") type   = "<none>"
  if (vm     == "") vm     = "<none>"
  if (probes == "") probes = "<none>"
  if (sys    == "") sys    = "<none>"

  note = note_cell
  status = parse_status(status_raw, note, note)
  note = ps_note

  delete row
  row["hwid"]   = hwid
  row["type"]   = type
  row["model"]  = vm
  row["vendor"] = vm
  row["probes"] = probes
  row["system"] = sys
  row["sys"]    = sys
  row["status"] = status

  if (!row_filter_row_match(row)) {
    for (i = 1; i <= n; i++) delete st_cells[i]
    st_row = ""
    return
  }

  device_status_print_header(1)
  device_status_print_row(hwid, type, vm, probes, sys, status, note, 1)

  st_nrows++

  for (i = 1; i <= n; i++) delete st_cells[i]
  st_row = ""

  if (max_results > 0 && st_nrows >= max_results) {
    st_reached_limit = 1
    st_in_table = 0
    st_in_tr    = 0
    st_row      = ""
  }
}

function device_status_handle(line) {
  device_status_init()

  if (st_reached_limit) return

  if (st_in_table && line ~ /<\/table>/) {
    if (st_in_tr) device_status_handle_row()

    st_in_table = 0
    st_in_tr    = 0
    st_row      = ""
    return
  }

  if (!st_in_table) {
    if (line ~ /<table[^>]*class=.tbl[[:space:]]+mono[[:space:]]+highlight[[:space:]]+computers_list[^>]*>/) {
      st_in_table = 1
    }
    return
  }

  if (line ~ /<tr[^>]*>/) {
    st_in_tr = 1
    st_row = ""
  }

  if (st_in_tr) {
    st_row = st_row line "\n"
  }

  if (st_in_tr && line ~ /<\/tr>/) {
    device_status_handle_row()
    st_in_tr = 0
    st_row = ""
  }
}

function device_status_flush() {
  if (st_in_tr) device_status_handle_row()
  device_status_reset()
}
