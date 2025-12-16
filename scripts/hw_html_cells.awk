function clean_inline(s) {
  gsub(/<br[[:space:]]*\/?>/, " ", s)
  gsub(/<[^>]*>/, "", s)
  gsub(/&nbsp;/, " ", s)
  gsub(/&[^;]+;/, "", s)
  gsub(/[[:space:]]+/, " ", s)
  return trim(s)
}

function clean_cell(raw, v, span, title) {
  v = raw

  while (match(v, /<span[^>]*title=["\047][^"\047]*["\047][^>]*>[^<]*<\/span>/)) {
    span = substr(v, RSTART, RLENGTH)

    title = span
    sub(/.*title=["\047]/, "", title)
    sub(/["\047].*$/, "", title)

    v = substr(v, 1, RSTART - 1) " " title " " substr(v, RSTART + RLENGTH)
  }

  gsub(/<br[[:space:]]*\/?>/, " ", v)
  gsub(/<[^>]*>/, "", v)
  gsub(/&nbsp;/, " ", v)
  gsub(/&[^;]+;/, "", v)
  gsub(/[[:space:]]+/, " ", v)

  return trim(v)
}

function extract_cells(row, cells,
                       start, pos, open, gt_rel, gt,
                       c_start, tmp, clos_rel, c_end,
                       raw, n) {
  start = 1
  n = 0

  while (1) {
    pos = index(substr(row, start), "<td")
    if (pos == 0) break

    open = start + pos - 1
    gt_rel = index(substr(row, open), ">")
    if (gt_rel == 0) break

    gt = open + gt_rel - 1
    c_start = gt + 1

    tmp = substr(row, c_start)
    clos_rel = index(tmp, "</td>")
    if (clos_rel == 0) break

    c_end = c_start + clos_rel - 2
    raw = substr(row, c_start, c_end - c_start + 1)

    n++
    cells[n] = clean_cell(raw)

    start = c_end + 5
  }

  return n
}
