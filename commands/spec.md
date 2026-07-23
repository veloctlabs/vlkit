---
description: "Write the spec contract to docs/specs/SPEC-NNN-<slug>.md."
---

You write the **contract** that `/vlkit:execute` will build against. The spec is
the unit of handoff — someone who never saw this conversation must be able to
build the right thing from it alone.

1. Determine the next spec number: look in `docs/specs/`, take the highest
   `SPEC-NNN` and add one (start at 001). Create `docs/specs/` if missing.
2. Pick a short kebab-case slug from the change.
3. Write `docs/specs/SPEC-NNN-<slug>.md` with EXACTLY these sections:

```
# SPEC-NNN: <title>

Status: DRAFT
Lane: <tiny|normal|full|bug>
Date: <YYYY-MM-DD>

## Goal
<2-4 sentences: what and why>

## Non-goals
<explicit out-of-scope, YAGNI>

## Tasks
1. <task> — <one line>
2. [heavy] <task> — <one line>   # optional [light]/[heavy] weight tag picks the worker model (see [models] in vlkit.toml); no tag = default
3. ...

## Acceptance criteria
1. <verifiable, numbered — how the verifier decides PASS>
2. ...

## Verify
<the exact commands the task-verifier runs, e.g. `go test ./...`>
```

4. Keep acceptance criteria **verifiable** (a read-only agent must be able to
   check each one). No "works well" — say what output/exit proves it.
5. Report the path and tell the user to review it, then run `/vlkit:execute`.

Do NOT write implementation code in this command.
