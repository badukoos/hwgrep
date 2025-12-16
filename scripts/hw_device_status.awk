function print_status_row(hwid, type, vm, probes, sys, status, note, include_notes,
                          nh, nt, nv, np, ns, nst, nn, max_lines, i,
                          col_hwid, col_type, col_vm, col_probes, col_sys, col_status,
                          col_note, color_start, color_end) {
  nh  = wrap(hwid,   w_hwid,   col_hwid)
  nt  = wrap(type,   w_type,   col_type)
  nv  = wrap(vm,     w_vm,     col_vm)
  np  = wrap(probes, w_probes, col_probes)
  ns  = wrap(sys,    w_sys,    col_sys)
  nst = wrap(status, w_status, col_status)

  nn = 0
  if (include_notes) {
    nn = wrap(note, w_notes, col_note)
  }

  max_lines = nh
  if (nt  > max_lines) max_lines = nt
  if (nv  > max_lines) max_lines = nv
  if (np  > max_lines) max_lines = np
  if (ns  > max_lines) max_lines = ns
  if (nst > max_lines) max_lines = nst
  if (include_notes && nn  > max_lines) max_lines = nn

  color_start = pick_status_color(status, enable_color)
  color_end   = (color_start != "" ? "\033[0m" : "")

  for (i = 1; i <= max_lines; i++) {
    if (include_notes) {
        printf("  %s%-*s %-*s %-*s %-*s %-*s %-*s %-*s%s\n",
               color_start,
               w_hwid,   col_hwid[i],
               w_type,   col_type[i],
               w_vm,     col_vm[i],
               w_probes, col_probes[i],
               w_sys,    col_sys[i],
               w_status, col_status[i],
               w_notes,  col_note[i],
               color_end)
    } else {
        printf("  %s%-*s %-*s %-*s %-*s %-*s %-*s%s\n",
               color_start,
               w_hwid,   col_hwid[i],
               w_type,   col_type[i],
               w_vm,     col_vm[i],
               w_probes, col_probes[i],
               w_sys,    col_sys[i],
               w_status, col_status[i],
               color_end)
    }
  }
}

function reset_table_state(i) {
  for (i = 1; i <= nrows; i++) {
    delete rows_hwid[i]
    delete rows_type[i]
    delete rows_vm[i]
    delete rows_probes[i]
    delete rows_sys[i]
    delete rows_status[i]
    delete rows_note[i]
  }
  nrows = 0
  has_notes = 0
}

function flush_table(i, include_notes) {
  if (nrows <= 0) return

  include_notes = has_notes ? 1 : 0
  status_print_header(desc, include_notes)

  for (i = 1; i <= nrows; i++) {
    print_status_row(rows_hwid[i], rows_type[i], rows_vm[i], rows_probes[i],
                     rows_sys[i], rows_status[i], rows_note[i], include_notes)
  }

  reset_table_state()
}

function handle_row(n, hwid, type, vm, probes, sys,
                    status_raw, status, note_cell, note, rest, i) {
  if (row == "") return
  if (index(row, "<th") > 0) return

  n = extract_cells(row, cells)
  if (n < 6) return

  hwid   = clean_field(cells[1])
  type   = clean_field(cells[2])
  vm     = clean_field(cells[3])
  probes = clean_field(cells[4])
  sys    = clean_field(cells[5])

  status_raw = clean_field(cells[6])
  note_cell  = (n >= 7 ? clean_field(cells[7]) : "")

  status = ""
  note   = note_cell
  rest   = ""

  if (hwid   == "") hwid   = "<none>"
  if (type   == "") type   = "<none>"
  if (vm     == "") vm     = "<none>"
  if (probes == "") probes = "<none>"
  if (sys    == "") sys    = "<none>"

  status = parse_status(status_raw, note, note)
  note   = ps_note

  nrows++
  rows_hwid[nrows]   = hwid
  rows_type[nrows]   = type
  rows_vm[nrows]     = vm
  rows_probes[nrows] = probes
  rows_sys[nrows]    = sys
  rows_status[nrows] = status
  rows_note[nrows]   = note

  if (!is_none(note))
    has_notes = 1

  for (i = 1; i <= n; i++) delete cells[i]
  row = ""
}

BEGIN {
  in_table = 0
  in_tr = 0
  row   = ""

  nrows = 0
  has_notes = 0

  w_hwid   = ST_W_HWID
  w_type   = ST_W_TYPE
  w_vm     = ST_W_VM
  w_probes = ST_W_PROBES
  w_sys    = ST_W_SYS
  w_status = ST_W_STATUS
  w_notes  = ST_W_NOTES
}

{
  line = $0

  if (line ~ /<table[^>]*class=.tbl[[:space:]]+mono[[:space:]]+highlight[[:space:]]+computers_list[^>]*>/) {
    in_table = 1
    reset_table_state()
  }

  if (!in_table) next

  if (line ~ /<\/table>/) {
    if (in_tr) handle_row()
    in_table = 0
    in_tr    = 0
    row      = ""
    flush_table()
    next
  }

  if (line ~ /<tr[^>]*>/) {
    in_tr = 1
    row   = ""
  }

  if (in_tr) {
    row = row line "\n"
  }

  if (in_tr && line ~ /<\/tr>/) {
    handle_row()
    in_tr = 0
    row   = ""
  }
}
