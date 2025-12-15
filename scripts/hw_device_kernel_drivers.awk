function print_kd_row(ver, src, cfg, id, cls,
                      nv, ns, nc, ni, nl, max_lines, i,
                      col_ver, col_src, col_cfg, col_id, col_cls) {
  nv = wrap(ver, w_ver, col_ver)
  ns = wrap(src, w_src, col_src)
  nc = wrap(cfg, w_cfg, col_cfg)
  ni = wrap(id,  w_id,  col_id)
  nl = wrap(cls, w_cls, col_cls)

  max_lines = nv
  if (ns > max_lines) max_lines = ns
  if (nc > max_lines) max_lines = nc
  if (ni > max_lines) max_lines = ni
  if (nl > max_lines) max_lines = nl

  for (i = 1; i <= max_lines; i++) {
    print_cols("  ",
      w_ver SEP w_src SEP w_cfg SEP w_id SEP w_cls,
      col_ver[i] SEP col_src[i] SEP col_cfg[i] SEP col_id[i] SEP col_cls[i],
      0)
  }
}

BEGIN {
  in_kd = 0
  in_tbody = 0
  have_rows = 0
  hdr = 0

  kd_desc = ""

  w_ver = KD_W_VER
  w_src = KD_W_SRC
  w_cfg = KD_W_CFG
  w_id  = KD_W_ID
  w_cls = KD_W_CLS
}

/<h2[^>]*>Kernel Drivers<\/h2>/ {
  in_kd = 1
}

in_kd && kd_desc == "" && match($0, /<p>(.*)<\/p>/, m) {
  kd_desc = clean_cell(m[1])
}

in_kd && /<tbody[^>]*>/ {
  in_tbody = 1
  next
}

in_tbody && /<\/tbody>/ {
  in_tbody = 0
  in_kd = 0
  next
}

!in_tbody {
  next
}

/<tr[^>]*>/ {
  col = 0
  row_has_th = 0
  delete cell
  next
}

/<\/tr>/ {
  if (!row_has_th && col >= 5) {
    if (!hdr) {
      kd_print_header(kd_desc)
      hdr = 1
    }
    ver = cell[1]
    src = cell[2]
    cfg = cell[3]
    id  = cell[4]
    cls = cell[5]
    print_kd_row(ver, src, cfg, id, cls)
    have_rows = 1
  }
  next
}

{
  if (index($0, "<th") > 0) {
    row_has_th = 1
    next
  }

  if (index($0, "<td") > 0) {
    col++
    sub(/.*<td[^>]*>/, "", $0)
    sub(/<\/td>.*/, "", $0)
    cell[col] = clean_cell($0)
  }
}
