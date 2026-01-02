function comp_info_init() {
  if (cs_init) return
  cs_init = 1
  cs_computer_id = COMPUTER_ID

  comp_info_reset()
}

function comp_info_reset() {
  cs_title    = ""
  cs_hwid     = ""
  cs_type     = ""
  cs_vendor   = ""
  cs_model    = ""
  cs_year     = ""
  cs_in_table = 0
  cs_in_tr    = 0
  cs_row      = ""
  cs_done     = 0
}

function comp_info_print() {
  if (cs_done) return
  cs_done = 1

  if (cs_computer_id != "") cs_hwid = cs_computer_id
  if (cs_title  == "") cs_title  = "Computer '<unknown>'"
  if (cs_hwid   == "") cs_hwid   = "<none>"
  if (cs_type   == "") cs_type   = "<none>"
  if (cs_vendor == "") cs_vendor = "<none>"
  if (cs_model  == "") cs_model  = "<none>"
  if (cs_year   == "") cs_year   = "<none>"

  print cs_title
  printf("  HWid   : %s\n", cs_hwid)
  printf("  Type   : %s\n", cs_type)
  printf("  Vendor : %s\n", cs_vendor)
  printf("  Model  : %s\n", cs_model)
  printf("  Year   : %s\n", cs_year)
}

function comp_info_handle_row(s, m, key, val) {
  s = cs_row
  if (s == "") return

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

  if      (key == "HWid"   && cs_hwid   == "" && cs_computer_id == "") cs_hwid   = val
  else if (key == "Type"   && cs_type   == "") cs_type   = val
  else if (key == "Vendor" && cs_vendor == "") cs_vendor = val
  else if (key == "Model"  && cs_model  == "") cs_model  = val
  else if (key == "Year"   && cs_year   == "") cs_year   = val
}

function comp_info_handle(line, m) {
  comp_info_init()

  if (cs_title == "" &&
      match(line, /<h2[^>]*class=.top[^>]*>Computer[[:space:]]*'([^<]*)'<\/h2>/, m)) {
    cs_title = "Computer '" m[1] "'"
  }

  if (cs_in_table && line ~ /<\/table>/) {
    if (cs_in_tr) comp_info_handle_row()

    cs_in_table = 0
    cs_in_tr    = 0
    cs_row      = ""

    comp_info_print()
    return
  }

  if (!cs_in_table) {
    if (line ~ /<table[^>]*>/ && line ~ /tbl/) {
      cs_in_table = 1
    }
    return
  }

  if (line ~ /<tr[^>]*>/) {
    cs_in_tr = 1
    cs_row = ""
  }

  if (cs_in_tr) {
    cs_row = cs_row line "\n"
  }

  if (cs_in_tr && line ~ /<\/tr>/) {
    comp_info_handle_row()
    cs_in_tr = 0
    cs_row = ""
  }
}

function comp_info_flush() {
  if (cs_in_tr) comp_info_handle_row()
  comp_info_print()
  comp_info_reset()
}
