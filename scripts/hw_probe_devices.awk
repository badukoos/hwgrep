function print_device_row(bus, idcls, vendor, device, type, driver, status, note, include_notes,
                          nb, ni, nv, nd, nt, ndv, ns, nn, max_lines, i,
                          col_bus, col_id, col_vendor, col_dev, col_type, col_drv,
                          col_status, col_note, color_start, color_end) {
  nb  = wrap(bus,    w_bus,    col_bus)
  ni  = wrap(idcls,  w_id,     col_id)
  nv  = wrap(vendor, w_vendor, col_vendor)
  nd  = wrap(device, w_dev,    col_dev)
  nt  = wrap(type,   w_type,   col_type)
  ndv = wrap(driver, w_drv,    col_drv)
  ns  = wrap(status, w_status, col_status)

  nn = 0
  if (include_notes) {
    nn = wrap(note, w_notes, col_note)
  }

  max_lines = nb
  if (ni  > max_lines) max_lines = ni
  if (nv  > max_lines) max_lines = nv
  if (nd  > max_lines) max_lines = nd
  if (nt  > max_lines) max_lines = nt
  if (ndv > max_lines) max_lines = ndv
  if (ns  > max_lines) max_lines = ns
  if (include_notes && nn > max_lines) max_lines = nn

  color_start = pick_status_color(status, enable_color)
  color_end   = (color_start != "" ? "\033[0m" : "")

  for (i = 1; i <= max_lines; i++) {
    if (include_notes) {
      printf("%s  %-*s %-*s %-*s %-*s %-*s %-*s %-*s %-*s%s\n",
             color_start,
             w_bus,    col_bus[i],
             w_id,     col_id[i],
             w_vendor, col_vendor[i],
             w_dev,    col_dev[i],
             w_type,   col_type[i],
             w_drv,    col_drv[i],
             w_status, col_status[i],
             w_notes,  col_note[i],
             color_end)
    } else {
      printf("%s  %-*s %-*s %-*s %-*s %-*s %-*s %-*s%s\n",
             color_start,
             w_bus,    col_bus[i],
             w_id,     col_id[i],
             w_vendor, col_vendor[i],
             w_dev,    col_dev[i],
             w_type,   col_type[i],
             w_drv,    col_drv[i],
             w_status, col_status[i],
             color_end)
    }
  }
}

function reset_table_state(i) {
  for (i = 1; i <= nrows; i++) {
    delete rows_bus[i]
    delete rows_idcls[i]
    delete rows_vendor[i]
    delete rows_device[i]
    delete rows_type[i]
    delete rows_driver[i]
    delete rows_status[i]
    delete rows_note[i]
  }
  nrows = 0
  has_notes = 0
}

function flush_table(i, include_notes) {
  if (nrows <= 0) return

  include_notes = has_notes ? 1 : 0
  dev_print_header(include_notes)

  for (i = 1; i <= nrows; i++) {
    print_device_row(rows_bus[i], rows_idcls[i], rows_vendor[i], rows_device[i],
                     rows_type[i], rows_driver[i], rows_status[i], rows_note[i],
                     include_notes)
  }

  reset_table_state()
}

function handle_row(n, bus, idcls, vendor, device, type, driver,
                    status_raw, status, note_cell, note, rest, i) {
  if (row == "") return
  if (index(row, "<th") > 0) return

  n = extract_cells(row, cells)
  if (n < 7) return

  bus    = clean_field(cells[1])
  idcls  = clean_field(cells[2])
  vendor = clean_field(cells[3])
  device = clean_field(cells[4])
  type   = clean_field(cells[5])
  driver = clean_field(cells[6])

  status_raw = clean_field(cells[7])
  note_cell  = (n >= 8 ? clean_field(cells[8]) : "")

  status = ""
  note   = note_cell
  rest   = ""

  if (bus    == "") bus    = "<none>"
  if (idcls  == "") idcls  = "<none>"
  if (vendor == "") vendor = "<none>"
  if (device == "") device = "<none>"
  if (type   == "") type   = "<none>"
  if (driver == "") driver = "<none>"

  status = parse_status(status_raw, note, note)
  note   = ps_note

  nrows++
  rows_bus[nrows]    = bus
  rows_idcls[nrows]  = idcls
  rows_vendor[nrows] = vendor
  rows_device[nrows] = device
  rows_type[nrows]   = type
  rows_driver[nrows] = driver
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

  w_bus    = DEV_W_BUS
  w_id     = DEV_W_ID
  w_vendor = DEV_W_VENDOR
  w_dev    = DEV_W_DEV
  w_type   = DEV_W_TYPE
  w_drv    = DEV_W_DRV
  w_status = DEV_W_STATUS
  w_notes  = DEV_W_NOTES
}

{
  line = $0

  if (line ~ /<table[^>]*class=.tbl[^>]*dev_info[^>]*highlight[^>]*>/) {
    in_table = 1
    reset_table_state()
    next
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
    for (i = 1; i <= n; i++) delete cells[i]
    in_tr = 0
    row   = ""
  }
}
