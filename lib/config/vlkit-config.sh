#!/bin/bash
# vlkit-config.sh — the ONE config resolver. Commands and libs call it at
# invocation time. Hot-path hooks must NOT source this (keeps hooks config-free).
#
# Usage:  bash lib/config/vlkit-config.sh get <section.key> [fallback]
# Example: bash lib/config/vlkit-config.sh get ledger.location shared
#
# Precedence: <project>/.vlkit.toml  >  installed vlkit.toml  >  <fallback arg>.
# Parser is a deliberately tiny TOML reader: [section] headers + `key = "value"`
# / `key = value` lines. No arrays, no nesting — matches vlkit.toml's shape.

set -euo pipefail

VLKIT_ROOT="${VLKIT_ROOT:-$HOME/.claude/vlkit}"

_read_toml_key() {  # <file> <section> <key>
  local file="$1" section="$2" key="$3"
  [ -f "$file" ] || return 1
  awk -v sect="$section" -v k="$key" '
    /^[ \t]*#/ { next }
    /^[ \t]*\[/ {
      cur = $0; gsub(/[ \t]*\[|\][ \t]*/, "", cur); next
    }
    {
      line = $0
      sub(/[ \t]*#.*$/, "", line)                 # strip trailing comment
      if (cur != sect) next
      n = index(line, "=")
      if (n == 0) next
      lk = substr(line, 1, n - 1); gsub(/[ \t]/, "", lk)
      if (lk != k) next
      v = substr(line, n + 1)
      gsub(/^[ \t]+|[ \t]+$/, "", v)              # trim
      gsub(/^"|"$/, "", v)                        # unquote
      print v; found = 1; exit
    }
    END { if (!found) exit 1 }
  ' "$file"
}

cmd_get() {
  local dotted="$1" fallback="${2:-}"
  local section="${dotted%%.*}" key="${dotted#*.}"
  local val
  if val=$(_read_toml_key "$(pwd)/.vlkit.toml" "$section" "$key" 2>/dev/null); then
    printf '%s\n' "$val"; return 0
  fi
  if val=$(_read_toml_key "$VLKIT_ROOT/vlkit.toml" "$section" "$key" 2>/dev/null); then
    printf '%s\n' "$val"; return 0
  fi
  printf '%s\n' "$fallback"
}

# Resolve where the ledger/logs live for the current project.
cmd_logdir() {
  local loc
  loc=$(cmd_get ledger.location shared)
  if [ "$loc" = "isolated" ]; then
    printf '%s\n' "$(pwd)/.vlkit/logs"
  else
    printf '%s\n' "${VLKIT_LOG_DIR:-$HOME/.claude/vlkit/logs}"
  fi
}

case "${1:-}" in
  get)     shift; cmd_get "$@" ;;
  logdir)  cmd_logdir ;;
  *) echo "usage: vlkit-config.sh {get <section.key> [fallback] | logdir}" >&2; exit 1 ;;
esac
