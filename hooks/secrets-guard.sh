#!/bin/bash
# secrets-guard.sh — PreToolUse(Read|Edit|Bash). Blocks access to secret files.
# Contract: stdin = event JSON; exit 2 = block; exit 0 = allow. Fail-open.

set -euo pipefail

INPUT=$(cat)
LOG_DIR="${VLKIT_LOG_DIR:-$HOME/.claude/vlkit/logs}"

block() {  # <path>
  mkdir -p "$LOG_DIR"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | BLOCKED | secrets | $(pwd) | $1" >> "$LOG_DIR/secrets-guard.log"
  echo "BLOCKED by vlkit secrets-guard: access to a secret file ($1) is not allowed" >&2
  exit 2
}

# Collect candidate paths from Read/Edit file_path and from a Bash command line.
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
CANDS=$(printf '%s' "$INPUT" | jq -r '
  [ .tool_input.file_path?, .tool_input.path?, .tool_input.command? ] | map(select(. != null)) | .[]' 2>/dev/null || true)
[ -z "$CANDS" ] && exit 0

# Secret path patterns (basename or path fragment).
PAT='(^|/)\.env($|\.)|(^|/)\.ssh/|(^|/)\.aws/|(^|/)\.gnupg/|\.pem($| )|\.p12($| )|\.pfx($| )|(^|/)\.git-credentials|(^|/)\.npmrc|id_rsa|id_ed25519'

while IFS= read -r c; do
  [ -z "$c" ] && continue
  printf '%s' "$c" | grep -qiE "$PAT" && block "$c"
done <<EOF
$CANDS
EOF

exit 0
