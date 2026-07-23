---
description: "Synthesize a reusable agent into the project's .claude/agents/ from a role description."
---

Create a new reusable sub-agent for THIS project by dispatching the `meta-agent`.
Use this when a role keeps coming up that no built-in agent covers (and you want
it saved, not synthesized ad-hoc each time).

1. Get the role from the user: what should this agent do, and is it read-only
   (a reviewer/researcher) or a worker (may edit)?
2. Derive a kebab-case `<name>` and the target path
   `.claude/agents/<name>.md` in the current project (create `.claude/agents/`
   if missing).
3. Dispatch the **meta-agent** with the role description and that target path.
   It writes a valid agent definition there — least-privilege `tools` for the
   role (read-only roles get no Edit/Write), a focused prompt body with Method
   and Output sections.
4. Report the path written. Note it is **project-scoped** and
   version-controlled, and loads on the **next** Claude Code session.

For a one-off role you don't need to keep, skip this — just dispatch a
specialized worker inline from `/vlkit:execute` or `/vlkit:dispatch` instead.
