# SPEC-006: trust-hardening — spec-as-tests, adversarial verify, provenance

Status: SHIPPED
Lane: full
Date: 2026-07-23

## Goal

Make the closed loop *trustworthy*, not just automated — the thing every
prompt→loop kit (dwarves-kit included) leaves soft. Three moves that all attack
"how much can you trust a PASS?":

1. **Spec-as-tests** — `/vlkit:spec` emits a failing test skeleton mapped 1:1 to
   acceptance criteria, so the gate becomes *tests going green*, not a verifier
   agent reading prose and believing it.
2. **Adversarial verification** — instead of one verifier confirming, three
   verifiers each try to **refute**; PASS only if a majority cannot. Harder to
   fool than a single lenient reader.
3. **Provenance artifact** — every shipped change gets a machine-checkable
   trace (spec → task→model → verdict → proof-of-done → commit) from the ledger,
   emitted as markdown + JSON.

## Non-goals

- Not a coverage tool or mutation-testing engine; spec-as-tests generates
  skeletons the build then satisfies, not a coverage gate.
- Adversarial verify does not replace the single `task-verifier`; it is an
  opt-in stronger mode for high-stakes tasks.
- Provenance reads the existing ledger + git; it does not add new tracking
  infrastructure.

## Design notes

- **Spec-as-tests:** `commands/spec.md` gains a step: after acceptance criteria,
  detect the project's test framework and write a **failing** test per criterion
  (each test references the criterion number). If no framework is detected, write
  `docs/specs/SPEC-NNN.tests.md` — a numbered, checkable checklist. The criteria
  and tests must stay 1:1.
- **Adversarial verify:** new read-only agent `adversarial-verifier` prompted to
  REFUTE a claim, defaulting `refuted=true` when uncertain. `commands/verify.md`
  and `commands/execute.md` gain an adversarial mode: dispatch **3**
  `adversarial-verifier`s in parallel; the task PASSES only if **< 2** return
  refuted (i.e. majority fail to refute). Any 2+ refutations → FAIL with the
  refutations.
- **Provenance:** `lib/provenance.sh <spec> [--json]` reads the gate ledger
  (run-start/run-end/proof-of-done rows for the spec) and prints a trace:
  the spec id, each task with its model and duration, the proof-of-done commit,
  and a verdict line. `commands/provenance.md` wraps it for `/vlkit:provenance`.

## Tasks

1. Update `commands/spec.md` — add the spec-as-tests generation step (failing
   test per criterion, framework-detected or checklist fallback, kept 1:1).
2. Add `agents/adversarial-verifier.md` (read-only, refute-framed) and wire an
   adversarial mode into `commands/verify.md` and `commands/execute.md`
   (3 verifiers, majority-cannot-refute → PASS). (deps: none — file-disjoint
   from task 1 and 3.)
3. Add `lib/provenance.sh` (trace from the ledger, `--json` flag) and
   `commands/provenance.md`. (deps: none.)
4. Add `tests/test-provenance.sh` and update `README.md`/`MANUAL.md`; keep all
   suites green. (deps: 1 2 3.)

## Acceptance criteria

1. `commands/spec.md` instructs generating a **failing test skeleton** with one
   test per acceptance criterion (grep-able for "spec-as-tests" / "failing" /
   "one test per").
2. `agents/adversarial-verifier.md` exists, is read-only (NO Edit/Write in its
   `tools`), and its body instructs refuting with `refuted=true` on uncertainty.
3. `commands/verify.md` and `commands/execute.md` each describe the adversarial
   mode: **3** verifiers, PASS only if a majority cannot refute (grep-able for
   "adversarial" and "3" / "majority").
4. `bash lib/provenance.sh SPEC-X` on a ledger seeded with
   `run-start SPEC-X taskA opus`, `run-end SPEC-X taskA`, and
   `proof SPEC-X <sha>` prints output containing `SPEC-X`, `taskA`, `opus`, and
   `<sha>`. `--json` prints valid JSON (parses with `jq empty`).
5. `commands/provenance.md` exists and references `lib/provenance.sh`.
6. `bash tests/test-provenance.sh` exits 0; `test-hooks.sh`, `test-meta.sh`,
   `test-lib.sh`, `test-dispatch.sh` still exit 0.
7. `README.md` and `MANUAL.md` document all three: spec-as-tests, adversarial
   verify, and `/vlkit:provenance`.

## Verify

```bash
bash tests/test-hooks.sh
bash tests/test-meta.sh
bash tests/test-lib.sh
bash tests/test-dispatch.sh
bash tests/test-provenance.sh
bash lib/provenance.sh SPEC-006
```
