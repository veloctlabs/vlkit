#!/bin/bash
# test-provenance.sh — lib/provenance.sh trace from a seeded ledger.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VLKIT_ROOT="$HERE"
export VLKIT_LOG_DIR="$(mktemp -d)"
PROV="$HERE/lib/provenance.sh"
LED="$HERE/lib/gate/gate-ledger.sh"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

# Seed a run + proof for SPEC-X.
bash "$LED" run-start SPEC-X taskA opus
bash "$LED" run-end   SPEC-X taskA
bash "$LED" proof     SPEC-X deadbee

echo "markdown trace:"
OUT="$(bash "$PROV" SPEC-X)"
printf '%s' "$OUT" | grep -q 'SPEC-X'  && ok || bad "markdown missing spec id"
printf '%s' "$OUT" | grep -q 'taskA'   && ok || bad "markdown missing task"
printf '%s' "$OUT" | grep -q 'opus'    && ok || bad "markdown missing model"
printf '%s' "$OUT" | grep -q 'deadbee' && ok || bad "markdown missing proof commit"
printf '%s' "$OUT" | grep -q 'shipped' && ok || bad "markdown missing shipped verdict"

echo "json trace:"
J="$(bash "$PROV" SPEC-X --json)"
printf '%s' "$J" | jq empty 2>/dev/null && ok || bad "json does not parse"
[ "$(printf '%s' "$J" | jq -r '.spec')" = "SPEC-X" ] && ok || bad "json spec wrong"
[ "$(printf '%s' "$J" | jq -r '.tasks[0].model')" = "opus" ] && ok || bad "json model wrong"
[ "$(printf '%s' "$J" | jq -r '.proof_commit')" = "deadbee" ] && ok || bad "json proof wrong"

echo "retry (duplicate run-start) never yields a negative duration, md==json:"
# Mirrors the execute fix-agent retry loop: a task run-starts twice.
bash "$LED" run-start SPEC-R taskR opus     # attempt 1 start
bash "$LED" run-end   SPEC-R taskR          # attempt 1 end
bash "$LED" run-start SPEC-R taskR sonnet    # retry start (no matching end yet)
bash "$LED" proof     SPEC-R cafe123
RJSON="$(bash "$PROV" SPEC-R --json)"
RDUR="$(printf '%s' "$RJSON" | jq -r '.tasks[0].duration_s')"
[ "$RDUR" -ge 0 ] 2>/dev/null && ok || bad "retry produced negative/invalid duration_s: $RDUR"
printf '%s' "$RJSON" | jq empty 2>/dev/null && ok || bad "retry json invalid"
# markdown must agree (also non-negative)
bash "$PROV" SPEC-R | grep -qE '\| taskR \| sonnet \| [0-9]' && ok || bad "retry markdown shows wrong model/duration"

echo "orphan run-end (no run-start) still appears:"
bash "$LED" run-end SPEC-O orphanTask
bash "$PROV" SPEC-O | grep -q 'orphanTask' && ok || bad "orphan run-end dropped from trace"

echo "unproven spec (no proof row):"
bash "$LED" run-start SPEC-Y taskB sonnet
bash "$LED" run-end   SPEC-Y taskB
bash "$PROV" SPEC-Y | grep -q 'UNPROVEN' && ok || bad "no-proof spec should be UNPROVEN"

echo "-----------------------------------------"
echo "provenance: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
