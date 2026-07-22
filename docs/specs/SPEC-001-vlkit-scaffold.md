# SPEC-001: vlkit — reusable Claude Code workflow kit

Status: SHIPPED
Lane: full
Date: 2026-07-22

## Goal

A reusable, bash-first Claude Code workflow toolkit installed **once** into
`~/.claude/` and active across **every** project on the machine. It provides a
closed-loop, spec-driven lifecycle (`think → spec → execute → verify → review →
ship → retro`) with **mechanical** safety and quality gates. Agents iterate
inside the gates; a read-only verifier decides pass/fail, never the agent that
did the work.

Distribution: **bash installer only** (no Claude Code plugin manifest). Docs and
prompts in **English**. Standalone git repo.

## Non-goals (YAGNI)

- No Claude Code `/plugin` marketplace manifest (bash path only).
- No compiled binaries, no Node/Python in hot hooks (carve-out: `statusline.sh`
  may shell out to anything, it is off the money/safety path).
- No DAG scheduler, no coordinating daemon, no cross-machine orchestration.
- No board/sync/telemetry-to-external-service modules in v1.

## Install model

- User clones the repo to `~/.claude/vlkit` and runs `bash install.sh`.
- `install.sh` merges vlkit's `settings.json` hook/statusLine/permission blocks
  into `~/.claude/settings.json` using `jq`, **idempotently** (re-running never
  double-registers; a block is recognized by its script path).
- `install.sh` also symlinks the command and agent files so Claude Code
  registers them: commands into `~/.claude/commands/vlkit/` (a subdirectory, so
  Claude Code namespaces them as **`/vlkit:<name>`**) and agents into
  `~/.claude/agents/`. `--uninstall` removes these symlinks too.
- Because `~/.claude/settings.json` is global, all projects get the kit.
- Per-project config lives in `<project>/.vlkit.toml` (optional; defaults apply
  when absent). Resolver: project `.vlkit.toml` wins over repo-root
  `vlkit.toml` default, key-by-key.
- Flags: `--with a,b,c` (opt-in cosmetic/stats modules), `--uninstall` (remove
  only the blocks vlkit added), `--prune` (trim back to spine).
- Requirements: `jq`, `git`, bash 3.2+ (macOS default).

## Repository layout

```
vlkit/
├── install.sh
├── settings.json
├── vlkit.toml
├── README.md  MANUAL.md  LICENSE  VERSION
├── hooks/
│   ├── safety-gate.sh          # PreToolUse(Bash)
│   ├── secrets-guard.sh        # PreToolUse(Read|Edit|Bash)
│   ├── commit-format.sh        # PreToolUse(Bash)
│   ├── ship-gate.sh            # PreToolUse(Bash)
│   ├── context-readiness.sh    # SessionStart
│   ├── context-hints.sh        # UserPromptSubmit
│   ├── anti-rationalization.sh # Stop
│   ├── session-state-save.sh   # Stop, SubagentStop
│   └── statusline.sh           # statusLine
├── commands/
│   ├── start.md think.md spec.md execute.md
│   ├── verify.md review.md ship.md retro.md
├── agents/
│   ├── task-verifier.md  fix-agent.md  code-reviewer.md  spec-writer.md
├── lib/
│   ├── gate/gate-ledger.sh
│   ├── stats/stats.sh
│   └── config/vlkit-config.sh
├── tests/
│   ├── test-hooks.sh
│   └── test-meta.sh
└── docs/specs/                 # this spec + downstream consumer specs
```

## Hook contract (shared by all hooks)

- Read the event JSON from **stdin**; parse with `jq`.
- **`exit 0`** = allow. **`exit 2`** = block the action; text on **stderr** is
  shown to Claude as the reason. Any other non-zero = hook error (fail-open,
  logged, does not block).
- `set -euo pipefail`. Debug via `VLKIT_DEBUG=1` (verbose to stderr).
- Blocked actions are appended to `${VLKIT_LOG_DIR:-~/.claude/vlkit/logs}/<hook>.log`.
- Hooks NEVER read `.vlkit.toml` (keep the hot path free of config reads); only
  commands and `lib/` read config.

### Per-hook behavior

| Hook | Event | Blocks / does |
|---|---|---|
| safety-gate | PreToolUse(Bash) | `rm -rf` (allowlist build artifacts), `git push` to main/master, force-push, `git reset --hard`, `DROP TABLE`, `kubectl delete`. Parse-aware: strip heredoc bodies, split compounds on `&&/;/\|`, key rules on each segment's actual argv (not prose). |
| secrets-guard | PreToolUse(Read\|Edit\|Bash) | Reads of `.env*`, `~/.ssh`, `~/.aws`, `~/.gnupg`, `*.pem/.p12/.pfx`. Canonicalize path first. |
| commit-format | PreToolUse(Bash) | Non-conventional commit subjects, `>72` chars. Only inspects `git commit` segments. |
| ship-gate | PreToolUse(Bash) | `git push` / `gh pr create` when the gate-ledger has no proof-of-done row for HEAD. |
| context-readiness | SessionStart | Detect project type + spec/board state, emit an intent-first "next step" suggestion (advisory, never blocks). |
| context-hints | UserPromptSubmit | Inject session elapsed/idle time + keyword→skill hints from a config map (empty default). |
| anti-rationalization | Stop | Detect premature "done" claims when tests/verify were not run; nudge (advisory). |
| session-state-save | Stop, SubagentStop | Persist progress to `<project>/.vlkit/state.json`. |
| statusline | statusLine | Render current lane + context budget. |

## Commands (`/vlkit:<name>`)

Each is a markdown file with frontmatter `description` and a prompt body.

| Command | Purpose |
|---|---|
| start | Detect state, suggest next command (entry point). |
| think | 6 forcing questions that stress-test the idea before any spec. Advisory. |
| spec | Write the contract to `docs/specs/SPEC-NNN-<slug>.md` (goal, acceptance criteria numbered, tasks, verify method, lane). |
| execute | Autonomous build: orchestrate worker → task-verifier → fix-agent over the spec's task list. |
| verify | Re-run the spec's tests read-only; report PASS / FAIL / INCONCLUSIVE. |
| review | Single-pass code review of the change; record a verdict (advisory). |
| ship | Verify gate → version bump → changelog → conventional commit → PR; writes proof-of-done to the ledger. |
| retro | Short retrospective after ship; append lessons to `docs/`. |

## Agents

| Agent | Tools | Role |
|---|---|---|
| task-verifier | Read, Grep, Glob, Bash(*test*) only | Read-only. Check one task vs its acceptance criteria + tests → PASS / FAIL:fixable / FAIL:escalate. Cannot edit code. |
| fix-agent | Read, Edit, Write, Bash(test) | Fix what the verifier flagged. Max 2 attempts per task, then escalate. |
| code-reviewer | Read, Grep, Glob, Bash(git diff) | One-lens review; report findings, does not edit. |
| spec-writer | Read, Grep, Glob, Write | Optional worker that drafts a spec from a brief. |

## Verification pipeline (`/vlkit:execute`)

```
execute (orchestrator: owns spec task-list, one task at a time)
  → worker (implements task)
  → task-verifier (read-only: acceptance criteria + tests)
       PASS         → mark done, next task
       FAIL:fixable → fix-agent (≤2 retries) → back to task-verifier
       FAIL:escalate→ stop, ask the human
```

Tasks run sequentially within a spec. No parallel-worktree fan-out in v1.

## Risk lanes

Set in the spec header: `tiny` (skip ceremony), `normal`, `full`, `bug`. Lane
governs verify depth. Documented in `MANUAL.md`; not machine-enforced in v1
beyond ship-gate's proof-of-done requirement.

## Ledger & proof-of-done

- `lib/gate/gate-ledger.sh` appends one line per gate crossing to
  `${VLKIT_LOG_DIR}/gate-ledger.log` (or `<project>/.vlkit/logs/` when
  `.vlkit.toml` sets `ledger = "isolated"`).
- A proof-of-done row records the spec ID + a commit/verify reference for HEAD.
- `ship-gate.sh` reads this ledger to gate push/PR.
- `lib/stats/stats.sh` is a read-only projection over the same ledger
  (run count, pass-rate, blocked-action tally).

## Config resolver

`lib/config/vlkit-config.sh get <key>` resolves: `<project>/.vlkit.toml` →
`~/.claude/vlkit/vlkit.toml` (installed default) → hardcoded fallback. Called by
commands and libs at invocation time only.

## Testing

- `tests/test-hooks.sh`: feed each hook a crafted stdin JSON, assert exit code
  and stderr substring. Must cover: safety-gate blocks `git push origin main`
  (exit 2) and allows `git push origin feature/x` (exit 0); secrets-guard blocks
  a `.env` read; commit-format blocks `git commit -m "stuff"` and allows
  `git commit -m "feat: add flag"`; ship-gate blocks a push with no proof-of-done.
- `tests/test-meta.sh`: every `commands/*.md` has a `description` frontmatter;
  every `hooks/*.sh` and `lib/**/*.sh` has a shebang and is executable; every
  agent has `name` + `description`.
- Both scripts run on macOS (bash 3.2) and Linux. CI (GitHub Actions matrix)
  is a follow-up, not in v1.

## Acceptance criteria

1. `bash install.sh` on a clean machine merges vlkit blocks into
   `~/.claude/settings.json`, creates the `~/.claude/vlkit` symlink, and
   registers commands under `~/.claude/commands/vlkit/` + agents under
   `~/.claude/agents/`; re-running is a no-op (idempotent). `--uninstall`
   removes exactly what was added.
2. All nine hooks exist, are executable, follow the stdin/exit-2 contract, and
   fail-open on internal error.
3. safety-gate and secrets-guard block the dangerous cases and allow the safe
   cases listed under Testing.
4. All eight commands exist with valid frontmatter and a prompt body.
5. All four agents exist with valid frontmatter and constrained `tools`.
6. `bash tests/test-hooks.sh` and `bash tests/test-meta.sh` pass.
7. README documents install, the lifecycle, and per-project `.vlkit.toml`;
   MANUAL documents every command/hook/agent.
8. No secret is ever committed; `settings.json` `permissions.deny` mirrors the
   secrets-guard list.

## Open questions

None blocking. Cosmetic/stats modules ship enabled-by-default-off via `--with`.
```

