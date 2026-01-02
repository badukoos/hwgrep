function kernel_driver_init() {
  if (dk_init) return
  dk_init = 1
  kernel_driver_reset()
}

function kernel_driver_reset() {
  dk_in_kde   = 0
  dk_in_table = 0
  dk_in_tr    = 0
  dk_row      = ""
  dk_hdr      = 0
  dk_kd_desc  = ""

  delete dk_cells
}

function kernel_driver_print_header() {
  if (dk_hdr) return

  if (dk_in_kde && dk_kd_desc != "") {
    print ""
    print "Kernel drivers:"
    printf("  %s\n", dk_kd_desc)
    dk_hdr = 1
  }
}

function kernel_driver_print_table_header() {
  if (dk_hdr) return
  print ""
  kd_print_header(dk_kd_desc)
  dk_hdr = 1
}

function kernel_driver_print_row(ver, src, cfg, id, cls,
                       nv, ns, nc, ni, nl, max_lines, i,
                       col_ver, col_src, col_cfg, col_id, col_cls) {
  nv = wrap(ver, KD_W_VER, col_ver)
  ns = wrap(src, KD_W_SRC, col_src)
  nc = wrap(cfg, KD_W_CFG, col_cfg)
  ni = wrap(id,  KD_W_ID,  col_id)
  nl = wrap(cls, KD_W_CLS, col_cls)

  max_lines = nv
  if (ns > max_lines) max_lines = ns
  if (nc > max_lines) max_lines = nc
  if (ni > max_lines) max_lines = ni
  if (nl > max_lines) max_lines = nl

  for (i = 1; i <= max_lines; i++) {
    print_cols("  ",
      KD_W_VER SEP KD_W_SRC SEP KD_W_CFG SEP KD_W_ID SEP KD_W_CLS,
      col_ver[i] SEP col_src[i] SEP col_cfg[i] SEP col_id[i] SEP col_cls[i],
      0)
  }
}

function kernel_driver_handle_row(n, ver, src, cfg, id, cls, i) {
  if (dk_row == "") return
  if (index(dk_row, "<th") > 0) return

  n = extract_cells(dk_row, dk_cells)
  if (n < 5) {
    for (i = 1; i <= n; i++) delete dk_cells[i]
    return
  }

  ver = dk_cells[1]
  src = dk_cells[2]
  cfg = dk_cells[3]
  id  = dk_cells[4]
  cls = dk_cells[5]

  kernel_driver_print_table_header()
  kernel_driver_print_row(ver, src, cfg, id, cls)

  for (i = 1; i <= n; i++) delete dk_cells[i]
}

function kernel_driver_handle(line, m) {
  kernel_driver_init()

  if (dk_in_kde && !dk_in_table && line ~ /<h2[^>]*>/ && line !~ /Kernel Drivers/) {
    if (dk_in_tr) kernel_driver_handle_row()
    kernel_driver_print_header()
    kernel_driver_reset()
    return
  }

  if (!dk_in_kde) {
    if (line ~ /<h2[^>]*>Kernel Drivers<\/h2>/) {
      dk_in_kde = 1
    }
    return
  }

  if (dk_kd_desc == "" && match(line, /<p>(.*)<\/p>/, m)) {
    dk_kd_desc = clean_cell(m[1])
    return
  }

  if (dk_in_table && line ~ /<\/table>/) {
    if (dk_in_tr) kernel_driver_handle_row()

    dk_in_table = 0
    dk_in_tr    = 0
    dk_row      = ""

    kernel_driver_print_header()
    return
  }

  if (!dk_in_table) {
    if (line ~ /<table[^>]*>/) {
      dk_in_table = 1
    }
    return
  }

  if (line ~ /<tr[^>]*>/) {
    dk_in_tr = 1
    dk_row = ""
  }

  if (dk_in_tr) {
    dk_row = dk_row line "\n"
  }

  if (dk_in_tr && line ~ /<\/tr>/) {
    kernel_driver_handle_row()
    dk_in_tr = 0
    dk_row = ""
  }
}

function kernel_driver_flush() {
  if (dk_in_tr) kernel_driver_handle_row()
  kernel_driver_print_header()
  kernel_driver_reset()
}
