BEGIN {
  probe_host_init()
  probe_device_init()
}

{
  probe_host_handle($0)
  probe_device_handle($0)
}

END {
  probe_host_flush()
  probe_device_flush()
}
