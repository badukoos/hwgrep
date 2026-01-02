function comp_probe_init() {
  if (cp_init) return
  cp_init = 1

  if (comp_mode == "") comp_mode = "render"
  if (os_name   == "") os_name   = ""
  if (os_icase  == "") os_icase  = 0
  if (emit_sys  == "") emit_sys  = 0

  comp_probe_reset()
}

function comp_probe_reset() {
  cp_in_h2    = 0
  cp_in_table = 0
  cp_in_tr    = 0
  cp_row      = ""
  cp_header   = 0

  delete cp_cells
}

function comp_probe_print_header() {
  if (comp_mode == "index") return
  if (cp_header) return
  print ""
  probes_print_header("")
  cp_header = 1
}

function comp_probe_print_row(id, src, syscell, datecell,
                       col_id, col_src, col_sys, col_date,
                       ni, ns, nsys, nd, max_lines, i) {
  ni   = wrap(id,       CP_W_ID,   col_id)
  ns   = wrap(src,      CP_W_SRC,  col_src)
  nsys = wrap(syscell,  CP_W_SYS,  col_sys)
  nd   = wrap(datecell, CP_W_DATE, col_date)

  max_lines = ni
  if (ns   > max_lines) max_lines = ns
  if (nsys > max_lines) max_lines = nsys
  if (nd   > max_lines) max_lines = nd

  for (i = 1; i <= max_lines; i++) {
    print_cols("  ",
      CP_W_ID SEP CP_W_SRC SEP CP_W_SYS SEP CP_W_DATE,
      col_id[i] SEP col_src[i] SEP col_sys[i] SEP col_date[i],
      0)
  }
}

function comp_probe_match_os(syscell, fam, a, b) {
  if (fam == "") return 1
  if (os_icase) {
    a = tolower(syscell)
    b = tolower(fam)
    return (index(a, b) > 0)
  }
  return (index(syscell, fam) > 0)
}

function comp_probe_emit_index(id, syscell) {
  if (emit_sys) print id "\t" syscell
  else print id
}

function comp_probe_handle_row(n, idcell, syscell, datecell,
                        parts, np, id, src, i) {
  if (cp_row == "") return
  if (index(cp_row, "<th") > 0) return

  n = extract_cells(cp_row, cp_cells)

  if (n < 3) {
    for (i = 1; i <= n; i++) delete cp_cells[i]
    return
  }

  idcell   = cp_cells[1]
  syscell  = cp_cells[2]
  datecell = cp_cells[3]

  np = split(idcell, parts, /[[:space:]]+/)
  id = parts[1]
  src = ""
  if (np > 1) {
    for (i = 2; i <= np; i++) {
      if (src == "") src = parts[i]
      else src = src " " parts[i]
    }
  }

  # only for cnsistency, ideally only src can be null here
  if (id       == "") id       = "<none>"
  if (src      == "") src      = "<none>"
  if (syscell  == "") syscell  = "<none>"
  if (datecell == "") datecell = "<none>"

  if (comp_mode == "index") {
    if (syscell == "<none>") {
      if (os_name == "") comp_probe_emit_index(id, syscell)
    } else {
      if (comp_probe_match_os(syscell, os_name)) comp_probe_emit_index(id, syscell)
    }

    for (i = 1; i <= n; i++) delete cp_cells[i]
    return
  }

  comp_probe_print_header()
  comp_probe_print_row(id, src, syscell, datecell)

  for (i = 1; i <= n; i++) delete cp_cells[i]
}

function comp_probe_handle(line) {
  comp_probe_init()

  if (cp_in_table && line ~ /<\/table>/) {
    if (cp_in_tr) comp_probe_handle_row()
    comp_probe_reset()
    return
  }

  if (!cp_in_h2) {
    if (line ~ /<h2[^>]*>Probes[[:space:]]*\([0-9]+\)<\/h2>/) {
      cp_in_h2 = 1
    }
    return
  }

  if (!cp_in_table) {
    if (line ~ /<table[^>]*>/) {
      cp_in_table = 1
    }
    return
  }

  if (line ~ /<tr[^>]*>/) {
    cp_in_tr = 1
    cp_row = ""
  }

  if (cp_in_tr) {
    cp_row = cp_row line "\n"
  }

  if (cp_in_tr && line ~ /<\/tr>/) {
    comp_probe_handle_row()
    cp_in_tr = 0
    cp_row = ""
  }
}

function comp_probe_flush() {
  if (cp_in_tr) comp_probe_handle_row()
  comp_probe_reset()
}