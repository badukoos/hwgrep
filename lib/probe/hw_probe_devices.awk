function probe_device_init() {
  if (pd_init) return
  pd_init = 1

  if (max_results == "") max_results = 0

  row_filter_init()
  probe_device_reset()
}

function probe_device_reset() {
  pd_in_table      = 0
  pd_in_tr         = 0
  pd_row           = ""
  pd_printed_any   = 0
  pd_hdr_printed   = 0
  pd_reached_limit = 0
  pd_nrows         = 0

  delete pd_cells
}

function probe_device_print_header(include_notes) {
  if (pd_hdr_printed) return
  if (!pd_printed_any) {
    print ""
    pd_printed_any = 1
  }

  dev_print_header(include_notes)
  pd_hdr_printed = 1
}

function probe_device_print_row(bus, idcls, vendor, device, type, driver, status, note, include_notes,
                       nb, ni, nv, nd, nt, ndv, ns, nn, max_lines, i,
                       col_bus, col_id, col_vendor, col_dev, col_type, col_drv,
                       col_status, col_note, color_start, color_end) {

  nb  = wrap(bus,    DEV_W_BUS,    col_bus)
  ni  = wrap(idcls,  DEV_W_ID,     col_id)
  nv  = wrap(vendor, DEV_W_VENDOR, col_vendor)
  nd  = wrap(device, DEV_W_DEV,    col_dev)
  nt  = wrap(type,   DEV_W_TYPE,   col_type)
  ndv = wrap(driver, DEV_W_DRV,    col_drv)
  ns  = wrap(status, DEV_W_STATUS, col_status)

  nn = 0
  if (include_notes) {
    nn = wrap(note, DEV_W_NOTES, col_note)
  }

  max_lines = nb
  if (ni  > max_lines) max_lines = ni
  if (nv  > max_lines) max_lines = nv
  if (nd  > max_lines) max_lines = nd
  if (nt  > max_lines) max_lines = nt
  if (ndv > max_lines) max_lines = ndv
  if (ns  > max_lines) max_lines = ns
  if (include_notes && nn > max_lines) max_lines = nn

  color_start = pick_color(status, enable_color)
  color_end   = (color_start != "" ? "\033[0m" : "")

  for (i = 1; i <= max_lines; i++) {
    if (include_notes) {
      print_cols("  ",
        DEV_W_BUS SEP DEV_W_ID SEP DEV_W_VENDOR SEP DEV_W_DEV SEP DEV_W_TYPE SEP DEV_W_DRV SEP DEV_W_STATUS SEP DEV_W_NOTES,
        col_bus[i] SEP col_id[i] SEP col_vendor[i] SEP col_dev[i] SEP col_type[i] SEP col_drv[i] SEP col_status[i] SEP col_note[i],
        0,
        color_start, color_end)
    } else {
      print_cols("  ",
        DEV_W_BUS SEP DEV_W_ID SEP DEV_W_VENDOR SEP DEV_W_DEV SEP DEV_W_TYPE SEP DEV_W_DRV SEP DEV_W_STATUS,
        col_bus[i] SEP col_id[i] SEP col_vendor[i] SEP col_dev[i] SEP col_type[i] SEP col_drv[i] SEP col_status[i],
        0,
        color_start, color_end)
    }
  }
}

function probe_device_handle_row(n, bus, idcls, vendor, device, type, driver,
                        status_raw, status, note_cell, note, i) {

  if (pd_row == "") return
  if (index(pd_row, "<th") > 0) return

  n = extract_cells(pd_row, pd_cells)
  if (n < 7) {
    for (i = 1; i <= n; i++) delete pd_cells[i]
    pd_row = ""
    return
  }

  bus    = clean_field(pd_cells[1])
  idcls  = clean_field(pd_cells[2])
  vendor = clean_field(pd_cells[3])
  device = clean_field(pd_cells[4])
  type   = clean_field(pd_cells[5])
  driver = clean_field(pd_cells[6])

  status_raw = clean_field(pd_cells[7])
  note_cell  = (n >= 8 ? clean_field(pd_cells[8]) : "")

  if (bus    == "") bus    = "<none>"
  if (idcls  == "") idcls  = "<none>"
  if (vendor == "") vendor = "<none>"
  if (device == "") device = "<none>"
  if (type   == "") type   = "<none>"
  if (driver == "") driver = "<none>"

  note = note_cell
  status = parse_status(status_raw, note, note)
  note = ps_note

  delete row
  row["bus"]     = bus
  row["id"]      = idcls
  row["class"]   = idcls
  row["idclass"] = idcls
  row["vendor"]  = vendor
  row["device"]  = device
  row["type"]    = type
  row["driver"]  = driver
  row["status"]  = status

  if (!row_filter_row_match(row)) {
    for (i = 1; i <= n; i++) delete pd_cells[i]
    pd_row = ""
    return
  }

  probe_device_print_header(1)
  probe_device_print_row(bus, idcls, vendor, device, type, driver, status, note, 1)

  pd_nrows++

  for (i = 1; i <= n; i++) delete pd_cells[i]
  pd_row = ""

  if (max_results > 0 && pd_nrows >= max_results) {
    pd_reached_limit = 1
  }
}

function probe_device_handle(line) {
  probe_device_init()

  if (pd_reached_limit) return

  if (pd_in_table && line ~ /<\/table>/) {
    if (pd_in_tr) probe_device_handle_row()

    pd_in_table = 0
    pd_in_tr    = 0
    pd_row      = ""
    return
  }

  if (!pd_in_table) {
    if (line ~ /<table[^>]*class=.tbl[^>]*dev_info[^>]*highlight[^>]*>/) {
      pd_in_table = 1
    }
    return
  }

  if (line ~ /<tr[^>]*>/) {
    pd_in_tr = 1
    pd_row = ""
  }

  if (pd_in_tr) {
    pd_row = pd_row line "\n"
  }

  if (pd_in_tr && line ~ /<\/tr>/) {
    probe_device_handle_row()
    pd_in_tr = 0
    pd_row = ""

    if (pd_reached_limit) {
      pd_in_table = 0
      pd_in_tr    = 0
      pd_row      = ""
      return
    }
  }
}

function probe_device_flush() {
  if (pd_in_tr) probe_device_handle_row()
  probe_device_reset()
}
