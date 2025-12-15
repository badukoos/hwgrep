BEGIN {
  in_od   = 0
  in_list = 0
  hdr     = 0
  desc    = ""
}

/<h2[^>]*>Other Drivers<\/h2>/ {
  in_od = 1
}

in_od && desc == "" && match($0, /<p>(.*)<\/p>/, m) {
  desc = clean_inline(m[1])
}

in_od && $0 ~ /<ul>/ {
  in_list = 1
  next
}

in_list && $0 ~ /<\/ul>/ {
  in_list = 0
  in_od = 0
  next
}

in_list && match($0, /<li>(.*)<\/li>/, m) {
  line = clean_inline(m[1])

  if (!hdr) {
    print "Other drivers:"
    if (desc != "") printf("  %s\n", desc)
    hdr = 1
  }

  printf("  %s\n", line)
}

in_od && /<h2[^>]*>/ && $0 !~ /Other Drivers/ {
  in_od = 0
  in_list = 0
}
