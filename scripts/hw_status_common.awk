function pick_status_color(status, enable_color, color_start) {
  if (enable_color != 1) return ""

  if (status == "failed") color_start = "\033[31m"
  else if (status == "works") color_start = "\033[32m"
  else if (status == "malfunc") color_start = "\033[33m"
  else if (status == "fixed") color_start = "\033[36m"
  else if (status == "limited") color_start = "\033[38;2;110;95;29m"
  else color_start = ""

  return color_start
}

function clean_field(s) {
  return clean_ws(s)
}

function parse_status(status_raw, note_cell, out_note,
                      status, rest) {

  status_raw = clean_cell(status_raw)
  note_cell  = clean_cell(note_cell)

  status = ""
  out_note = note_cell
  rest = ""

  if (status_raw != "") {
    if (match(status_raw, /(works|detected|fixed|limited|malfunc|failed|disabled|unknown|n\/a)\b/)) {
      status = substr(status_raw, RSTART, RLENGTH)
      rest   = trim(substr(status_raw, RSTART + RLENGTH + 1))
      if (out_note == "" && rest != "")
        out_note = rest
    } else {
      status = status_raw
    }
  }

  if (status == "") status = "<none>"
  if (out_note == "") out_note = "<none>"

  ps_note = out_note

  return status
}