BEGIN {
  comp_info_init()
  comp_probe_init()
}

{
  comp_info_handle($0)
  comp_probe_handle($0)
}

END {
  comp_info_flush()
  comp_probe_flush()
}
