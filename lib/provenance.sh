#!/bin/bash
# provenance.sh — a machine-checkable trace for a spec, built from the gate
# ledger: which tasks ran, on which model, for how long, and the proof-of-done
# commit that opened the ship-gate. Markdown by default, JSON with --json.
#
# Usage: provenance.sh <spec> [--json]

set -euo pipefail
SPEC="${1:?usage: provenance.sh <spec> [--json]}"
JSON=0; [ "${2:-}" = "--json" ] && JSON=1

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEDGER="$(bash "$HERE/lib/gate/gate-ledger.sh" path 2>/dev/null || echo "")"
[ -n "$LEDGER" ] && [ -f "$LEDGER" ] || { echo "provenance: no ledger for $SPEC" >&2; exit 1; }

awk -v FS=' \\| ' -v spec="$SPEC" -v json="$JSON" '
  function fmt(d){ if(d<0)d=0; if(d>=60) return int(d/60) "m " (d%60) "s"; return d "s" }
  {
    kind=$2; s=$3; task=$4; note=$5
    if (s!=spec) next
    if (kind=="run-start") {
      ep=note; sub(/.*epoch=/,"",ep); sub(/[^0-9].*/,"",ep)
      md=note; if (md ~ /model=/){ sub(/.*model=/,"",md); sub(/;.*/,"",md) } else md="?"
      if (!(task in seenT)){ order[++n]=task; seenT[task]=1 }
      start[task]=ep+0; model[task]=md
      delete end[task]   # retry: drop any stale run-end so it never pairs with this newer start
    } else if (kind=="run-end") {
      ep=note; sub(/.*epoch=/,"",ep); sub(/[^0-9].*/,"",ep); end[task]=ep+0
      if (!(task in seenT)){ order[++n]=task; seenT[task]=1 }   # orphan run-end still shows
    } else if (kind=="proof-of-done") {
      commit=task
    }
  }
  END {
    if (json) {
      printf "{\"spec\":\"%s\",\"tasks\":[", spec
      first=1
      for(i=1;i<=n;i++){ t=order[i]; d=((t in start)&&(t in end))?end[t]-start[t]:0; if(d<0)d=0
        printf "%s{\"task\":\"%s\",\"model\":\"%s\",\"duration_s\":%d}", (first?"":","), t, (t in model?model[t]:"?"), d; first=0 }
      printf "],\"proof_commit\":\"%s\"}\n", commit
    } else {
      print "# Provenance: " spec
      print ""
      print "| task | model | duration |"
      print "|---|---|---|"
      for(i=1;i<=n;i++){ t=order[i]; d=((t in start)&&(t in end))?end[t]-start[t]:0
        printf "| %s | %s | %s |\n", t, (t in model?model[t]:"?"), fmt(d) }
      print ""
      printf "Proof-of-done: %s\n", (commit==""?"(none)":commit)
      printf "Verdict: %s\n", (commit==""?"UNPROVEN":"shipped (proof recorded)")
    }
  }
' "$LEDGER"
