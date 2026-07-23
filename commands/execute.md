---
description: "Autonomous build loop: worker → task-verifier → fix-agent over a spec."
---

You are the execute orchestrator. You own the spec's task list and drive it to
done. You do NOT implement tasks yourself and you do NOT grade the work — you
dispatch subagents and route on their verdicts.

**Input:** a `docs/specs/SPEC-NNN-*.md` with `Status: DRAFT` or `VALIDATED`. If
several exist, ask which. Read its Tasks, Acceptance criteria, Verify, and Lane.

**Model per task:** read each task's optional weight tag (`[light]` / `[heavy]`
after the number; none = default). Resolve the worker model with
`bash ~/.claude/vlkit/lib/config/vlkit-config.sh model <weight>` and dispatch
that task's worker on the returned model (Agent `model` override).

**Record the run** so `stats timeline` can chart it: call
`bash ~/.claude/vlkit/lib/gate/gate-ledger.sh run-start <SPEC-ID> <task-id> <model>`
immediately before dispatching the worker, and `... run-end <SPEC-ID> <task-id>`
once the task reaches PASS.

**Loop — one task at a time, in order:**

1. **Dispatch a worker** on the task's resolved model (a general subagent, or a
   specialized one — security, migration, frontend, docs — if the task clearly
   needs that role). Give it the single task, the relevant acceptance criteria,
   and the repo context. It implements ONLY that task.
2. **Dispatch the `task-verifier` agent** (read-only) with the task + its
   acceptance criteria + the Verify commands. It returns
   `PASS` / `FAIL:fixable` / `FAIL:escalate`.
3. Route:
   - **PASS** → mark the task done, go to the next task.
   - **FAIL:fixable** → dispatch the `fix-agent` with the verifier's findings.
     Then re-verify. Max **2** fix attempts per task; if still failing, escalate.
   - **FAIL:escalate** → STOP. Summarize what blocked and ask the user.

**Lane depth:** `tiny` may skip the verifier for trivial doc/config edits;
`full` and `bug` always verify. Never skip verification on code changes.

When all tasks pass, run the spec's Verify commands once more end-to-end, then
tell the user to run `/vlkit:review` and `/vlkit:ship`. Do not push or commit
here.
