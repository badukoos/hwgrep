function row_filter_init(s, n, i, clause, eq, k, v, key, m, j, t) {
  if (rf_init) return
  rf_init = 1

  delete rf_keys
  delete rf_tok
  delete rf_ntok

  s = row_filter
  gsub(/\r/, "", s)
  if (trim(s) == "") return

  n = split(s, rf_clause, /[\n;]/)
  for (i = 1; i <= n; i++) {
    clause = trim(rf_clause[i])
    if (clause == "") continue

    eq = index(clause, "=")
    if (eq <= 1) continue

    k = trim(substr(clause, 1, eq - 1))
    v = trim(substr(clause, eq + 1))

    if (k == "" || v == "") continue

    key = tolower(k)

    rf_keys[key] = 1
    m = split(v, rf_val, /[|,]/)
    for (j = 1; j <= m; j++) {
      t = tolower(trim(rf_val[j]))
      if (t == "") continue
      rf_ntok[key]++
      rf_tok[key, rf_ntok[key]] = t
    }
  }
}

function row_filter_value_match(key, val, v, i, tok) {
  if (!rf_init) row_filter_init()
  if (length(rf_keys) == 0) return 1
  if (!(key in rf_keys)) return 1

  v = tolower(trim(val))

  for (i = 1; i <= rf_ntok[key]; i++) {
    tok = rf_tok[key, i]
    if (tok == "") continue

    if (key == "status") {
      if (v == tok) return 1
    } else {
      if (index(v, tok) > 0) return 1
    }
  }
  return 0
}

function row_filter_row_match(row, key, val) {
  if (!rf_init) row_filter_init()

  if (length(rf_keys) == 0) return 1

  for (key in rf_keys) {
    val = (key in row ? row[key] : "")
    if (!row_filter_value_match(key, val)) return 0
  }
  return 1
}
