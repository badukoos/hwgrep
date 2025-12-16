function wrap(str, width, out,
              i, n, words, w, wlen,
              line, len, idx) {

  for (i in out) delete out[i]

  str = trim(str)
  if (str == "") {
    out[1] = ""
    return 1
  }

  n = split(str, words, /[[:space:]]+/)
  line = ""
  len = 0
  idx = 1

  for (i = 1; i <= n; i++) {
    w = words[i]
    wlen = length(w)

    if (len == 0) {
      if (wlen <= width) {
        line = w
        len = wlen
      } else {
        while (wlen > width) {
          out[idx++] = substr(w, 1, width)
          w    = substr(w, width + 1)
          wlen = length(w)
        }
        if (wlen > 0) {
          line = w
          len = wlen
        }
      }
    } else {
      if (len + 1 + wlen <= width) {
        line = line " " w
        len  = len + 1 + wlen
      } else {
        out[idx++] = line
        line = ""
        len = 0
        i--
      }
    }
  }

  if (len > 0)
    out[idx++] = line

  return idx - 1
}
