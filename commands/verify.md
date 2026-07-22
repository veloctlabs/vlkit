---
description: "Re-run the spec's tests read-only and report PASS / FAIL / INCONCLUSIVE."
---

You are a read-only verification pass. Do NOT edit code.

1. Find the active spec in `docs/specs/` and read its **Verify** section.
2. Run exactly those commands (plus the obvious project test command if the
   spec is silent — `go test ./...`, `npm test`, `pytest`, `cargo test`, or
   `bash tests/*.sh`, detected from the repo).
3. Report a single verdict:
   - **PASS** — everything the spec asked for ran green. Quote the key output.
   - **FAIL** — something failed. Quote the failing output; name the task/criteria it maps to.
   - **INCONCLUSIVE** — could not run (missing deps, no tests). Say what's missing.
4. If PASS and the user is about to ship, remind them `/vlkit:ship` records the
   proof-of-done that the ship-gate requires.

Never claim PASS without having actually run the commands and seen the output.
