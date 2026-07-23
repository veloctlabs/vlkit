# SPEC-003: parallel dispatch via git worktrees

Status: SHIPPED
Lane: full
Date: 2026-07-23

## Goal

Add `/vlkit:dispatch`: run a spec's independent tasks **in parallel**, each in
its own git worktree, then **merge them back sequentially**, surfacing (never
auto-resolving) conflicts. It reuses SPEC-002's `[light]`/`[heavy]` weights (so
each parallel worker runs on its resolved model) and the run ledger (so
`stats timeline` shows the real overlap and the closed parallel gap). This is
the capability behind the screenshot's wavefront dispatch and its "-64% wall
clock" number.

## Non-goals

- **No disjointness gate.** We do NOT statically check whether two tasks touch
  the same file. Each task gets a fully isolated worktree; collisions are caught
  at merge time, not prevented.
- **No auto merge-conflict resolution.** On conflict the merge aborts cleanly,
  the conflict is reported, and the run stops for a human/agent to resolve.
- No cross-machine or daemon orchestration; no DAG scheduler beyond wave
  grouping computed once at dispatch time.
- The actual parallel *worker* execution is the orchestrator dispatching several
  Agents at once (out of scope for the bash lib); this spec builds the worktree
  plumbing, the wave planner, and the command that drives them.

## Design notes (for the implementer)

- **Waves.** A spec task line MAY declare dependencies:
  `3. [heavy] token-ledger (deps: 1 2) — ...`. `lib/dispatch/waves.sh <spec>`
  parses task numbers + `deps:` and emits waves by Kahn topological grouping:
  wave 1 = tasks with no deps; wave N = tasks whose deps all appear in earlier
  waves. Output one line per wave: `wave <n>: <id> <id> ...`. A dependency cycle
  is reported on stderr and exits non-zero.
- **Worktrees.** `lib/dispatch/worktree.sh`:
  - `provision <id> [base]` → `git worktree add .vlkit/worktrees/<id> -b vlkit/<id> <base|HEAD>`; prints the worktree path.
  - `merge <id> [base]` → from the base checkout, `git merge --no-ff vlkit/<id>`.
    On success print `MERGED <id>`; on conflict run `git merge --abort`, print
    `CONFLICT <id>` plus the conflicting paths, exit non-zero.
  - `cleanup <id>` → `git worktree remove --force` + delete branch `vlkit/<id>`.
  - `list` → active `vlkit/*` worktrees.
- **Ledger.** The command records `run-start`/`run-end` (SPEC-002) around each
  parallel task, so overlapping bars appear in `stats timeline` and `worker` >
  `wall` demonstrates the speedup.
- All worktree state lives under `<project>/.vlkit/worktrees/` (already
  git-ignored via `.vlkit/`).

## Tasks

1. Add `lib/dispatch/waves.sh` — parse a spec's tasks + `deps:` and print waves
   by topological grouping; detect and reject cycles (stderr + non-zero).
2. Add `lib/dispatch/worktree.sh` with `provision` / `merge` / `cleanup` /
   `list` as described; `merge` aborts and reports on conflict.
3. Add `commands/dispatch.md`: compute waves, then per wave provision worktrees,
   dispatch one worker per task in parallel on its resolved model (record
   run-start/run-end), verify each with `task-verifier`, then merge the wave's
   branches sequentially — stopping and reporting on any `CONFLICT`. Cleanup
   merged worktrees.
4. Register `dispatch` in the installer's command set (it is picked up
   automatically by the `commands/*.md` glob — confirm no code change needed and
   note it) and document that `/vlkit:dispatch` is the parallel sibling of
   `/vlkit:execute`.
5. Add `tests/test-dispatch.sh` — in a throwaway temp git repo: (a) `waves.sh`
   groups a known DAG into the expected waves and rejects a cycle; (b)
   `worktree.sh provision` creates the worktree + `vlkit/<id>` branch; (c) a
   non-conflicting `merge` prints `MERGED` and lands the change on base; (d) a
   conflicting `merge` prints `CONFLICT`, leaves base un-merged (no conflict
   markers committed), and exits non-zero; (e) `cleanup` removes worktree +
   branch. Keep the other test suites green.
6. Update `README.md` and `MANUAL.md`: `/vlkit:dispatch`, the `deps:` task
   syntax, worktree location, and the "merge is sequential, conflicts stop the
   run" contract.

## Acceptance criteria

1. `bash lib/dispatch/waves.sh <spec>` on a spec whose tasks are
   `1; 2; 3 (deps 1 2); 4 (deps 3)` prints `wave 1: 1 2`, `wave 2: 3`,
   `wave 3: 4` (ids in ascending order within a wave). A spec with a cycle
   exits non-zero with a stderr message containing `cycle`.
2. In a temp git repo, `worktree.sh provision t1` creates directory
   `.vlkit/worktrees/t1` and a branch `vlkit/t1` (`git branch --list vlkit/t1`
   is non-empty), rooted at HEAD.
3. After committing a non-conflicting change on `vlkit/t1`, `worktree.sh merge
   t1` prints `MERGED t1`, exits 0, and the change is present on the base branch.
4. With two branches that edit the same line, merging the second prints
   `CONFLICT <id>`, exits non-zero, and `git status` on base shows a clean tree
   (the merge was aborted — no conflict markers, no half-merge).
5. `worktree.sh cleanup t1` removes `.vlkit/worktrees/t1` and deletes branch
   `vlkit/t1`.
6. `commands/dispatch.md` exists and references `waves.sh`, `worktree.sh`
   (provision + merge), `gate-ledger.sh run-start`, and the conflict-stop rule
   (grep-able).
7. `bash tests/test-hooks.sh`, `test-meta.sh`, `test-lib.sh`, and
   `test-dispatch.sh` all exit 0.

## Verify

```bash
bash tests/test-hooks.sh
bash tests/test-meta.sh
bash tests/test-lib.sh
bash tests/test-dispatch.sh
```
