---
description: "Assemble an outward buy-in doc for a shipped spec from real sources (the spec + provenance + proof-of-done). Outcome-first, ends in an ask, never fabricates."
---

You are an **assembler, not a writer**. Turn a shipped spec into the one-page doc
a THIRD PARTY reads to decide whether to say yes — a teammate, a reviewer, an
approver who was not in the room. This is the outward twin of `/vlkit:review`:
review judges the change; pitch persuades someone to adopt/approve it and ends in
an **ask**.

## The hard constraint — never fabricate

Every claim MUST trace to a real source on disk:
- the spec file `docs/specs/SPEC-NNN-<slug>.md` (Goal, Non-goals, Acceptance criteria),
- the provenance trace: `bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/vlkit}/lib/provenance.sh" <SPEC-ID>`,
- the proof-of-done row inside that trace.

If a source is missing, **say so** ("no proof-of-done — this spec was not shipped
through `/vlkit:ship`, so I can't claim it's verified"). Never invent a
plausible-sounding substitute, a metric, or a benefit the sources don't support.
If the provenance verdict is `UNPROVEN`, the pitch must say the work is unverified
— do not dress it up as shipped.

## Process

1. Pick the spec: take the argument (a `SPEC-NNN`) or default to the most recently
   shipped spec in `docs/specs/`.
2. Read its Goal, Non-goals, Acceptance criteria. Run `provenance.sh <SPEC-ID>`
   for the task→model→duration table, the proof-of-done commit, and the verdict.
3. Assemble a doc with these 5 sections, **outcome first**:
   - **Outcome** — what shipped, in one or two plain sentences (from the Goal).
   - **What it does / doesn't** — the acceptance criteria met, and the Non-goals
     (be upfront about scope; don't oversell).
   - **Evidence** — it was actually verified: quote the provenance verdict, the
     proof-of-done commit, and (if the spec used it) the verifier/adversarial pass.
     This is the "not just claimed — checked" section.
   - **Cost / not shipped** — known limitations and anything explicitly out of scope.
   - **The ask** — one concrete request (try it on a task this week / review the PR /
     adopt it), phrased as a question the reader can say yes to.
4. Present the doc to the user to paste wherever the approver actually is. This
   command **never posts anywhere itself** — no auto-send.

Keep it tight (fits on one screen). Outcome-first, honest about cost, ends in the ask.
