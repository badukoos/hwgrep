#!/usr/bin/env bash
hw_resolve_root() {
  if [ -n "${HWGREP_ROOT:-}" ]; then
    printf '%s\n' "${HWGREP_ROOT}"
    return 0
  fi

  local script_dir="${1:?missing script_dir}"

  if [ -d "${script_dir}/lib" ]; then
    printf '%s\n' "${script_dir}"
    return 0
  fi

  if [ -d "${script_dir}/../lib" ]; then
    (cd "${script_dir}/.." && pwd)
    return 0
  fi

  (cd "${script_dir}/.." && pwd)
}

hw_init_env() {
  local caller_dir
  caller_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"

  ROOT_DIR="$(hw_resolve_root "${caller_dir}")"
  LIB_DIR="${ROOT_DIR}/lib"
  SCRIPTS_DIR="${ROOT_DIR}/scripts"

  export ROOT_DIR LIB_DIR SCRIPTS_DIR
}
