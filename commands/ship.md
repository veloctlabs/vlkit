---
description: "Verify gate → version bump → changelog → conventional commit → PR, and record proof-of-done."
---

You ship the change. The ship-gate hook will BLOCK a push/PR unless a
proof-of-done row exists for HEAD — this command is what writes that row, so
follow the order exactly.

1. **Verify first.** Run the spec's Verify commands (or `/vlkit:verify`'s
   detection). If anything fails, STOP — do not ship.
2. **Version + changelog.** Bump `VERSION` (or the project's version file) per
   the change's semver impact. Add a changelog entry if the project keeps one.
3. **Commit.** Stage the change and commit with a conventional-commit subject
   (the commit-format hook enforces this). Reference the spec ID in the body.
4. **Record proof-of-done** so the ship-gate opens:
   `bash ~/.claude/vlkit/lib/gate/gate-ledger.sh proof SPEC-NNN "$(git rev-parse --short HEAD)"`
5. **Publish.** Push the branch and open a PR (`gh pr create`) with a body that
   summarizes the spec, the change, and how it was verified.
   Never push to main directly — the safety-gate blocks it; always a PR.
6. Tell the user to run `/vlkit:retro` after merge.
