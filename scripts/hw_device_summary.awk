function process_row(s, m, key, val) {
  s = row

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

  if      (key == "ID"        && dev_id     == "") dev_id     = val
  else if (key == "Class"     && dev_cls    == "") dev_cls    = val
  else if (key == "Type"      && dev_type   == "") dev_type   = val
  else if (key == "Vendor"    && dev_vendor == "") dev_vendor = val
  else if (key == "Name"      && dev_name   == "") dev_name   = val
  else if (key == "Subsystem" && dev_subsys == "") dev_subsys = val
}

BEGIN {
  dev_title  = ""
  dev_id     = ""
  dev_cls    = ""
  dev_type   = ""
  dev_vendor = ""
  dev_name   = ""
  dev_subsys = ""

  in_table = 0
  in_tr    = 0
  row      = ""
}

{
  line = $0

  if (dev_title == "" &&
      match(line, /<h2[^>]*class=.top[^>]*>([^<]*)<\/h2>/, m)) {
    dev_title = clean_inline(m[1])
  }

  if (line ~ /<table[^>]*class=.tbl[[:space:]]+narrow[[:space:]]+properties[[:space:]]+highlight[^>]*>/) {
    in_table = 1
  }

  if (!in_table) next

  if (line ~ /<\/table>/) {
    if (in_tr) {
      process_row()
      in_tr = 0
      row = ""
    }
    in_table = 0
    next
  }

  if (line ~ /<tr[^>]*>/) {
    in_tr = 1
    row = ""
  }

  if (in_tr) {
    row = row line "\n"
  }

  if (in_tr && line ~ /<\/tr>/) {
    process_row()
    in_tr = 0
    row = ""
  }
}

END {
  if (dev_title  == "" &&
      dev_id     == "" &&
      dev_cls    == "" &&
      dev_type   == "" &&
      dev_vendor == "" &&
      dev_name   == "" &&
      dev_subsys == "") {
    exit
  }

  if (dev_title  != "") printf("%s\n", dev_title)
  if (dev_id     != "") printf("  %-10s: %s\n", "ID",        dev_id)
  if (dev_cls    != "") printf("  %-10s: %s\n", "Class",     dev_cls)
  if (dev_type   != "") printf("  %-10s: %s\n", "Type",      dev_type)
  if (dev_vendor != "") printf("  %-10s: %s\n", "Vendor",    dev_vendor)
  if (dev_name   != "") printf("  %-10s: %s\n", "Name",      dev_name)
  if (dev_subsys != "") printf("  %-10s: %s\n", "Subsystem", dev_subsys)
}
