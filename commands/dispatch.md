---
description: "Parallel sibling of execute: run independent tasks in git worktrees per wave, merge sequentially."
---

You are the dispatch orchestrator — the parallel version of `/vlkit:execute`.
Independent tasks run at the same time, each in its own git worktree; merges are
**sequential** and a conflict **stops the run** (never auto-resolved).

**Input:** a `docs/specs/SPEC-NNN-*.md` with tasks that may declare
`(deps: <ids>)`. If several specs qualify, ask which.

**Plan the waves:**
```
bash ~/.claude/vlkit/lib/dispatch/waves.sh <spec-file>
```
This prints `wave N: <ids…>`. Tasks in the same wave are independent and run in
parallel; later waves depend on earlier ones.

**Per wave, in order:**

1. **Provision** a worktree for each task in the wave:
   `bash ~/.claude/vlkit/lib/dispatch/worktree.sh provision <task-id>` — it
   prints the worktree path (branch `vlkit/<task-id>` off HEAD).
2. **Dispatch workers in parallel** — one Agent per task, **in a single message**
   so they run concurrently. Use a built-in specialized agent where one fits, or
   **synthesize one via the `meta-agent`** (persist with `/vlkit:draft-agent`)
   when no built-in covers the role. Each worker runs on its resolved model
   (`vlkit-config.sh model <weight>` from the task's `[light]/[heavy]` tag) and
   works ONLY inside its own worktree path. Record
   `gate-ledger.sh run-start <SPEC> <task> <model>` before and
   `run-end <SPEC> <task>` after each.
3. **Verify each** with the `task-verifier` agent (read-only) against its
   acceptance criteria. A task that fails routes to `fix-agent` (≤2), same as
   `/vlkit:execute`.
4. **Merge sequentially** — for each passed task, in id order:
   `bash ~/.claude/vlkit/lib/dispatch/worktree.sh merge <task-id>`.
   - `MERGED <id>` → continue.
   - `CONFLICT <id> <files>` → **STOP the whole run**. Report the conflicting
     files and which two tasks collided. Do not merge anything else, do not
     attempt to auto-resolve — hand it to the human (or a follow-up task).
5. **Cleanup** merged worktrees: `worktree.sh cleanup <task-id>`.

After all waves merge cleanly, run the spec's Verify commands once end-to-end,
then show `stats timeline <SPEC>` so the parallel overlap and the closed gap are
visible. Hand off to `/vlkit:review` and `/vlkit:ship`.
