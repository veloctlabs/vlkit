#!/bin/bash
# stats.sh — read-only projection over the gate ledger and hook logs.
# Never writes. Usage: stats.sh [summary]

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOGDIR="$(bash "$HERE/lib/config/vlkit-config.sh" logdir 2>/dev/null || echo "$HOME/.claude/vlkit/logs")"
LEDGER="$LOGDIR/gate-ledger.log"

summary() {
  echo "vlkit stats  (ledger: $LEDGER)"
  echo "-----------------------------------------"
  if [ -f "$LEDGER" ]; then
    printf "gate events        : %s\n" "$(wc -l < "$LEDGER" | tr -d ' ')"
    printf "proof-of-done rows : %s\n" "$(grep -c '| proof-of-done |' "$LEDGER" 2>/dev/null || echo 0)"
  else
    echo "no ledger yet"
  fi
  local blocked=0 f
  for f in "$LOGDIR"/safety-gate.log "$LOGDIR"/secrets-guard.log "$LOGDIR"/ship-gate.log "$LOGDIR"/commit-format.log; do
    [ -f "$f" ] && blocked=$(( blocked + $(wc -l < "$f" | tr -d ' ') ))
  done
  printf "blocked actions    : %s\n" "$blocked"
}

case "${1:-summary}" in
  summary) summary ;;
  *) echo "usage: stats.sh [summary]" >&2; exit 1 ;;
esac
