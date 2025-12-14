BEGIN {
  SEP = "\034"

  CP_W_ID   = 10
  CP_W_SRC  = 8
  CP_W_SYS  = 12
  CP_W_DATE = 14

  DEV_W_BUS    = 4
  DEV_W_ID     = 26
  DEV_W_VENDOR = 22
  DEV_W_DEV    = 30
  DEV_W_TYPE   = 10
  DEV_W_DRV    = 12
  DEV_W_STATUS = 8
  DEV_W_NOTES  = 30

  KD_W_VER = 18
  KD_W_SRC = 40
  KD_W_CFG = 30
  KD_W_ID  = 16
  KD_W_CLS = 10

  ST_W_HWID   = 6
  ST_W_TYPE   = 10
  ST_W_VM     = 40
  ST_W_PROBES = 7
  ST_W_SYS    = 14
  ST_W_STATUS = 10
  ST_W_NOTES  = 30

}

function dashes(n, s) {
  s = sprintf("%" n "s", "")
  gsub(/ /, "-", s)
  return s
}

function print_cols(indent, widths, labels, underline, w, t, n, i) {
  n = split(widths, w, SEP)
  split(labels, t, SEP)

  printf("%s", indent)
  for (i = 1; i <= n; i++) {
    if (i > 1) printf(" ")
    printf("%-*s", w[i], (underline ? dashes(w[i]) : t[i]))
  }
  printf("\n")
}

# ?computer=xxxxx
function probes_print_header(desc) {
  print "Probes:"
  if (desc != "")
    printf("  %s\n", desc)

  print_cols("  ",
    CP_W_ID SEP CP_W_SRC SEP CP_W_SYS SEP CP_W_DATE,
    "ID"    SEP "Source" SEP "System" SEP "Date",
    0)
  print_cols("  ",
    CP_W_ID SEP CP_W_SRC SEP CP_W_SYS SEP CP_W_DATE,
    "", 1)
}

# ?probe=xxxxx
function dev_print_header(include_notes) {
  print "Devices:"

  if (include_notes) {
    print_cols("  ",
      DEV_W_BUS SEP DEV_W_ID SEP DEV_W_VENDOR SEP DEV_W_DEV SEP DEV_W_TYPE SEP DEV_W_DRV SEP DEV_W_STATUS SEP DEV_W_NOTES,
      "BUS"     SEP "ID/Class" SEP "Vendor"   SEP "Device"  SEP "Type"     SEP "Driver"  SEP "Status"     SEP "Comments",
      0)
    print_cols("  ",
      DEV_W_BUS SEP DEV_W_ID SEP DEV_W_VENDOR SEP DEV_W_DEV SEP DEV_W_TYPE SEP DEV_W_DRV SEP DEV_W_STATUS SEP DEV_W_NOTES,
      "", 1)
  } else {
    print_cols("  ",
      DEV_W_BUS SEP DEV_W_ID SEP DEV_W_VENDOR SEP DEV_W_DEV SEP DEV_W_TYPE SEP DEV_W_DRV SEP DEV_W_STATUS,
      "BUS"     SEP "ID/Class" SEP "Vendor"   SEP "Device"  SEP "Type"     SEP "Driver"  SEP "Status",
      0)
    print_cols("  ",
      DEV_W_BUS SEP DEV_W_ID SEP DEV_W_VENDOR SEP DEV_W_DEV SEP DEV_W_TYPE SEP DEV_W_DRV SEP DEV_W_STATUS,
      "", 1)
  }
}

# ?id=xxxxx
function kd_print_header(desc) {
  print "Kernel drivers:"
  if (desc != "")
    printf("  %s\n", desc)

  print_cols("  ",
    KD_W_VER SEP KD_W_SRC SEP KD_W_CFG SEP KD_W_ID SEP KD_W_CLS,
    "BUS"    SEP "ID/Class" SEP "Vendor" SEP "Device" SEP "Type",
    0)
  print_cols("  ",
    KD_W_VER SEP KD_W_SRC SEP KD_W_CFG SEP KD_W_ID SEP KD_W_CLS,
    "", 1)
}

function status_print_header(desc, include_notes) {
  print "Status:"
  if (desc != "")
    printf("  %s\n", desc)

  if (include_notes) {
    print_cols("  ",
      ST_W_HWID SEP ST_W_TYPE SEP ST_W_VM SEP ST_W_PROBES SEP ST_W_SYS SEP ST_W_STATUS SEP ST_W_NOTES,
      "HWid"    SEP "Type"    SEP "Vendor/Model" SEP "Probes" SEP "System" SEP "Status" SEP "Comments",
      0)
    print_cols("  ",
      ST_W_HWID SEP ST_W_TYPE SEP ST_W_VM SEP ST_W_PROBES SEP ST_W_SYS SEP ST_W_STATUS SEP ST_W_NOTES,
      "", 1)
  } else {
    print_cols("  ",
      ST_W_HWID SEP ST_W_TYPE SEP ST_W_VM SEP ST_W_PROBES SEP ST_W_SYS SEP ST_W_STATUS,
      "HWid"    SEP "Type"    SEP "Vendor/Model" SEP "Probes" SEP "System" SEP "Status",
      0)
    print_cols("  ",
      ST_W_HWID SEP ST_W_TYPE SEP ST_W_VM SEP ST_W_PROBES SEP ST_W_SYS SEP ST_W_STATUS,
      "", 1)
  }
}
