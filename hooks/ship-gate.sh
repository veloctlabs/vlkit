#!/bin/bash
# ship-gate.sh — PreToolUse(Bash). Blocks push / PR-create when the gate ledger
# has no proof-of-done row for the current HEAD. exit 2 = block. Fail-open.
# Escape hatch: set VLKIT_SHIP_OVERRIDE=1 for a deliberate manual push.

set -euo pipefail

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[ -z "$CMD" ] && exit 0

# Only guard actual publish actions.
printf '%s' "$CMD" | grep -qE 'git[[:space:]]+push|gh[[:space:]]+pr[[:space:]]+create' || exit 0

[ "${VLKIT_SHIP_OVERRIDE:-0}" = "1" ] && exit 0

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HEAD=$(git rev-parse --short HEAD 2>/dev/null || true)
[ -z "$HEAD" ] && exit 0   # not a git repo / no commits — nothing to gate

if bash "$HERE/lib/gate/gate-ledger.sh" has-proof "$HEAD" 2>/dev/null; then
  exit 0
fi

LOG_DIR="${VLKIT_LOG_DIR:-$HOME/.claude/vlkit/logs}"
mkdir -p "$LOG_DIR"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | BLOCKED | ship-gate | $(pwd) | $HEAD" >> "$LOG_DIR/ship-gate.log"
echo "BLOCKED by vlkit ship-gate: no proof-of-done recorded for HEAD ($HEAD)." >&2
echo "Run the verify + ship flow (/vlkit:ship) so a proof row is written, or set VLKIT_SHIP_OVERRIDE=1 to override deliberately." >&2
exit 2
