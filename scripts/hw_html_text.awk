BEGIN {
  in_script = 0
  in_style  = 0
}

{
  line = $0

  if (line ~ /<[Ss][Cc][Rr][Ii][Pp][Tt][^>]*>/) in_script = 1
  if (in_script) {
    if (line ~ /<\/[Ss][Cc][Rr][Ii][Pp][Tt]>/) in_script = 0
    next
  }

  if (line ~ /<[Ss][Tt][Yy][Ll][Ee][^>]*>/) in_style = 1
  if (in_style) {
    if (line ~ /<\/[Ss][Tt][Yy][Ll][Ee]>/) in_style = 0
    next
  }

  gsub(/<[Bb][Rr][[:space:]]*\/?>/, "\n", line)
  gsub(/&nbsp;/, " ", line)
  gsub(/&[A-Za-z0-9#]+;/, "", line)
  gsub(/<[^>]*>/, "", line)

  n = split(line, parts, /\n/)
  for (i = 1; i <= n; i++) {
    t = parts[i]
    if (t ~ /^[[:space:]]*$/) continue
    print t
  }
}
