# SPEC-002: model-per-task assignment + run timeline

Status: SHIPPED
Lane: full
Date: 2026-07-23

## Goal

Let a spec assign a **model** to each task by weight (light work on a cheaper
model, heavy work on a stronger one), and record each task's real start/end so a
`stats timeline` view can render an ASCII Gantt plus wall-clock / worker-time /
parallel-potential numbers from the ledger. This is the cheap, low-risk half of
the "multi-model + parallel" work; SPEC-003 adds actual parallel dispatch and
consumes the same weight annotations and run ledger this spec establishes.

## Non-goals

- No parallel execution — tasks still run sequentially (that is SPEC-003).
- No heuristic/auto model selection — the model comes only from the task's
  explicit weight tag and the `[models]` config map.
- No web dashboard — the timeline renders to the terminal / markdown.
- No new model names invented — weights map to existing Claude tiers via config.

## Design notes (for the implementer)

- **Weight tag in a spec task:** a task line MAY carry a leading `[light]` or
  `[heavy]` tag right after the number, e.g. `3. [heavy] token-ledger — ...`.
  No tag = the default weight.
- **Model map** lives in `vlkit.toml` `[models]`: `default`, `light`, `heavy`
  keys whose values are model names (e.g. `sonnet`, `opus`). Resolver returns
  `models.<weight>` else `models.default` else `sonnet`.
- **Run ledger events** reuse `gate-ledger.sh record`, with the epoch stored in
  the note field so `stats` needs no cross-platform date parsing:
  - `run-start <spec> <task> <model>` → appends a `run-start` row, note
    `model=<model>;epoch=<secs>`.
  - `run-end <spec> <task>` → appends a `run-end` row, note `epoch=<secs>`.
- **timeline math:** pair run-start/run-end by `(spec,task)`; duration =
  end.epoch − start.epoch. `wall = max(end) − min(start)`, `worker = Σ duration`,
  `parallel_potential = max(duration)` (the floor if every task ran at once).

## Tasks

1. Add a `[models]` section to `vlkit.toml` (`default`/`light`/`heavy`) with
   comments, and document the `[light]`/`[heavy]` task-tag syntax in
   `commands/spec.md`'s task template.
2. Add `model <weight>` to `lib/config/vlkit-config.sh` — resolve
   `models.<weight>` → `models.default` → `sonnet`.
3. Add `run-start` and `run-end` verbs to `lib/gate/gate-ledger.sh` that append
   the rows described in Design notes (epoch in the note, via `date +%s`).
4. Add `timeline [spec]` to `lib/stats/stats.sh`: parse run-start/run-end,
   print one line per task (`<task>  <model>  <duration>  <bar>`) and a summary
   block (`wall`, `worker`, `parallel_potential`). No external date parsing.
5. Update `commands/execute.md` so the orchestrator: (a) reads each task's
   weight tag, (b) resolves the model via `vlkit-config.sh model <weight>` and
   dispatches the worker on that model, (c) calls `gate-ledger.sh run-start`
   before and `run-end` after each task.
6. Add `tests/test-lib.sh` covering: `vlkit-config.sh model heavy` returns the
   configured heavy model; `run-start`/`run-end` append parseable rows;
   `stats.sh timeline` prints a task row and a `wall`/`worker` summary for a
   seeded ledger. Wire it into any test runner and keep `test-meta.sh` green.
7. Update `README.md` and `MANUAL.md`: weight syntax, `[models]` config, and the
   `stats timeline` command.

## Acceptance criteria

1. `bash lib/config/vlkit-config.sh model heavy` prints the `[models] heavy`
   value from a `.vlkit.toml`/`vlkit.toml`; `model unknuown` falls back to the
   `default` value; with no config it prints `sonnet`.
2. After `gate-ledger.sh run-start S T opus` then `gate-ledger.sh run-end S T`,
   the ledger file (from `gate-ledger.sh path`) contains one `run-start` row
   whose note has `model=opus` and an `epoch=`, and one `run-end` row with an
   `epoch=`.
3. `bash lib/stats/stats.sh timeline` on a ledger seeded with one completed run
   prints a line containing the task name and its model, and a summary block
   containing the literal labels `wall`, `worker`, and `parallel_potential`.
4. `commands/execute.md` contains instructions that reference
   `vlkit-config.sh model` and `gate-ledger.sh run-start`/`run-end` (grep-able).
5. `commands/spec.md` documents the `[light]`/`[heavy]` task tag.
6. `bash tests/test-hooks.sh`, `bash tests/test-meta.sh`, and
   `bash tests/test-lib.sh` all exit 0.
7. No regression: the nine existing hooks are unchanged in behavior (test-hooks
   still passes).

## Verify

```bash
bash tests/test-hooks.sh
bash tests/test-meta.sh
bash tests/test-lib.sh
bash lib/config/vlkit-config.sh model heavy
bash lib/stats/stats.sh timeline
```
