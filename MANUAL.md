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
| `spec` | Write `docs/specs/SPEC-NNN-<slug>.md` (Goal, Non-goals, Tasks, Acceptance criteria, Verify, Lane) **plus a spec-as-tests skeleton**: one failing test per acceptance criterion (framework-detected, or a `.tests.md` checklist fallback), kept 1:1. |
| `execute` | Orchestrate worker → task-verifier → fix-agent over the spec's tasks. Stops to ask on escalation. High-stakes tasks escalate to **adversarial mode** (3 `adversarial-verifier`s; pass only if a majority can't refute). |
| `dispatch` | Parallel `execute`: run a wave's independent tasks in git worktrees at once, merge sequentially, **stop on conflict**. Uses `(deps: …)` task syntax. |
| `draft-agent` | Synthesize a reusable agent into the project's `.claude/agents/` via `meta-agent`, from a role description. |
| `provenance` | Emit a machine-checkable trace for a spec (task → model → proof → commit) from the ledger, markdown or `--json`. |
| `verify` | Re-run the spec's Verify commands read-only → PASS / FAIL / INCONCLUSIVE. **Adversarial mode**: 3 `adversarial-verifier`s try to refute; pass only if a majority can't. |
| `review` | Single-pass (or `code-reviewer`-backed) review of the diff. Advisory verdict SHIP/FIX-FIRST. |
| `ship` | Verify → version bump → changelog → conventional commit → record proof-of-done → push branch + open PR. If `gh` is missing/unauthenticated, `lib/ship/open-pr.sh` **falls back** to printing the GitHub compare URL so ship still finishes (never a direct-main push). |
| `retro` | Short retrospective appended to `docs/RETRO.md`. |
| `pitch` | Assemble an outward buy-in doc for a shipped spec from the spec + provenance + proof-of-done. Outcome-first, ends in an ask, never fabricates. |

## Agents

| Agent | Tools | Role |
|---|---|---|
| `task-verifier` | read-only + test runners | Check one task vs its acceptance criteria → PASS / FAIL:fixable / FAIL:escalate. Cannot edit. |
| `fix-agent` | edit + test runners | Fix exactly the flagged finding, minimal change, ≤2 attempts per task. |
| `code-reviewer` | read-only + git diff | One-lens review, findings ranked by severity. |
| `spec-writer` | read + write | Draft a spec from a brief non-interactively. |
| `security-reviewer` | read-only + git diff | Audit a change for injection, secret exposure, authz gaps, path traversal, unsafe deserialization. Verdict SAFE/FIX-FIRST. |
| `test-writer` | edit + test runners | Write tests covering a change — happy path, edges, and the fixed failure. |
| `researcher` | read-only + git log | Investigate architecture, prior art, conventions, pitfalls before a spec; returns a findings brief. |
| `db-migration-worker` | edit + goose/psql | Write reversible up/down migrations; flag destructive DDL, never silent data loss. |
| `meta-agent` | read + write | Synthesize a new agent definition to a given path (least-privilege tools, focused body). Backs `/vlkit:draft-agent`. |
| `adversarial-verifier` | read-only + test runners | Tries to REFUTE that a task meets its criteria (default refuted=true when unsure). Run 3 in parallel; pass only if a majority can't refute. |

**Growing the roster:** prefer synthesis over cloning. `/vlkit:draft-agent
<role>` dispatches `meta-agent` to write a reusable agent into the project's
`.claude/agents/` (version-controlled, loads next session). For a one-off role,
`/vlkit:execute`/`/vlkit:dispatch` synthesize a worker inline. Freeze a
synthesized agent into a static file only once the same role recurs.

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

## Parallel dispatch (worktrees)

```bash
bash ~/.claude/vlkit/lib/dispatch/waves.sh <spec>          # print topological waves; rejects cycles
bash ~/.claude/vlkit/lib/dispatch/worktree.sh provision <id> [base]  # add .vlkit/worktrees/<id> on branch vlkit/<id>
bash ~/.claude/vlkit/lib/dispatch/worktree.sh merge <id>   # MERGED <id> | CONFLICT <id> <files> (aborts, exit≠0)
bash ~/.claude/vlkit/lib/dispatch/worktree.sh cleanup <id> # remove worktree + branch
bash ~/.claude/vlkit/lib/dispatch/worktree.sh list         # active vlkit worktrees
```

Task dependency syntax in a spec: `3. [heavy] name (deps: 1 2) — …`. Merges are
sequential; a `CONFLICT` stops the run and is never auto-resolved. Worktrees live
under `<project>/.vlkit/worktrees/` (git-ignored via the shipped `.vlkit/` rule —
consumer repos should ignore `.vlkit/` too).

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
