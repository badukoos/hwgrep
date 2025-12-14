function print_probe_row(id, src, syscell, datecell,
                         col_id, col_src, col_sys, col_date,
                         ni, ns, nsys, nd, max_lines, i) {
  ni   = wrap(id,  w_id,  col_id)
  ns   = wrap(src, w_src, col_src)
  nsys = wrap(syscell,  w_sys,  col_sys)
  nd   = wrap(datecell, w_date, col_date)

  max_lines = ni
  if (ns   > max_lines) max_lines = ns
  if (nsys > max_lines) max_lines = nsys
  if (nd   > max_lines) max_lines = nd

  for (i = 1; i <= max_lines; i++) {
    printf("  %-*s %-*s %-*s %-*s\n",
           w_id,   col_id[i],
           w_src,  col_src[i],
           w_sys,  col_sys[i],
           w_date, col_date[i])
  }
}

function handle_row(n, idcell, syscell, datecell,
                       parts, np, id, src, i) {
  if (row == "") return
  if (index(row, "<th") > 0) return

  n = extract_cells(row, cells)
  if (n < 3) return

  idcell  = cells[1]
  syscell = cells[2]
  datecell = cells[3]

  np = split(idcell, parts, /[[:space:]]+/)
  id = parts[1]
  src = ""
  if (np > 1) {
    for (i = 2; i <= np; i++) {
      if (src == "")
        src = parts[i]
      else
        src = src " " parts[i]
    }
  }

  if (id  == "") id  = "<none>"
  if (src == "") src = "<none>"
  if (syscell  == "") syscell  = "<none>"
  if (datecell == "") datecell = "<none>"

  if (!header) {
    probes_print_header(probes_desc)
    header = 1
  }

  print_probe_row(id, src, syscell, datecell)
}

BEGIN {
  in_h2    = 0
  in_table = 0
  in_tr    = 0
  row      = ""

  header = 0
  probes_desc = ""

  w_id   = CP_W_ID
  w_src  = CP_W_SRC
  w_sys  = CP_W_SYS
  w_date = CP_W_DATE
}

{
  line = $0

  if (line ~ /<h2[^>]*>Probes[[:space:]]*\([0-9]+\)<\/h2>/) {
    in_h2 = 1
    next
  }

  if (in_h2 && !in_table && line ~ /<table[^>]*>/) {
    in_table = 1
    next
  }

  if (!in_table) next

  if (line ~ /<\/table>/) {
    if (in_tr) handle_row()
    in_table = 0
    in_h2 = 0
    in_tr = 0
    row   = ""
    next
  }

  if (line ~ /<tr[^>]*>/) {
    in_tr = 1
    row   = ""
  }

  if (in_tr) {
    row = row line "\n"
  }

  if (in_tr && line ~ /<\/tr>/) {
    handle_row()
    for (i = 1; i <= n; i++) delete cells[i]
    in_tr = 0
    row   = ""
  }
}
