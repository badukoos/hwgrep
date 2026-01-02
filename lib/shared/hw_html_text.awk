BEGIN {
  in_script = 0
  in_style  = 0

  hw_mode   = (hw_mode ? hw_mode : "")
  seen_log  = 0
  stop_out  = 0
}

function starts_block(s, tag, x) {
  x = tolower(s)
  return (x ~ ("<" tag "([[:space:]>]|$)"))
}

function ends_block(s, tag, x) {
  x = tolower(s)
  return (x ~ ("</" tag "([[:space:]>]|$)"))
}

function filter_text(t) {
  sub(/^[[:space:]]+/, "", t)
  sub(/[[:space:]]+$/, "", t)
  if (t == "") return

  if (hw_mode == "log") {
    if (stop_out) return
    if (!seen_log) {
      if (t ~ /^Log:[[:space:]]*/) seen_log = 1
      else return
    }

    if (t ~ /^Hardware for Linux( and BSD)?$/) { stop_out = 1; return }
  }

  print t
}

{
  line = $0

  if (starts_block(line, "script")) in_script = 1
  if (in_script) {
    if (ends_block(line, "script")) in_script = 0
    next
  }

  if (starts_block(line, "style")) in_style = 1
  if (in_style) {
    if (ends_block(line, "style")) in_style = 0
    next
  }

  gsub(/<[Tt][Dd][^>]*style=['"][^'"]*text-decoration[[:space:]]*:[[:space:]]*line-through[^'"]*['"][^>]*>[^<]*<\/[Tt][Dd][[:space:]]*>/, "", line)
  gsub(/<[Bb][Rr][[:space:]]*\/?>/, "\n", line)
  gsub(/&nbsp;/, " ", line)
  gsub(/&[A-Za-z0-9#]+;/, "", line)
  gsub(/<[^>]*>/, "", line)

  n = split(line, parts, /\n/)
  for (i = 1; i <= n; i++) {
    filter_text(parts[i])
  }
}