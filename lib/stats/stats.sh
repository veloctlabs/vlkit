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

timeline() {  # [spec]
  local spec_filter="${1:-}"
  [ -f "$LEDGER" ] || { echo "no ledger yet ($LEDGER)"; return 0; }
  awk -v FS=' \\| ' -v specf="$spec_filter" '
    function fmt(d,   m,s){ if(d<0)d=0; m=int(d/60); s=d%60; if(m>0) return m "m " s "s"; return s "s" }
    {
      kind=$2; spec=$3; task=$4; note=$5
      if (specf!="" && spec!=specf) next
      key=spec SUBSEP task
      if (kind=="run-start") {
        ep=note; sub(/.*epoch=/,"",ep); sub(/[^0-9].*/,"",ep)
        md=note; if (md ~ /model=/){ sub(/.*model=/,"",md); sub(/;.*/,"",md) } else md="?"
        start[key]=ep+0; model[key]=md
        if (!(key in seen)){ order[++n]=key; seen[key]=1 }
      } else if (kind=="run-end") {
        ep=note; sub(/.*epoch=/,"",ep); sub(/[^0-9].*/,"",ep)
        end[key]=ep+0
        if (!(key in seen)){ order[++n]=key; seen[key]=1 }
      }
    }
    END {
      maxd=0; sum=0; have=0
      for(i=1;i<=n;i++){ k=order[i]; if((k in start) && (k in end)){ d=end[k]-start[k]; if(d>maxd)maxd=d;
        if(!have||start[k]<mins)mins=start[k]; if(!have||end[k]>maxe)maxe=end[k]; sum+=d; have=1 } }
      if(!have){ print "no completed runs in ledger"; exit }
      print "vlkit timeline" (specf!=""?" ("specf")":"")
      print "-----------------------------------------"
      for(i=1;i<=n;i++){ k=order[i]; if(!((k in start) && (k in end))) continue
        d=end[k]-start[k]; split(k,kp,SUBSEP); task=kp[2]
        w=(maxd>0)?int(d/maxd*24):1; if(w<1)w=1
        bar=""; for(j=0;j<w;j++)bar=bar "#"
        printf "%-18s %-8s %-9s %s\n", task, model[k], fmt(d), bar
      }
      print "-----------------------------------------"
      printf "wall               : %s\n", fmt(maxe-mins)
      printf "worker             : %s\n", fmt(sum)
      printf "parallel_potential : %s\n", fmt(maxd)
    }
  ' "$LEDGER"
}

case "${1:-summary}" in
  summary)  summary ;;
  timeline) shift; timeline "$@" ;;
  *) echo "usage: stats.sh [summary|timeline [spec]]" >&2; exit 1 ;;
esac
