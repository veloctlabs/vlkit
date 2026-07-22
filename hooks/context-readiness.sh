#!/bin/bash
# context-readiness.sh — SessionStart. Advisory: detect project + spec state and
# suggest a next step. Never blocks. Prints context for Claude on stdout.

set -euo pipefail
INPUT=$(cat 2>/dev/null || true)

echo "## vlkit"
if [ -d docs/specs ]; then
  n=$(find docs/specs -name 'SPEC-*.md' 2>/dev/null | wc -l | tr -d ' ')
  draft=$(grep -lE '^Status:[[:space:]]*DRAFT' docs/specs/SPEC-*.md 2>/dev/null | wc -l | tr -d ' ')
  echo "- specs: $n total, $draft in DRAFT (docs/specs/)"
  if [ "$draft" -gt 0 ]; then
    echo "- next: a DRAFT spec exists — /vlkit:execute to build it, or /vlkit:spec-validate to stress-test."
  else
    echo "- next: /vlkit:think or /vlkit:spec to start a change."
  fi
else
  echo "- no docs/specs/ yet — /vlkit:think to shape an idea, then /vlkit:spec."
fi
exit 0
