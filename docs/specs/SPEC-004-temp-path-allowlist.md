# SPEC-004: widen safety-gate rm -rf allowlist to OS temp roots

Status: SHIPPED
Lane: bug
Date: 2026-07-23

## Goal

`safety-gate` blocks `rm -rf` unless the path matches a build-artifact
allowlist. On macOS, `mktemp -d` returns `/var/folders/...` and this session's
scratch lives under `/private/tmp/...`, neither of which is allowlisted — so
routine temp cleanup gets blocked (observed live during SPEC-002/003 work). Add
the standard OS temp roots to the allowlist so legitimate temp cleanup passes,
without weakening the block on real project paths.

## Non-goals

- No general weakening — only well-known ephemeral temp roots are added. Deletes
  of project/source/home paths must still block.
- No `$TMPDIR` env expansion (dynamic, unmatchable in a static path scan); the
  literal macOS/Linux temp roots cover the real cases.

## Tasks

1. In `hooks/safety-gate.sh`, add `/var/folders/`, `/private/var/folders/`, and
   `/private/tmp/` to the `rm -rf` allowlist regex (keeping the existing
   `node_modules|dist|build|.next|target|coverage|.cache|/tmp/`).
2. Add regression cases to `tests/test-hooks.sh`: `rm -rf` on a `/var/folders/…`
   path and on a `/private/tmp/…` path are allowed (rc 0); `rm -rf` on a project
   source path stays blocked (rc 2).

## Acceptance criteria

1. `safety-gate` returns rc 0 for `rm -rf /var/folders/x1/abc/T/tmp.XXXX`.
2. `safety-gate` returns rc 0 for `rm -rf /private/tmp/claude-501/scratch`.
3. `safety-gate` still returns rc 2 for `rm -rf /Users/me/project/src` (no
   regression to the real-path block).
4. `bash tests/test-hooks.sh` exits 0 with the new cases included; the other
   three suites (`test-meta.sh`, `test-lib.sh`, `test-dispatch.sh`) still exit 0.

## Verify

```bash
bash tests/test-hooks.sh
bash tests/test-meta.sh
bash tests/test-lib.sh
bash tests/test-dispatch.sh
```
