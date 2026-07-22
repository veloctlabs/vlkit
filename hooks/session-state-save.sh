#!/bin/bash
# session-state-save.sh — Stop / SubagentStop. Persists a small progress snapshot
# to <project>/.vlkit/state.json. Never blocks. Best-effort; fail-open silently.

set -euo pipefail
INPUT=$(cat 2>/dev/null || true)

git rev-parse --show-toplevel >/dev/null 2>&1 || exit 0   # only inside a repo
DIR="$(pwd)/.vlkit"
mkdir -p "$DIR" 2>/dev/null || exit 0

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
HEAD=$(git rev-parse --short HEAD 2>/dev/null || echo none)
DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# jq builds valid JSON; fall back to a plain heredoc if jq is somehow absent.
if command -v jq >/dev/null 2>&1; then
  jq -n --arg ts "$TS" --arg b "$BRANCH" --arg h "$HEAD" --arg d "$DIRTY" \
    '{updated_at:$ts, branch:$b, head:$h, dirty_files:($d|tonumber)}' > "$DIR/state.json" 2>/dev/null || true
else
  printf '{"updated_at":"%s","branch":"%s","head":"%s","dirty_files":%s}\n' "$TS" "$BRANCH" "$HEAD" "$DIRTY" > "$DIR/state.json"
fi
exit 0
