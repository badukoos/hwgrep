function trim(s) {
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
  return s
}

function append_log(cat, entry, t) {
  t = trim(entry)
  if (t == "") return

  if (cat_logs[cat] == "") {
    cat_logs[cat] = t
  } else {
    cat_logs[cat] = cat_logs[cat] ", " t
  }
}

BEGIN {
  in_logs = 0
  current_cat = ""
  order_count = 0

  known["Board"]      = 1
  known["Boot"]       = 1
  known["CPU"]        = 1
  known["Drive"]      = 1
  known["Filesystem"] = 1
  known["Graphics"]   = 1
  known["Input"]      = 1
  known["Kernel"]     = 1
  known["Modules"]    = 1
  known["Network"]    = 1
  known["PCI"]        = 1
  known["Processes"]  = 1
  known["Sound"]      = 1
  known["System"]     = 1
  known["USB"]        = 1
  known["Wireless"]   = 1
}

/^Logs[[:space:]]*\([0-9]+\)/ {
  in_logs = 1
  next
}

{
  if (!in_logs) next

  line = trim($0)
  if (line == "") next

  if (line ~ /^Export template to forum/ ||
      line ~ /^Find compatible parts/ ||
      line ~ /^How it fits BSD/ ||
      line ~ /^Hardware for /) {
    in_logs = 0
    next
  }

  n = split(line, parts, /[[:space:]]+/)
  cat = parts[1]

  if (cat in known) {
    current_cat = cat

    if (!(cat in seen_cat)) {
      order[++order_count] = cat
      seen_cat[cat] = 1
    }

    rest = substr(line, length(cat) + 2)
    rest = trim(rest)
    if (rest != "") append_log(cat, rest)
  } else if (current_cat != "") {
    append_log(current_cat, line)
  }
}

END {
  if (order_count == 0) exit

  maxw = 0
  for (i = 1; i <= order_count; i++) {
    cat = order[i]
    if (length(cat) > maxw) maxw = length(cat)
  }

  print "Logs"
  for (i = 1; i <= order_count; i++) {
    cat = order[i]
    printf("  %-" maxw "s : %s\n", cat, cat_logs[cat])
  }
}
