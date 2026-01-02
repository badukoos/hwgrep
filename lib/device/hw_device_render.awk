BEGIN {
  device_info_init()
  kernel_driver_init()
  other_driver_init()
  device_status_init()
}

{
  line = $0
  device_info_handle(line)
  kernel_driver_handle(line)
  other_driver_handle(line)
  device_status_handle(line)
}

END {
  device_info_flush()
  kernel_driver_flush()
  other_driver_flush()
  device_status_flush()
}
