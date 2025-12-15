function process_row(s, m, key, val) {
  s = row

  if (match(s, /<th[^>]*>([^<]*)<\/th>/, m)) {
    key = clean_inline(m[1])
  } else {
    return
  }

  if (match(s, /<td[^>]*>(.*)<\/td>/, m)) {
    val = clean_cell(m[1])
  } else {
    val = ""
  }

  if      (key == "HWid"   && comp_hwid   == "") comp_hwid   = val
  else if (key == "Type"   && comp_type   == "") comp_type   = val
  else if (key == "Vendor" && comp_vendor == "") comp_vendor = val
  else if (key == "Model"  && comp_model  == "") comp_model  = val
  else if (key == "Year"   && comp_year   == "") comp_year   = val
}

BEGIN {
  comp_title  = ""
  comp_hwid   = ""
  comp_type   = ""
  comp_vendor = ""
  comp_model  = ""
  comp_year   = ""

  in_table = 0
  in_tr    = 0
  row      = ""
}

{
  line = $0

  if (comp_title == "" &&
      match(line, /<h2[^>]*class=.top[^>]*>Computer[[:space:]]*'([^<]*)'<\/h2>/, m)) {
    comp_title = "Computer '" m[1] "'"
  }

  if (line ~ /<table[^>]*class=.tbl[[:space:]]+properties[[:space:]]+highlight[^>]*>/) {
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
  if (comp_title  == "" &&
      comp_hwid   == "" &&
      comp_type   == "" &&
      comp_vendor == "" &&
      comp_model  == "" &&
      comp_year   == "") {
    exit
  }

  if (comp_title  != "") printf("%s\n", comp_title)
  if (comp_hwid   != "") printf("  %-7s: %s\n", "HWid",   comp_hwid)
  if (comp_type   != "") printf("  %-7s: %s\n", "Type",   comp_type)
  if (comp_vendor != "") printf("  %-7s: %s\n", "Vendor", comp_vendor)
  if (comp_model  != "") printf("  %-7s: %s\n", "Model",  comp_model)
  if (comp_year   != "") printf("  %-7s: %s\n", "Year",   comp_year)
}
