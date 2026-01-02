function device_info_init() {
  if (ds_init) return
  ds_init = 1
  device_info_reset()
}

function device_info_reset() {
  ds_dev_title  = ""
  ds_dev_id     = ""
  ds_dev_cls    = ""
  ds_dev_type   = ""
  ds_dev_vendor = ""
  ds_dev_name   = ""
  ds_dev_subsys = ""
  ds_in_table   = 0
  ds_in_tr      = 0
  ds_row        = ""
  ds_printed    = 0
}

function device_info_print() {
  if (ds_printed) return

  if (ds_dev_title  == "" &&
      ds_dev_id     == "" &&
      ds_dev_cls    == "" &&
      ds_dev_type   == "" &&
      ds_dev_vendor == "" &&
      ds_dev_name   == "" &&
      ds_dev_subsys == "") {
    return
  }

  if (ds_dev_title  != "") printf("%s\n", ds_dev_title)
  if (ds_dev_id     != "") printf("  %-10s: %s\n", "ID",        ds_dev_id)
  if (ds_dev_cls    != "") printf("  %-10s: %s\n", "Class",     ds_dev_cls)
  if (ds_dev_type   != "") printf("  %-10s: %s\n", "Type",      ds_dev_type)
  if (ds_dev_vendor != "") printf("  %-10s: %s\n", "Vendor",    ds_dev_vendor)
  if (ds_dev_name   != "") printf("  %-10s: %s\n", "Name",      ds_dev_name)
  if (ds_dev_subsys != "") printf("  %-10s: %s\n", "Subsystem", ds_dev_subsys)

  ds_printed = 1
}

function device_info_handle_row(s, m, key, val) {
  s = ds_row
  if (s == "") return

  if (match(s, /<th[^>]*>([^<]*)<\/th>/, m)) {
    key = m[1]
    gsub(/&nbsp;/, " ", key)
    key = trim(key)
  } else {
    return
  }

  if (match(s, /<td[^>]*>(.*)<\/td>/, m)) {
    val = clean_inline(m[1])
  } else {
    val = ""
  }

  if      (key == "ID"        && ds_dev_id     == "") ds_dev_id     = val
  else if (key == "Class"     && ds_dev_cls    == "") ds_dev_cls    = val
  else if (key == "Type"      && ds_dev_type   == "") ds_dev_type   = val
  else if (key == "Vendor"    && ds_dev_vendor == "") ds_dev_vendor = val
  else if (key == "Name"      && ds_dev_name   == "") ds_dev_name   = val
  else if (key == "Subsystem" && ds_dev_subsys == "") ds_dev_subsys = val
}

function device_info_handle(line, m) {
  device_info_init()

  if (ds_dev_title == "" &&
      match(line, /<h2[^>]*class=.top[^>]*>([^<]*)<\/h2>/, m)) {
    ds_dev_title = clean_inline(m[1])
  }

  if (ds_in_table && line ~ /<\/table>/) {
    if (ds_in_tr) device_info_handle_row()

    ds_in_table = 0
    ds_in_tr    = 0
    ds_row      = ""

    device_info_print()
    return
  }

  if (!ds_in_table) {
    if (line ~ /<table[^>]*class=.tbl[[:space:]]+narrow[[:space:]]+properties[[:space:]]+highlight[^>]*>/) {
      ds_in_table = 1
    }
    return
  }

  if (line ~ /<tr[^>]*>/) {
    ds_in_tr = 1
    ds_row = ""
  }

  if (ds_in_tr) {
    ds_row = ds_row line "\n"
  }

  if (ds_in_tr && line ~ /<\/tr>/) {
    device_info_handle_row()
    ds_in_tr = 0
    ds_row = ""
  }
}

function device_info_flush() {
  if (ds_in_tr) device_info_handle_row()
  device_info_print()
  device_info_reset()
}
