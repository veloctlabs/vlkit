# SPEC-008: package vlkit as a dual-mode Claude Code plugin

Status: SHIPPED
Lane: full
Date: 2026-07-23

## Goal

Make vlkit installable via `/plugin` (Claude Code plugin) **without losing** the
bash installer — the same dual-mode dwarves-kit uses. Add the plugin manifest,
a plugin-native hook config, path references that resolve in both modes, and a
plugin-aware `install.sh`, so `/plugin marketplace add yuzuyield/vlkit` →
`/plugin install vlkit@vlkit` works and `bash install.sh` still works.

## Non-goals

- No removal of the bash path (`settings.json` + `install.sh` stay).
- No submission to Anthropic's community marketplace here (that's a manual
  follow-up via the claude.ai/console form once this is published self-hosted).

## Design notes (mirror dwarves-kit)

- **Manifest**: `.claude-plugin/plugin.json` (name required) + a self-hosted
  `.claude-plugin/marketplace.json` listing vlkit with `source: "."`.
- **Hooks**: `hooks/hooks.json` at the plugin root declares the same hook wiring
  as `settings.json`, but with paths under `${CLAUDE_PLUGIN_ROOT}` (the plugin
  cache dir) instead of `$HOME/.claude/vlkit`. `plugin.json` points at it via a
  `hooks` key. `settings.json` stays for the bash path.
- **Path idiom**: command/agent prose that shells out to `lib/` must use
  `${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/vlkit}` so it resolves in plugin mode
  (var set → cache dir) and bash mode (var unset → the installed symlink).
- **install.sh plugin-awareness**: when the vlkit plugin is already installed
  (detected under `~/.claude/plugins`) OR `--plugin-compat` is passed, do a
  compat-only install — symlink `~/.claude/vlkit → <plugin root>` for bare-path
  docs and **skip** the `settings.json` hook merge (the plugin already registers
  them; double-registration would double-fire).
- **`statusLine` is NOT in `hooks/hooks.json`**: the v1 plugin schema does not
  configure a status line (confirmed against dwarves-kit, whose hooks.json also
  omits it). The status-line HUD stays **bash-installer-only** — `settings.json`
  keeps its `statusLine` key; plugin installs simply don't get the HUD (a
  documented, accepted limitation). So hooks.json carries the 8 event-hook
  scripts, not statusline.

## Tasks

1. Add `.claude-plugin/plugin.json` (name/description/version/author/repo/license,
   `hooks: "./hooks/hooks.json"`) and `.claude-plugin/marketplace.json`
   (`name: vlkit`, one plugin, `source: "."`).
2. Add `hooks/hooks.json` — the `settings.json` hook-event wiring (the 8 event
   hooks; NOT statusLine, which the plugin schema can't configure) with every
   `$HOME/.claude/vlkit/hooks/<x>.sh` rewritten to
   `${CLAUDE_PLUGIN_ROOT}/hooks/<x>.sh`.
3. Rewrite the `~/.claude/vlkit/lib/...` references in `commands/*.md`
   (ship, provenance, dispatch, execute) to
   `${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/vlkit}/lib/...`.
4. Make `install.sh` plugin-aware: detect an installed vlkit plugin (or
   `--plugin-compat`), and in that mode symlink `~/.claude/vlkit → plugin root`
   and skip the settings.json hook merge; otherwise the current full bash
   install (unchanged).
5. Document dual-mode install in `README.md` (both `/plugin` and `bash`).
6. Keep all test suites green; add a `tests/test-plugin.sh` that validates the
   plugin manifest + hooks.json structurally (valid JSON, plugin name present,
   every hooks.json command path points into `hooks/`, hook set matches
   settings.json).

## Acceptance criteria

1. `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` exist and
   are valid JSON; plugin.json has a `name` of `vlkit`; marketplace.json lists a
   plugin named `vlkit`.
2. `hooks/hooks.json` is valid JSON and registers the SAME set of hook-event
   scripts as `settings.json`'s `.hooks` (the 8: safety-gate, secrets-guard,
   commit-format, ship-gate, context-readiness, context-hints,
   anti-rationalization, session-state-save), each path under
   `${CLAUDE_PLUGIN_ROOT}` (grep-able; no `$HOME/.claude/vlkit` in it).
   `statusLine` is intentionally NOT in hooks.json (plugin schema can't set it;
   it stays in `settings.json` for the bash path only).
3. No `commands/*.md` file references a bare `~/.claude/vlkit/lib` or
   `$HOME/.claude/vlkit/lib` without the `${CLAUDE_PLUGIN_ROOT:-...}` prefix.
4. `install.sh --plugin-compat` symlinks `~/.claude/vlkit` and does NOT write
   vlkit hook entries into settings.json (verified in a sandbox HOME); the
   default `install.sh` still merges hooks (existing behavior).
5. If `claude plugin validate .` is available, it passes; otherwise state it was
   unavailable and the structural test covers the manifest.
6. `bash tests/test-plugin.sh` exits 0; `test-hooks.sh`, `test-meta.sh`,
   `test-lib.sh`, `test-dispatch.sh`, `test-provenance.sh`, `test-ship.sh` still
   exit 0.

## Verify

```bash
bash tests/test-plugin.sh
bash tests/test-hooks.sh
bash tests/test-meta.sh
bash tests/test-lib.sh
bash tests/test-dispatch.sh
bash tests/test-provenance.sh
bash tests/test-ship.sh
claude plugin validate .   # if available
```
