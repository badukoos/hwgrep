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

  if      (key == "System" && host_system == "") host_system = val
  else if (key == "Arch"   && host_arch   == "") host_arch   = val
  else if (key == "Kernel" && host_kernel == "") host_kernel = val
  else if (key == "Vendor" && host_vendor == "") host_vendor = val
  else if (key == "Model"  && host_model  == "") host_model  = val
  else if (key == "Year"   && host_year   == "") host_year   = val
  else if (key == "HWid"   && host_hwid   == "") host_hwid   = val
  else if (key == "Type"   && host_type   == "") host_type   = val
  else if (key == "DE"     && host_de     == "") host_de     = val
}

BEGIN {
  host_system = ""
  host_arch   = ""
  host_kernel = ""
  host_vendor = ""
  host_model  = ""
  host_year   = ""
  host_hwid   = ""
  host_type   = ""
  host_de     = ""

  in_host_h2 = 0
  in_table   = 0
  in_tr      = 0
  row        = ""
}

{
  line = $0

  if (line ~ /<h2[^>]*>Host<\/h2>/) {
    in_host_h2 = 1
    next
  }

  if (in_host_h2 && !in_table && line ~ /<table[^>]*>/) {
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
    in_host_h2 = 0
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
  if (host_system == "" &&
      host_arch   == "" &&
      host_kernel == "" &&
      host_vendor == "" &&
      host_model  == "" &&
      host_year   == "" &&
      host_hwid   == "" &&
      host_type   == "" &&
      host_de     == "") {
    exit
  }

  print "Host"
  if (host_system != "") printf("  %-7s: %s\n", "System", host_system)
  if (host_arch   != "") printf("  %-7s: %s\n", "Arch",   host_arch)
  if (host_kernel != "") printf("  %-7s: %s\n", "Kernel", host_kernel)
  if (host_vendor != "") printf("  %-7s: %s\n", "Vendor", host_vendor)
  if (host_model  != "") printf("  %-7s: %s\n", "Model",  host_model)
  if (host_year   != "") printf("  %-7s: %s\n", "Year",   host_year)
  if (host_hwid   != "") printf("  %-7s: %s\n", "HWid",   host_hwid)
  if (host_type   != "") printf("  %-7s: %s\n", "Type",   host_type)
  if (host_de     != "") printf("  %-7s: %s\n", "DE",     host_de)
}
