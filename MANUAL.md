# MANUAL

Operator reference for vlkit. For the what/why, read `README.md`; for the design
contract, `docs/specs/SPEC-001-vlkit-scaffold.md`.

## The hook contract

Every hook reads the Claude Code event JSON on **stdin** and communicates by
exit code:

| Exit | Meaning |
|---|---|
| `0` | allow / no-op |
| `2` | **block** the action; text on **stderr** is shown to Claude as the reason |
| other | hook error — treated as fail-open (logged, does not block) |

Debug any hook with `VLKIT_DEBUG=1`. Blocked actions are appended to
`${VLKIT_LOG_DIR:-~/.claude/vlkit/logs}/<hook>.log`.

## Hooks

| Hook | Event | Blocking? | Behavior |
|---|---|---|---|
| `safety-gate` | PreToolUse(Bash) | yes | Blocks `rm -rf` (allowlist: node_modules/dist/build/.next/target/coverage/.cache/tmp), `git push` to main/master, force-push, `git reset --hard`, `kubectl delete`, `DROP/TRUNCATE TABLE`. Parse-aware: strips heredoc bodies, splits on `&&/\|\|/;`, keys each rule on the segment's real first word — prose describing `rm -rf` does not trip it. |
| `secrets-guard` | PreToolUse(Read\|Edit\|Bash) | yes | Blocks access to `.env*`, `~/.ssh`, `~/.aws`, `~/.gnupg`, `*.pem/.p12/.pfx`, `.git-credentials`, `.npmrc`, and named key files. |
| `commit-format` | PreToolUse(Bash) | yes | Only inspects `git commit -m …`. Requires a conventional subject (`type(scope)?: …`) ≤ 72 chars. Interactive commits (no `-m`) pass. |
| `ship-gate` | PreToolUse(Bash) | yes | Blocks `git push` / `gh pr create` when the gate-ledger has no proof-of-done row for HEAD. Escape hatch: `VLKIT_SHIP_OVERRIDE=1`. Fails open outside a git repo. |
| `context-readiness` | SessionStart | no | Prints project + spec state and an intent-first next step. |
| `context-hints` | UserPromptSubmit | no | Injects keyword→hint text from `[hints]` in the resolved `.vlkit.toml`/`vlkit.toml`. |
| `anti-rationalization` | Stop | no | If a "done/complete/passing" claim appears but no test/verify ran this session, nudges to run `/vlkit:verify`. |
| `session-state-save` | Stop, SubagentStop | no | Writes `<project>/.vlkit/state.json` (branch, HEAD, dirty count). |
| `statusline` | statusLine | no | Renders `vlkit ⟨repo:branch⟩ lane:<lane>`. |

## Commands (`/vlkit:<name>`)

| Command | Use |
|---|---|
| `start` | Detect state, suggest the next command. Entry point. |
| `think` | 6 forcing questions before any spec. Ends in a BUILD/RETHINK/KILL brief. Advisory. |
| `spec` | Write `docs/specs/SPEC-NNN-<slug>.md` (Goal, Non-goals, Tasks, Acceptance criteria, Verify, Lane). |
| `execute` | Orchestrate worker → task-verifier → fix-agent over the spec's tasks. Stops to ask on escalation. |
| `verify` | Re-run the spec's Verify commands read-only → PASS / FAIL / INCONCLUSIVE. |
| `review` | Single-pass (or `code-reviewer`-backed) review of the diff. Advisory verdict SHIP/FIX-FIRST. |
| `ship` | Verify → version bump → changelog → conventional commit → record proof-of-done → push + PR. |
| `retro` | Short retrospective appended to `docs/RETRO.md`. |

## Agents

| Agent | Tools | Role |
|---|---|---|
| `task-verifier` | read-only + test runners | Check one task vs its acceptance criteria → PASS / FAIL:fixable / FAIL:escalate. Cannot edit. |
| `fix-agent` | edit + test runners | Fix exactly the flagged finding, minimal change, ≤2 attempts per task. |
| `code-reviewer` | read-only + git diff | One-lens review, findings ranked by severity. |
| `spec-writer` | read + write | Draft a spec from a brief non-interactively. |

## Risk lanes

Set `Lane:` in the spec header. `tiny` may skip the verifier for trivial
doc/config edits; `normal` is the default; `full` and `bug` always verify. The
lane is advice to the orchestrator, plus what `statusline` displays.

## The gate ledger

```bash
bash ~/.claude/vlkit/lib/gate/gate-ledger.sh record <kind> <spec> <ref> [note]
bash ~/.claude/vlkit/lib/gate/gate-ledger.sh proof  <spec> <short-sha>   # opens the ship-gate for that HEAD
bash ~/.claude/vlkit/lib/gate/gate-ledger.sh has-proof <short-sha>       # exit 0 if a proof exists
bash ~/.claude/vlkit/lib/gate/gate-ledger.sh run-start <spec> <task> <model>  # mark a task's worker start
bash ~/.claude/vlkit/lib/gate/gate-ledger.sh run-end   <spec> <task>          # mark it done (epoch stored in note)
bash ~/.claude/vlkit/lib/stats/stats.sh                                   # summary projection
bash ~/.claude/vlkit/lib/stats/stats.sh timeline [spec]                    # Gantt + wall/worker/parallel_potential
```

## Model per task

Tag a spec task `[light]` or `[heavy]` (after its number) to pick the worker
model; `[models]` in `vlkit.toml` maps weight → model. Resolve one directly:

```bash
bash ~/.claude/vlkit/lib/config/vlkit-config.sh model heavy   # -> opus (default map)
```

`/vlkit:execute` calls this per task and records `run-start`/`run-end` around
each so `stats timeline` can chart real durations by model.

Location follows `[ledger] location` in config: `shared`
(`~/.claude/vlkit/logs/`) or `isolated` (`<project>/.vlkit/logs/`).

## Recovering from a misbehaving hook

- A hook blocking something it shouldn't: read the stderr reason; it names the
  rule. For a deliberate one-off (e.g. a real force-push), the specific escape
  hatch is on the hook (`VLKIT_SHIP_OVERRIDE=1` for ship-gate). For safety-gate
  there is intentionally no per-command bypass — do the action outside the agent.
- Turn on `VLKIT_DEBUG=1` to see what a hook parsed.
- Full removal: `bash ~/.claude/vlkit/install.sh --uninstall`.

## Uninstall

```bash
bash ~/.claude/vlkit/install.sh --uninstall   # removes only what vlkit added
```
