#!/bin/bash
# statusline.sh — statusLine renderer. Prints one line: repo/branch, lane, and a
# context-budget bar. This is the one hook allowed to be liberal (off safety path).

set -euo pipefail
INPUT=$(cat 2>/dev/null || true)

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "-")
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")

# Lane from the newest DRAFT spec header, if any.
LANE="-"
if [ -d docs/specs ]; then
  latest=$(ls -t docs/specs/SPEC-*.md 2>/dev/null | head -1 || true)
  [ -n "$latest" ] && LANE=$(grep -iE '^Lane:' "$latest" 2>/dev/null | head -1 | sed -E 's/^Lane:[[:space:]]*//' || echo "-")
fi

# Context budget, if Claude Code provides token counts in the payload.
CTX=""
if command -v jq >/dev/null 2>&1; then
  used=$(printf '%s' "$INPUT" | jq -r '.cost.total_tokens // .context.used // empty' 2>/dev/null || true)
  [ -n "$used" ] && CTX=" · ctx ${used}"
fi

printf 'vlkit ⟨%s:%s⟩ lane:%s%s\n' "$REPO" "$BRANCH" "${LANE:--}" "$CTX"
