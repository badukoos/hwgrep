function trim(s) {
  gsub(/^[ \t]+|[ \t]+$/, "", s)
  return s
}

function clean_ws(s) {
  gsub(/\r/, " ", s)
  gsub(/\n/, " ", s)
  gsub(/\t/, " ", s)
  s = trim(s)
  gsub(/[[:space:]]+/, " ", s)
  return s
}

function is_none(s, t) {
  t = tolower(trim(s))
  return (t == "" || t == "<none>" || t == "none")
}
