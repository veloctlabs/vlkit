#!/bin/bash
# safety-gate.sh — PreToolUse(Bash). Blocks destructive commands.
# Contract: stdin = event JSON; exit 2 = block (stderr = reason); exit 0 = allow.
# Parse-aware: strip heredoc bodies, split compounds on && || ; | and newlines,
# then key each rule on the segment's actual first word (argv), never on prose.
# Fail-open on internal error (a broken safety hook must not wedge the session).

set -euo pipefail
set -f  # no globbing while word-splitting segments

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[ -z "$CMD" ] && exit 0

[ "${VLKIT_DEBUG:-0}" = "1" ] && echo "[vlkit:safety] $(printf '%s' "$CMD" | head -c 80)" >&2

LOG_DIR="${VLKIT_LOG_DIR:-$HOME/.claude/vlkit/logs}"
block() {  # <rule> <message>
  mkdir -p "$LOG_DIR"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | BLOCKED | $1 | $(pwd) | $(printf '%s' "$CMD" | head -c 120)" >> "$LOG_DIR/safety-gate.log"
  echo "BLOCKED by vlkit safety-gate ($1): $2" >&2
  exit 2
}

# Strip heredoc bodies (they are data), then make &&/||/;/| newline boundaries.
SEGMENTS=$(printf '%s\n' "$CMD" | awk '
  BEGIN { inhd = 0 }
  {
    line = $0
    if (inhd) { t = line; gsub(/^[ \t]+/, "", t); if (t == marker) inhd = 0; next }
    if (match(line, /<<-?[ \t]*["'\'']?[A-Za-z_][A-Za-z0-9_]*["'\'']?/)) {
      m = substr(line, RSTART, RLENGTH); sub(/<<-?[ \t]*/, "", m); gsub(/["'\'']/, "", m)
      marker = m; inhd = 1; line = substr(line, 1, RSTART - 1)
    }
    print line
  }' | awk '{ gsub(/&&|\|\||;/, "\n"); print }')

while IFS= read -r seg; do
  # Normalize: drop leading env-assignments/sudo, collapse whitespace.
  s=$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+/ /g')
  [ -z "$s" ] && continue
  bin=$(printf '%s' "$s" | awk '{print $1}')

  case "$bin" in
    rm)
      # Block recursive+force removals except an explicit build-artifact allowlist.
      if printf '%s' "$s" | grep -qE '(^| )-[a-zA-Z]*r[a-zA-Z]*f|(^| )-[a-zA-Z]*f[a-zA-Z]*r|(^| )-rf|(^| )-fr'; then
        if ! printf '%s' "$s" | grep -qE '(node_modules|dist|build|\.next|target|coverage|\.cache|/tmp/)'; then
          block "rm-rf" "recursive force-delete outside the build-artifact allowlist"
        fi
      fi ;;
    git)
      sub=$(printf '%s' "$s" | awk '{print $2}')
      if [ "$sub" = "push" ]; then
        printf '%s' "$s" | grep -qE '(^| )(--force|-f|--force-with-lease)( |$)' && block "force-push" "force push"
        printf '%s' "$s" | grep -qE '(^| )(main|master|origin/main|origin/master)( |$)' && block "push-main" "direct push to main/master — open a PR"
      fi
      if [ "$sub" = "reset" ]; then
        printf '%s' "$s" | grep -qE '(^| )--hard( |$)' && block "reset-hard" "git reset --hard discards work"
      fi ;;
    kubectl)
      printf '%s' "$s" | grep -qE '(^| )delete( |$)' && block "kubectl-delete" "kubectl delete"
      ;;
  esac

  # DROP TABLE / TRUNCATE anywhere in the segment (SQL run via CLI).
  printf '%s' "$s" | grep -qiE 'drop[[:space:]]+table|truncate[[:space:]]+table' && block "drop-table" "destructive SQL (DROP/TRUNCATE TABLE)"
done <<EOF
$SEGMENTS
EOF

exit 0
