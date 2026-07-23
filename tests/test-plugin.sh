#!/bin/bash
# test-plugin.sh — plugin manifest + hooks.json structure, path idiom, and the
# install.sh --plugin-compat path. No Claude Code required.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

echo "plugin.json + marketplace.json:"
jq empty "$HERE/.claude-plugin/plugin.json" 2>/dev/null && ok || bad "plugin.json invalid JSON"
[ "$(jq -r '.name' "$HERE/.claude-plugin/plugin.json")" = "vlkit" ] && ok || bad "plugin.json name != vlkit"
jq empty "$HERE/.claude-plugin/marketplace.json" 2>/dev/null && ok || bad "marketplace.json invalid JSON"
jq -e '.plugins[] | select(.name=="vlkit")' "$HERE/.claude-plugin/marketplace.json" >/dev/null 2>&1 && ok || bad "marketplace.json lists no vlkit plugin"

echo "hooks/hooks.json:"
jq empty "$HERE/hooks/hooks.json" 2>/dev/null && ok || bad "hooks.json invalid JSON"
# every command path uses CLAUDE_PLUGIN_ROOT, none uses $HOME/.claude/vlkit
if jq -r '[.hooks[][]?.hooks[]?.command] | .[]' "$HERE/hooks/hooks.json" | grep -q 'HOME/.claude/vlkit'; then
  bad "hooks.json still references \$HOME/.claude/vlkit"
else ok; fi
jq -r '[.hooks[][]?.hooks[]?.command] | .[]' "$HERE/hooks/hooks.json" | grep -q 'CLAUDE_PLUGIN_ROOT' && ok || bad "hooks.json missing CLAUDE_PLUGIN_ROOT"
# hook-script set matches settings.json exactly
SET_SCRIPTS="$(jq -r '[.hooks[][]?.hooks[]?.command] | map(gsub(".*/hooks/";"")) | sort | unique | join(",")' "$HERE/settings.json")"
HJ_SCRIPTS="$(jq -r '[.hooks[][]?.hooks[]?.command] | map(gsub(".*/hooks/";"")) | sort | unique | join(",")' "$HERE/hooks/hooks.json")"
[ "$SET_SCRIPTS" = "$HJ_SCRIPTS" ] && ok || bad "hooks.json hook set != settings.json ($HJ_SCRIPTS vs $SET_SCRIPTS)"

echo "command lib refs use the fallback idiom (no bare ~/.claude/vlkit/lib):"
grep -rq '~/.claude/vlkit/lib' "$HERE"/commands/*.md && bad "a command still has a bare ~/.claude/vlkit/lib ref" || ok

echo "install.sh --plugin-compat: symlinks repo, does NOT add hooks to settings.json:"
SB="$(mktemp -d)"; mkdir -p "$SB/.claude"
printf '{"model":"sonnet"}\n' > "$SB/.claude/settings.json"
HOME="$SB" bash "$HERE/install.sh" --plugin-compat >/dev/null 2>&1
# settings.json must NOT contain vlkit hook entries
if jq -e '[.. | .command? // empty] | map(select(contains("vlkit/hooks"))) | length > 0' "$SB/.claude/settings.json" >/dev/null 2>&1; then
  bad "--plugin-compat wrote vlkit hooks into settings.json"
else ok; fi
[ -L "$SB/.claude/vlkit" ] && ok || bad "--plugin-compat did not create the ~/.claude/vlkit symlink"
# and the pre-existing model key is preserved
[ "$(jq -r '.model' "$SB/.claude/settings.json")" = "sonnet" ] && ok || bad "--plugin-compat clobbered settings.json"
rm -rf "$SB" 2>/dev/null

echo "-----------------------------------------"
echo "plugin: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
