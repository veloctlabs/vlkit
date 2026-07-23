#!/bin/bash
# waves.sh — parse a spec's ## Tasks and print dependency waves (Kahn grouping).
# A task line: `<n>. [weight]? <name> (deps: a b)? — ...`. Output one line per
# wave: `wave <n>: <id> <id> ...` (ids ascending). Cycle → stderr + non-zero.
#
# Usage: waves.sh <spec-file>

set -euo pipefail
SPEC="${1:?usage: waves.sh <spec-file>}"
[ -f "$SPEC" ] || { echo "waves.sh: no such spec: $SPEC" >&2; exit 1; }

awk '
  /^##[[:space:]]+Tasks/ { intask=1; next }
  /^##[[:space:]]/       { intask=0 }
  intask && /^[0-9]+\./ {
    line=$0
    id=line; sub(/\..*/,"",id); id=id+0
    ids[++cnt]=id
    d=""
    if (match(line, /\(deps:?[[:space:],0-9 \t]+\)/)) {
      d=substr(line,RSTART,RLENGTH); gsub(/[^0-9]+/," ",d)
    }
    deps[id]=d
  }
  END {
    if (cnt==0){ print "waves.sh: no tasks found" > "/dev/stderr"; exit 2 }
    total=cnt; emitted=0; wave=0
    for(;;){
      nready=0
      for(i=1;i<=cnt;i++){ id=ids[i]; if(done[id]) continue
        ok=1; n=split(deps[id],dd," ")
        for(j=1;j<=n;j++){ if(dd[j]!="" && !done[dd[j]+0]){ ok=0; break } }
        if(ok) ready[++nready]=id
      }
      if(nready==0){
        if(emitted<total){ print "waves.sh: dependency cycle among remaining tasks" > "/dev/stderr"; exit 3 }
        break
      }
      for(a=2;a<=nready;a++){ key=ready[a]; b=a-1; while(b>=1 && ready[b]>key){ ready[b+1]=ready[b]; b-- } ready[b+1]=key }
      wave++
      out="wave " wave ":"
      for(a=1;a<=nready;a++){ out=out " " ready[a]; done[ready[a]]=1; emitted++ }
      print out
    }
  }
' "$SPEC"
