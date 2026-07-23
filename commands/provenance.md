---
description: "Emit a machine-checkable provenance trace for a spec (spec → task→model → proof → commit)."
---

Produce the provenance trace for a shipped (or in-progress) spec — the record of
how it was built and verified, straight from the gate ledger.

1. Take the spec id (e.g. `SPEC-006`); if omitted, use the most recently shipped
   spec in `docs/specs/`.
2. Run `bash ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/vlkit}/lib/provenance.sh <spec>` for the human-readable
   markdown trace, or `... <spec> --json` for a machine-readable object.
3. Present it: the table of task → model → duration, the proof-of-done commit,
   and the verdict (`shipped` vs `UNPROVEN` if no proof row exists).

Use this to answer "how was this change produced and verified?" — for a review,
a PR body, an audit, or a thesis methodology section. It asserts nothing the
ledger doesn't already record; an `UNPROVEN` verdict means the work never passed
through `/vlkit:ship`.
