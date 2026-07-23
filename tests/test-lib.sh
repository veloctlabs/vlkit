#!/bin/bash
# test-lib.sh — lib/ behavior: model resolution, run ledger, timeline.
# No Claude Code required.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VLKIT_ROOT="$HERE"
export VLKIT_LOG_DIR="$(mktemp -d)"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
eq()  { if [ "$2" = "$3" ]; then ok; else bad "$1 — want [$3] got [$2]"; fi; }

CFG="$HERE/lib/config/vlkit-config.sh"
LED="$HERE/lib/gate/gate-ledger.sh"
STATS="$HERE/lib/stats/stats.sh"

echo "config model resolution:"
eq "model heavy → opus"        "$(bash "$CFG" model heavy)"   "opus"
eq "model light → sonnet"      "$(bash "$CFG" model light)"   "sonnet"
eq "unknown weight → default"  "$(bash "$CFG" model bogus)"   "sonnet"
# no config anywhere → hardcoded sonnet
eq "no config → sonnet"        "$(cd "$VLKIT_LOG_DIR" && VLKIT_ROOT="$VLKIT_LOG_DIR" bash "$CFG" model heavy)" "sonnet"

echo "run ledger:"
bash "$LED" run-start SPEC-T taskA opus
bash "$LED" run-end   SPEC-T taskA
LEDGER="$(bash "$LED" path)"
grep -qE '\| run-start \| SPEC-T \| taskA \| model=opus;epoch=[0-9]+' "$LEDGER" && ok || bad "run-start row missing/malformed"
grep -qE '\| run-end \| SPEC-T \| taskA \| epoch=[0-9]+' "$LEDGER" && ok || bad "run-end row missing/malformed"

echo "timeline:"
OUT="$(bash "$STATS" timeline)"
printf '%s' "$OUT" | grep -q 'taskA' && ok || bad "timeline missing task row"
printf '%s' "$OUT" | grep -q 'opus'  && ok || bad "timeline missing model"
printf '%s' "$OUT" | grep -q '^wall'               && ok || bad "timeline missing wall summary"
printf '%s' "$OUT" | grep -q '^worker'             && ok || bad "timeline missing worker summary"
printf '%s' "$OUT" | grep -q '^parallel_potential' && ok || bad "timeline missing parallel_potential"

echo "timeline spec filter (unknown spec → no completed runs):"
bash "$STATS" timeline SPEC-NONE | grep -q 'no completed runs' && ok || bad "spec filter did not isolate"

rm -rf "$VLKIT_LOG_DIR"
echo "-----------------------------------------"
echo "lib: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
