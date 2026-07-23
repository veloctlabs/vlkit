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
   `bash ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/vlkit}/lib/gate/gate-ledger.sh proof SPEC-NNN "$(git rev-parse --short HEAD)"`
5. **Publish.** Push the **branch** (never main — the safety-gate blocks a direct
   main push; always a PR). Then open the PR with the fallback-safe helper:
   `bash ${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/vlkit}/lib/ship/open-pr.sh <branch> [base]`. It uses `gh pr
   create --fill` when `gh` is available and authenticated, and otherwise prints
   the GitHub compare URL for you to open the PR manually — so ship always
   finishes even when `gh` isn't set up. Add a PR body summarizing the spec, the
   change, and how it was verified.
6. Tell the user to run `/vlkit:retro` after merge.
