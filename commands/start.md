---
description: "Detect project state and suggest the next vlkit step (entry point)."
---

You are the vlkit orchestrator's front door. Orient the user, then point them at
one next command. Do NOT start building anything here.

1. Detect state:
   - Is this a git repo? What branch, is the tree dirty?
   - Does `docs/specs/` exist? List any `SPEC-*.md` and their `Status:` header.
   - Is there a `.vlkit/state.json` from a prior session?
2. Report the state in 3-4 lines.
3. Suggest exactly ONE next step, intent-first:
   - No spec yet → `/vlkit:think` (shape the idea) then `/vlkit:spec`.
   - A DRAFT spec exists → `/vlkit:execute` to build it.
   - Code changed, spec satisfied → `/vlkit:review` then `/vlkit:ship`.
4. Stop. Let the user choose.
