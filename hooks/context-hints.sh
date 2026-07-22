#!/bin/bash
# context-hints.sh — UserPromptSubmit. Advisory: inject keyword-matched hints
# from vlkit.toml [hints]. Never blocks. Prints hints on stdout (added to context).

set -euo pipefail
INPUT=$(cat 2>/dev/null || true)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
[ -z "$PROMPT" ] && exit 0

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG="$HERE/lib/config/vlkit-config.sh"

# [hints] is a flat keyword=text map; read raw lines from the resolved toml.
# We scan both project and installed toml via a tiny inline reader.
emit_from() {  # <tomlfile>
  local f="$1"; [ -f "$f" ] || return 0
  awk '
    /^[ \t]*\[hints\]/ { inh=1; next }
    /^[ \t]*\[/ { inh=0 }
    inh && /=/ {
      line=$0; sub(/[ \t]*#.*$/,"",line)
      n=index(line,"="); if(!n) next
      k=substr(line,1,n-1); gsub(/[ \t"]/,"",k)
      v=substr(line,n+1); gsub(/^[ \t]+|[ \t]+$/,"",v); gsub(/^"|"$/,"",v)
      if(k!="") print k "\t" v
    }' "$f"
}

MAP=$( { emit_from "$(pwd)/.vlkit.toml"; emit_from "$HOME/.claude/vlkit/vlkit.toml"; } 2>/dev/null )
[ -z "$MAP" ] && exit 0

shown=0
while IFS=$'\t' read -r kw text; do
  [ -z "$kw" ] && continue
  if printf '%s' "$PROMPT" | grep -qiF "$kw"; then
    [ "$shown" -eq 0 ] && { echo "## vlkit hints"; shown=1; }
    echo "- ($kw) $text"
  fi
done <<EOF
$MAP
EOF
exit 0
