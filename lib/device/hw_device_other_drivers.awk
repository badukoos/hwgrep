function other_driver_init() {
  if (do_init) return
  do_init = 1
  other_driver_reset()
}

function other_driver_reset() {
  do_in_od   = 0
  do_in_list = 0
  do_hdr     = 0
  do_desc    = ""
}

function other_driver_print_header() {
  if (do_hdr) return
  print ""
  print "Other drivers:"
  if (do_desc != "") printf("  %s\n", do_desc)
  do_hdr = 1
}

function other_driver_handle(line, m, out) {
  other_driver_init()

  if (do_in_od && line ~ /<h2[^>]*>/ && line !~ /Other Drivers/) {
    if (do_desc != "") other_driver_print_header()
    other_driver_reset()
    return
  }

  if (!do_in_od) {
    if (line ~ /<h2[^>]*>Other Drivers<\/h2>/) {
      do_in_od = 1
    }
    return
  }

  if (do_desc == "" && match(line, /<p>(.*)<\/p>/, m)) {
    do_desc = clean_inline(m[1])
    return
  }

  if (do_in_list && line ~ /<\/ul>/) {
    do_in_list = 0
    do_in_od   = 0

    if (do_desc != "") other_driver_print_header()
    other_driver_reset()
    return
  }

  if (!do_in_list) {
    if (line ~ /<ul>/) do_in_list = 1
    return
  }

  if (match(line, /<li>(.*)<\/li>/, m)) {
    out = clean_inline(m[1])
    if (!do_hdr) other_driver_print_header()
    if (out != "") printf("  - %s\n", out)
    return
  }
}

function other_driver_flush() {
  if (do_in_od && do_desc != "") other_driver_print_header()
  other_driver_reset()
}
