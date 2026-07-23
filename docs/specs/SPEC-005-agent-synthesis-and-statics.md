# SPEC-005: dynamic agent synthesis + curated static agents

Status: SHIPPED
Lane: full
Date: 2026-07-23

## Goal

Give vlkit the ability to **synthesize an agent on demand** (a `meta-agent` that
writes agent definitions, plus `/vlkit:draft-agent` to persist reusable ones into
the current project's `.claude/agents/`), and add **four high-value static
agents** for roles used often: `security-reviewer`, `test-writer`, `researcher`,
`db-migration-worker`. This grows coverage the vlkit way — one strong synthesis
mechanism plus a curated few, not 24 cargo-culted files. Built via
`/vlkit:dispatch` to exercise SPEC-003's parallel worktrees on real work.

## Non-goals

- Not cloning dwarves-kit's full agent roster; only the four that earn their keep.
- Drafted agents are **project-scoped** (`.claude/agents/`), version-controlled;
  no global `~/.claude/agents/` writes by draft-agent.
- No agent-effectiveness / self-tuning loop.

## Design notes

- **meta-agent** writes a new agent `.md` (valid frontmatter: `name`,
  `description`, constrained `tools`, `model`; then a focused prompt body) to a
  path it is given. It does not execute the drafted agent.
- **`/vlkit:draft-agent <role description>`** dispatches meta-agent to create
  `.claude/agents/<name>.md` in the current project, reports the path, and notes
  it loads next session.
- **On-the-fly synthesis:** `/vlkit:execute` and `/vlkit:dispatch` already say to
  dispatch a specialized worker when a task needs a role no built-in covers; add
  one line pointing at meta-agent / draft-agent for the persistent case.
- The four static agents follow the existing agent-file shape (see
  `agents/task-verifier.md`): reviewers/researchers are **read-only**; workers
  (`test-writer`, `db-migration-worker`) may edit within their task scope.

## Tasks

1. Add `agents/meta-agent.md` — synthesizes a valid agent definition file to a given path (read + write).
2. Add `agents/security-reviewer.md` — read-only; audits a diff for injection, secret exposure, authz/ownership gaps, path traversal, unsafe deserialization.
3. Add `agents/test-writer.md` — worker; writes tests covering a change (edit + run test tools).
4. Add `agents/researcher.md` — read-only; investigates architecture, prior art, stack conventions, and likely pitfalls before a spec; returns a findings brief.
5. Add `agents/db-migration-worker.md` — worker; writes reversible DB migrations (up/down), guards against destructive DDL.
6. Add `commands/draft-agent.md` (deps: 1) — `/vlkit:draft-agent`: dispatch meta-agent to write `.claude/agents/<name>.md` in the project; report path.
7. Wire + verify (deps: 1 2 3 4 5 6) — add the on-the-fly synthesis line to `commands/execute.md` and `commands/dispatch.md`; update `README.md`/`MANUAL.md` agent list; confirm `test-meta.sh` validates the new agents; keep all suites green.

## Acceptance criteria

1. Files `agents/meta-agent.md`, `agents/security-reviewer.md`,
   `agents/test-writer.md`, `agents/researcher.md`,
   `agents/db-migration-worker.md` all exist, each with `name:` and
   `description:` frontmatter and a non-empty prompt body.
2. Read-only agents (`security-reviewer`, `researcher`, `meta-agent` sans exec)
   do NOT grant blanket write to the codebase beyond their stated scope
   (meta-agent writes agent files only; security-reviewer/researcher have no
   Edit/Write of source). `test-writer` and `db-migration-worker` may edit.
3. `commands/draft-agent.md` exists, references `meta-agent`, and writes drafted
   agents under `.claude/agents/` (grep-able).
4. `commands/execute.md` and `commands/dispatch.md` each reference on-the-fly
   synthesis via meta-agent / draft-agent (grep-able).
5. `bash tests/test-meta.sh` exits 0 with the five new agents present (its
   agent-frontmatter check now covers them).
6. `bash tests/test-hooks.sh`, `test-lib.sh`, `test-dispatch.sh` still exit 0.
7. README and MANUAL list the new agents and the `/vlkit:draft-agent` command.

## Verify

```bash
bash tests/test-meta.sh
bash tests/test-hooks.sh
bash tests/test-lib.sh
bash tests/test-dispatch.sh
ls agents/meta-agent.md agents/security-reviewer.md agents/test-writer.md agents/researcher.md agents/db-migration-worker.md
```
