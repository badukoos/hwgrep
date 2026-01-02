function probe_host_init() {
  if (ph_init) return
  ph_init = 1
  probe_host_reset()
}

function probe_host_reset() {
  host_system   = ""
  host_arch     = ""
  host_kernel   = ""
  host_vendor   = ""
  host_model    = ""
  host_year     = ""
  host_hwid     = ""
  host_type     = ""
  host_de       = ""

  ph_in_host_h2 = 0
  ph_in_table   = 0
  ph_in_tr      = 0
  ph_row        = ""
  ph_printed    = 0
}

function probe_host_handle_row(s, m, key, val) {
  s = ph_row
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

function probe_host_print() {
  if (ph_printed) return

  if (host_system == "" &&
      host_arch   == "" &&
      host_kernel == "" &&
      host_vendor == "" &&
      host_model  == "" &&
      host_year   == "" &&
      host_hwid   == "" &&
      host_type   == "" &&
      host_de     == "") {
    return
  }

  print "Host:"
  if (host_system != "") printf("  %-7s: %s\n", "System", host_system)
  if (host_arch   != "") printf("  %-7s: %s\n", "Arch",   host_arch)
  if (host_kernel != "") printf("  %-7s: %s\n", "Kernel", host_kernel)
  if (host_vendor != "") printf("  %-7s: %s\n", "Vendor", host_vendor)
  if (host_model  != "") printf("  %-7s: %s\n", "Model",  host_model)
  if (host_year   != "") printf("  %-7s: %s\n", "Year",   host_year)
  if (host_hwid   != "") printf("  %-7s: %s\n", "HWid",   host_hwid)
  if (host_type   != "") printf("  %-7s: %s\n", "Type",   host_type)
  if (host_de     != "") printf("  %-7s: %s\n", "DE",     host_de)

  ph_printed = 1
  print ""
}

function probe_host_handle(line) {
  probe_host_init()

  if (ph_printed) return

  if (ph_in_table && line ~ /<\/table>/) {
    if (ph_in_tr) probe_host_handle_row()

    ph_in_table   = 0
    ph_in_host_h2 = 0
    ph_in_tr      = 0
    ph_row        = ""

    probe_host_print()
    return
  }

  if (!ph_in_host_h2) {
    if (line ~ /<h2[^>]*>Host<\/h2>/) {
      ph_in_host_h2 = 1
    }
    return
  }

  if (!ph_in_table) {
    if (line ~ /<table[^>]*>/) {
      ph_in_table = 1
    }
    return
  }

  if (line ~ /<tr[^>]*>/) {
    ph_in_tr = 1
    ph_row = ""
  }

  if (ph_in_tr) {
    ph_row = ph_row line "\n"
  }

  if (ph_in_tr && line ~ /<\/tr>/) {
    probe_host_handle_row()
    ph_in_tr = 0
    ph_row = ""
  }
}

function probe_host_flush() {
  if (ph_in_tr) probe_host_handle_row()
  probe_host_print()
  probe_host_reset()
}
