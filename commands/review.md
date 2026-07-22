---
description: "Single-pass code review of the current change; record a verdict."
---

Review the working change against the spec and general quality bars. Advisory —
this does not block; it surfaces findings.

1. Get the diff (`git diff` and staged changes) and read the active spec.
2. Dispatch the `code-reviewer` agent for a focused pass, or review inline for a
   small change. Check: correctness, matches the spec's acceptance criteria,
   error handling, tests present, no secrets, no scope creep.
3. Report findings ranked by severity. For each: file:line, the problem, and a
   concrete fix. Distinguish **must-fix** from **nice-to-have**.
4. End with a one-line verdict: SHIP / FIX-FIRST. If FIX-FIRST, list the
   must-fixes so `/vlkit:execute` or a manual pass can address them.
