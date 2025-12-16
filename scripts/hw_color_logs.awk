BEGIN {
  red = "\033[31m"
  yellow = "\033[33m"
  reset = "\033[0m"

  if (enable_color == 0) force_no_color = 1
  if ("NO_COLOR" in ENVIRON && ENVIRON["NO_COLOR"] != "") force_no_color = 1
}

function has_word(re, l) {
  return (l ~ ("(^|[[:space:][:punct:]])" re "([[:space:][:punct:]]|$)"))
}

function is_error(l) {
  if (has_word("error(s)?", l)) return 1
  if (has_word("fail(ed|ure)?", l)) return 1
  if (has_word("fault(s)?", l)) return 1
  if (l ~ /timed out/) return 1
  if (has_word("timeout(s)?", l)) return 1
  if (l ~ /i\/o error/) return 1
  if (has_word("corrupt(ion)?", l)) return 1
  if (has_word("panic", l)) return 1
  if (has_word("segfault", l)) return 1
  return 0
}

function is_warn(l) {
  if (l ~ /warning:/) return 1
  return 0
}

{
  if (force_no_color) {
    print $0
    next
  }

  l = tolower($0)
  if (is_error(l)) print red $0 reset
  else if (is_warn(l)) print yellow $0 reset
  else print $0
}
