#!/bin/bash
# anti-rationalization.sh — Stop. Advisory nudge when Claude signals "done" but
# the transcript shows no test/verify run this session. Never blocks (exit 0);
# emits a reminder on stdout that Claude sees before finishing.

set -euo pipefail
INPUT=$(cat 2>/dev/null || true)

# Respect the config toggle (best-effort; default on).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ON=$(bash "$HERE/lib/config/vlkit-config.sh" get gates.anti_rationalization true 2>/dev/null || echo true)
[ "$ON" = "true" ] || exit 0

# transcript_path points at the session JSONL; scan the tail for verify activity.
TP=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)
[ -z "$TP" ] || [ ! -f "$TP" ] && exit 0

TAIL=$(tail -n 80 "$TP" 2>/dev/null || true)
# Did anything that looks like a test/verify run recently?
if printf '%s' "$TAIL" | grep -qiE 'go test|npm test|pytest|cargo test|vlkit:verify|bash tests/'; then
  exit 0
fi
# Did the assistant claim completion?
if printf '%s' "$TAIL" | grep -qiE '\b(done|complete|completed|finished|all set|works now|passing)\b'; then
  echo "vlkit reminder: a completion was claimed but no test/verify ran this session. Run /vlkit:verify (or the project's tests) before treating this as done."
fi
exit 0
