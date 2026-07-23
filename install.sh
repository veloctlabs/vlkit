#!/bin/bash
# install.sh — install vlkit into ~/.claude/ (bash path, no plugin manifest).
#
#   bash install.sh                 # install / re-install (idempotent)
#   bash install.sh --with a,b,c    # opt-in modules (reserved; no-op in v1)
#   bash install.sh --uninstall     # remove exactly what vlkit added
#   bash install.sh --prune         # alias of a clean re-install
#
# What it does: symlink the repo to ~/.claude/vlkit, chmod scripts, merge the
# hook/statusLine/permission blocks from settings.json into ~/.claude/settings.json
# (idempotent: vlkit entries are stripped then re-added), and register commands
# under ~/.claude/commands/vlkit/ and agents under ~/.claude/agents/.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
LINK="$CLAUDE_DIR/vlkit"
SETTINGS="$CLAUDE_DIR/settings.json"
CMD_DIR="$CLAUDE_DIR/commands/vlkit"
AGENT_DIR="$CLAUDE_DIR/agents"
SRC_SETTINGS="$REPO/settings.json"

MODE="install"
WITH=""
PLUGIN_COMPAT=0
prev=""
for arg in "$@"; do
  case "$arg" in
    --uninstall)     MODE="uninstall" ;;
    --prune)         MODE="install" ;;
    --plugin-compat) PLUGIN_COMPAT=1 ;;
    --with=*)        WITH="${arg#--with=}" ;;
    *)               [ "$prev" = "--with" ] && WITH="$arg" ;;
  esac
  prev="$arg"
done

# Auto-detect: if the vlkit plugin is already installed, default to compat mode
# (the plugin owns the hooks + commands; the bash install would double-register).
if [ "$PLUGIN_COMPAT" = "0" ] && [ -d "$HOME/.claude/plugins" ] \
   && grep -rqsl '"name"[[:space:]]*:[[:space:]]*"vlkit"' "$HOME/.claude/plugins" 2>/dev/null; then
  PLUGIN_COMPAT=1
fi

command -v jq >/dev/null 2>&1 || { echo "vlkit: 'jq' is required." >&2; exit 1; }

require_repo_link() {
  mkdir -p "$CLAUDE_DIR"
  if [ -L "$LINK" ] || [ -e "$LINK" ]; then
    local target; target="$(cd "$LINK" 2>/dev/null && pwd || true)"
    [ "$target" = "$REPO" ] && return 0
    if [ -L "$LINK" ]; then rm -f "$LINK"; else
      echo "vlkit: $LINK exists and is not vlkit; leaving it. Point CLAUDE at $REPO manually." >&2
      return 0
    fi
  fi
  ln -s "$REPO" "$LINK"
}

merge_settings() {
  local cur="{}"
  [ -f "$SETTINGS" ] && cur="$(cat "$SETTINGS")"
  local src; src="$(cat "$SRC_SETTINGS")"
  jq -n --argjson cur "$cur" --argjson src "$src" '
    def strip(arr): [ (arr // [])[]
      | select( ( [ (.hooks // [])[].command | contains("/.claude/vlkit/") ] | any ) | not ) ];
    ($cur // {})
    | .hooks = ( (.hooks // {}) as $h
        | reduce ($src.hooks | keys_unsorted[]) as $ev ($h;
            .[$ev] = ( strip($h[$ev]) + $src.hooks[$ev] ) ) )
    | .statusLine = $src.statusLine
    | .permissions = ( (.permissions // {})
        | .deny = ( ((.deny // []) + ($src.permissions.deny // [])) | unique ) )
  ' > "$SETTINGS.tmp"
  mv "$SETTINGS.tmp" "$SETTINGS"
}

unmerge_settings() {
  [ -f "$SETTINGS" ] || return 0
  local src; src="$(cat "$SRC_SETTINGS")"
  jq -n --argjson cur "$(cat "$SETTINGS")" --argjson src "$src" '
    def strip(arr): [ (arr // [])[]
      | select( ( [ (.hooks // [])[].command | contains("/.claude/vlkit/") ] | any ) | not ) ];
    ($cur // {})
    | .hooks = ( (.hooks // {}) | with_entries( .value |= strip(.) ) )
    | ( if ((.statusLine.command // "") | contains("/.claude/vlkit/")) then del(.statusLine) else . end )
    | ( if (.permissions.deny? != null)
          then .permissions.deny = ( (.permissions.deny) - ($src.permissions.deny // []) )
          else . end )
  ' > "$SETTINGS.tmp"
  mv "$SETTINGS.tmp" "$SETTINGS"
}

register_commands_agents() {
  mkdir -p "$CMD_DIR" "$AGENT_DIR"
  local f
  for f in "$REPO"/commands/*.md; do ln -sf "$f" "$CMD_DIR/$(basename "$f")"; done
  for f in "$REPO"/agents/*.md;   do ln -sf "$f" "$AGENT_DIR/$(basename "$f")"; done
}

unregister_commands_agents() {
  rm -rf "$CMD_DIR"
  local f
  for f in "$AGENT_DIR"/*.md; do
    [ -L "$f" ] || continue
    case "$(readlink "$f")" in *"/vlkit/agents/"*) rm -f "$f" ;; esac
  done
}

chmod_scripts() {
  chmod +x "$REPO"/hooks/*.sh 2>/dev/null || true
  find "$REPO/lib" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
  chmod +x "$REPO"/tests/*.sh 2>/dev/null || true
}

if [ "$MODE" = "uninstall" ]; then
  unmerge_settings
  unregister_commands_agents
  [ -L "$LINK" ] && rm -f "$LINK"
  echo "vlkit: uninstalled (settings.json cleaned, commands/agents unregistered, symlink removed)."
  exit 0
fi

chmod_scripts
require_repo_link

if [ "$PLUGIN_COMPAT" = "1" ]; then
  # Plugin mode: the Claude Code plugin already registers hooks (hooks/hooks.json)
  # and commands/agents. Do NOT merge them into settings.json (double-fire) or
  # re-register commands. Only keep the ~/.claude/vlkit symlink so any bare-path
  # `$HOME/.claude/vlkit/lib/...` reference still resolves.
  echo "vlkit: plugin-compat install."
  echo "  repo symlink -> $LINK  (for bare-path lib references)"
  echo "  hooks/commands/agents are owned by the installed plugin — settings.json untouched."
  exit 0
fi

merge_settings
register_commands_agents
echo "vlkit: installed (bash mode)."
echo "  repo         -> $LINK"
echo "  settings     -> merged into $SETTINGS"
echo "  commands     -> $CMD_DIR/ (invoke as /vlkit:<name>)"
echo "  agents       -> $AGENT_DIR/"
[ -n "$WITH" ] && echo "  (--with '$WITH' noted; optional modules are reserved in v1)"
echo "Open a new Claude Code session for the hooks and commands to load."
