#!/bin/bash
# gate-ledger.sh — append-only record of gate crossings and proof-of-done.
# The ship-gate hook reads this; stats.sh projects over it. One line per event:
#   <iso8601> | <kind> | <spec> | <ref> | <note>
#
# Usage:
#   gate-ledger.sh record <kind> <spec> <ref> [note]   # append an event
#   gate-ledger.sh proof <spec> <commit-or-verify-ref>  # write a proof-of-done row
#   gate-ledger.sh has-proof <ref>                       # exit 0 if a proof row exists for <ref>
#   gate-ledger.sh path                                  # print the ledger file path

set -euo pipefail

_dir() {
  local here; here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  bash "$here/lib/config/vlkit-config.sh" logdir 2>/dev/null || echo "$HOME/.claude/vlkit/logs"
}
LEDGER="$(_dir)/gate-ledger.log"

_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

cmd_record() {  # <kind> <spec> <ref> [note]
  mkdir -p "$(dirname "$LEDGER")"
  printf '%s | %s | %s | %s | %s\n' "$(_ts)" "${1:-}" "${2:-}" "${3:-}" "${4:-}" >> "$LEDGER"
}

cmd_proof() {   # <spec> <ref>
  cmd_record proof-of-done "${1:-}" "${2:-}" "verified"
}

cmd_has_proof() {  # <ref>
  local ref="${1:-}"
  [ -n "$ref" ] || return 1
  [ -f "$LEDGER" ] || return 1
  grep -qE "\| proof-of-done \|.*\| ${ref} \|" "$LEDGER"
}

case "${1:-}" in
  record)    shift; cmd_record "$@" ;;
  proof)     shift; cmd_proof "$@" ;;
  has-proof) shift; cmd_has_proof "$@" ;;
  path)      echo "$LEDGER" ;;
  *) echo "usage: gate-ledger.sh {record|proof|has-proof|path} ..." >&2; exit 1 ;;
esac
