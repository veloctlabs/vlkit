# vlkit

A reusable, bash-first **Claude Code workflow kit**. Install it once into
`~/.claude/` and every project on the machine gets a closed-loop, spec-driven
lifecycle with **mechanical** safety and quality gates.

The idea: you set the goal and write a spec; agents build inside the gates; a
**read-only verifier** — never the agent that did the work — decides pass/fail.
Dangerous actions (`rm -rf`, push to `main`, force-push, reading secret files,
shipping without proof) are blocked by bash hooks, not by asking the model to be
careful.

```
/vlkit:think → spec → execute → verify → review → ship → retro
```

## Install

Requires `jq`, `git`, and bash (macOS 3.2+ or Linux).

```bash
git clone <this-repo> ~/.claude/vlkit
cd ~/.claude/vlkit && bash install.sh
```

`install.sh` is **idempotent**: it merges vlkit's hook/statusLine/permission
blocks into `~/.claude/settings.json` (preserving everything already there),
symlinks the repo to `~/.claude/vlkit`, and registers commands under
`~/.claude/commands/vlkit/` (invoked as `/vlkit:<name>`) and agents under
`~/.claude/agents/`. Re-running never double-registers.

Open a **new** Claude Code session afterward so the hooks and commands load.

Remove everything vlkit added: `bash ~/.claude/vlkit/install.sh --uninstall`.

## Your first cycle

In any project, run one lap. A tiny change is the best first try:

1. `/vlkit:start` — orients you, suggests the next step.
2. `/vlkit:think` — describe the change; it throws 6 forcing questions at it.
3. `/vlkit:spec` — writes the contract to `docs/specs/SPEC-NNN-<slug>.md`.
4. `/vlkit:execute` — worker builds a task → task-verifier checks it → fix-agent
   retries fixable failures (max 2) → next task. (Or `/vlkit:dispatch` to run
   independent tasks in parallel — see below.)
5. `/vlkit:review` then `/vlkit:ship` — review, then version bump, changelog,
   conventional commit, PR (and the proof-of-done the ship-gate requires).
6. `/vlkit:retro` — capture one improvement for next time.

## Parallel dispatch

`/vlkit:dispatch` is the parallel sibling of `/vlkit:execute`. Tasks may declare
dependencies; independent ones run **at the same time**, each in its own git
worktree, and are **merged back sequentially**:

```
## Tasks
1. tier-defaults — ...
2. provenance — ...
3. [heavy] token-ledger (deps: 1 2) — ...   # waits for 1 and 2
```

`lib/dispatch/waves.sh` groups tasks into waves (topological); each wave's tasks
get a worktree (`.vlkit/worktrees/<id>` on branch `vlkit/<id>`), run in parallel
on their resolved model, then merge one by one. There is **no disjointness
check** — a merge conflict **stops the run** and is reported for a human to
resolve (never auto-merged). `stats timeline` then shows the overlap and how much
wall-clock the parallelism saved.

`/vlkit:execute` runs the build semi-autonomously, but only **after you approve
a spec**, and it stops to ask you whenever a task can't be fixed automatically.
It is not an "do everything from one sentence" bot.

## What's in the box

- **9 hooks** (bash + jq, each readable in 30 seconds) — see `MANUAL.md`.
  Blocking: `safety-gate`, `secrets-guard`, `commit-format`, `ship-gate`.
  Advisory: `context-readiness`, `context-hints`, `anti-rationalization`,
  `session-state-save`, `statusline`.
- **8 commands** — the lifecycle above plus `/vlkit:start`.
- **4 agents** — `task-verifier` (read-only gate), `fix-agent` (bounded fixer),
  `code-reviewer`, `spec-writer`.
- **lib/** — `gate-ledger.sh` (proof-of-done record), `stats.sh` (read-only
  projection), `vlkit-config.sh` (the one config resolver).

## Model per task + timeline

A spec task may carry a weight tag so heavier work runs on a stronger model:

```
## Tasks
1. [light] docs-index — regenerate the index
2. [heavy] token-ledger — double-entry accounting core
3. release-cut — tag and changelog        # no tag = default weight
```

`[models]` in `vlkit.toml` maps weight → model (`default`/`light`/`heavy`).
`/vlkit:execute` resolves each task's model and dispatches the worker on it, and
records the run so you can chart it:

```bash
bash ~/.claude/vlkit/lib/stats/stats.sh timeline          # all runs
bash ~/.claude/vlkit/lib/stats/stats.sh timeline SPEC-002 # one spec
```

The timeline prints a per-task bar (task · model · duration) and a summary:
`wall` (first start → last end), `worker` (Σ durations), and
`parallel_potential` (the floor if every task ran at once) — the gap between
`worker` and `parallel_potential` is what parallel dispatch (SPEC-003) closes.

## Configure per project

Drop a `.vlkit.toml` at a project's root to override defaults (see `vlkit.toml`
for every key). Common ones:

```toml
[ledger]
location = "isolated"   # keep this project's ledger in ./.vlkit/logs instead of the shared one

[models]
heavy = "opus"          # which model [heavy]-tagged tasks run on

[hints]
migration = "run the db-migration checklist before editing schema"
```

Only commands and `lib/` read config; the hot-path hooks never do.

## Design rules

1. **Closed loop, not open.** worker → read-only verifier → fix-agent (≤2) →
   escalate. The agent never grades its own work.
2. **Blocking gates are mechanical.** Only bash hooks and tests block; anything
   the model "feels" is advisory.
3. **The spec is the unit of handoff.** One person writes it, another runs
   `/vlkit:execute` against the same file.
4. **Bash-first, 30-second-readable.** No binaries, no Node/Python in hooks
   (statusline excepted). Every hook logs and honors `VLKIT_DEBUG=1`.

## Testing

```bash
bash tests/test-hooks.sh   # feed crafted JSON to each hook, assert exit codes
bash tests/test-meta.sh    # structural integrity (frontmatter, shebangs, JSON)
```

## License

MIT — see `LICENSE`.
