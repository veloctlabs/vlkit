#!/bin/bash
# commit-format.sh — PreToolUse(Bash). Enforces conventional commit subjects.
# Only inspects `git commit -m ...` segments. exit 2 = block. Fail-open.

set -euo pipefail

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[ -z "$CMD" ] && exit 0
printf '%s' "$CMD" | grep -qE 'git[[:space:]]+commit' || exit 0

LOG_DIR="${VLKIT_LOG_DIR:-$HOME/.claude/vlkit/logs}"
block() {
  mkdir -p "$LOG_DIR"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | BLOCKED | commit-format | $(pwd) | $1" >> "$LOG_DIR/commit-format.log"
  echo "BLOCKED by vlkit commit-format: $1" >&2
  echo "Use: type(scope?): subject  — e.g. 'feat(auth): add refresh flow'  (<=72 chars)" >&2
  exit 2
}

# Extract the -m / --message subject. Try double-quoted, then single-quoted,
# then a bare token. First non-empty wins.
SUBJECT=$(printf '%s' "$CMD" | sed -nE 's/.*(-m|--message)[[:space:]]+"([^"]*)".*/\2/p' | head -1)
[ -z "$SUBJECT" ] && SUBJECT=$(printf '%s' "$CMD" | sed -nE "s/.*(-m|--message)[[:space:]]+'([^']*)'.*/\2/p" | head -1)
[ -z "$SUBJECT" ] && SUBJECT=$(printf '%s' "$CMD" | sed -nE 's/.*(-m|--message)[[:space:]]+([^[:space:]]+).*/\2/p' | head -1)
[ -z "$SUBJECT" ] && exit 0   # no -m (interactive editor) — let it through

TYPES='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'
printf '%s' "$SUBJECT" | grep -qE "^($TYPES)(\([a-z0-9._-]+\))?!?: .+" \
  || block "non-conventional subject: '$SUBJECT'"

LEN=$(printf '%s' "$SUBJECT" | wc -c | tr -d ' ')
[ "$LEN" -gt 72 ] && block "subject too long ($LEN > 72): '$SUBJECT'"

exit 0
