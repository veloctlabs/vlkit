# SPEC-007: ship PR fallback when gh is unavailable

Status: SHIPPED
Lane: bug
Date: 2026-07-23

## Goal

`/vlkit:ship` opens a PR with `gh`. When `gh` is missing or unauthenticated
(observed: the token here is invalid), the flow gets stuck instead of finishing.
Add a helper that opens the PR via `gh` when it works, and otherwise falls back
to printing the GitHub **compare URL** for the pushed branch — so ship always
completes with a clear next step, never a dead end.

## Non-goals

- No direct-to-`main` push fallback (that defeats the branch+PR discipline the
  safety-gate enforces); the fallback is a manual-PR link, not a main push.
- No `gh` auth automation; if `gh` is unauthenticated we just link out.

## Design notes

- `lib/ship/open-pr.sh <branch> [base]`: derive `owner/repo` from
  `git remote get-url origin` (handles `git@host[-alias]:owner/repo.git`,
  `git@github.com:owner/repo.git`, and `https://github.com/owner/repo.git`).
  If `gh` exists AND `gh auth status` succeeds, run `gh pr create --head
  <branch> --base <base> --fill`; on success exit 0. Otherwise (or on gh
  failure) print `https://github.com/<slug>/compare/<base>...<branch>?expand=1`
  with a "open the PR here" message and exit 0 (never fails the ship).
- `VLKIT_SHIP_NO_GH=1` forces the fallback path (for tests / deliberate use).
- `commands/ship.md` step 5 calls `open-pr.sh` instead of a bare `gh pr create`.

## Tasks

1. Add `lib/ship/open-pr.sh` (derive slug, gh-or-fallback, `VLKIT_SHIP_NO_GH`
   override).
2. Update `commands/ship.md` to push the branch then call `open-pr.sh`, and note
   the fallback behavior.
3. Add `tests/test-ship.sh` covering slug derivation (ssh-alias, plain-ssh,
   https) and the forced-fallback compare-URL output; keep all suites green.
4. Note the fallback in `MANUAL.md`.

## Acceptance criteria

1. `bash lib/ship/open-pr.sh` with `VLKIT_SHIP_NO_GH=1`, in a repo whose origin
   is `git@github.com-yuzuyield:veloctlabs/vlkit.git`, prints a line containing
   `https://github.com/veloctlabs/vlkit/compare/main...<branch>?expand=1` and
   exits 0.
2. Slug derivation is correct for all three remote URL forms
   (`git@github.com-alias:o/r.git`, `git@github.com:o/r.git`,
   `https://github.com/o/r.git`) — verified in a temp repo per form.
3. `open-pr.sh` never exits non-zero on the fallback path (ship must not break
   when gh is absent).
4. `commands/ship.md` references `open-pr.sh` (grep-able) and no longer relies
   on a bare `gh pr create` as the only path.
5. `bash tests/test-ship.sh` exits 0; `test-hooks.sh`, `test-meta.sh`,
   `test-lib.sh`, `test-dispatch.sh`, `test-provenance.sh` still exit 0.
6. `MANUAL.md` documents the gh fallback.

## Verify

```bash
bash tests/test-ship.sh
bash tests/test-hooks.sh
bash tests/test-meta.sh
bash tests/test-lib.sh
bash tests/test-dispatch.sh
bash tests/test-provenance.sh
```
