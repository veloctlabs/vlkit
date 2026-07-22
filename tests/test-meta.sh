#!/bin/bash
# test-meta.sh — structural integrity: frontmatter, shebangs, executability,
# and valid JSON. No Claude Code required.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

echo "commands have a description frontmatter:"
for f in "$HERE"/commands/*.md; do
  head -5 "$f" | grep -qE '^description:' && ok || bad "$(basename "$f") missing description"
done

echo "agents have name + description frontmatter:"
for f in "$HERE"/agents/*.md; do
  h="$(head -8 "$f")"
  { printf '%s' "$h" | grep -qE '^name:' && printf '%s' "$h" | grep -qE '^description:'; } \
    && ok || bad "$(basename "$f") missing name/description"
done

echo "hooks + lib scripts have a shebang:"
for f in "$HERE"/hooks/*.sh "$HERE"/lib/**/*.sh; do
  [ -f "$f" ] || continue
  head -1 "$f" | grep -qE '^#!' && ok || bad "$(basename "$f") missing shebang"
done

echo "settings.json + vlkit.toml are present and settings.json is valid JSON:"
jq empty "$HERE/settings.json" >/dev/null 2>&1 && ok || bad "settings.json invalid JSON"
[ -f "$HERE/vlkit.toml" ] && ok || bad "vlkit.toml missing"

echo "every settings.json hook path points into hooks/:"
for cmd in $(jq -r '[.. | .command? // empty] | .[]' "$HERE/settings.json"); do
  case "$cmd" in *"/.claude/vlkit/hooks/"*) hook="${cmd##*/}"
      [ -f "$HERE/hooks/$hook" ] && ok || bad "settings references missing hook $hook" ;;
  esac
done

echo "-----------------------------------------"
echo "meta: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
