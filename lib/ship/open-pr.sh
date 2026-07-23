#!/bin/bash
# open-pr.sh — open a PR for a pushed branch via gh, or fall back to printing the
# GitHub compare URL when gh is missing/unauthenticated. NEVER fails the ship:
# the fallback path always exits 0 with a clear next step.
#
# Usage: open-pr.sh <branch> [base]
# Env:   VLKIT_SHIP_NO_GH=1  forces the fallback (skip gh entirely).

set -euo pipefail
BRANCH="${1:?usage: open-pr.sh <branch> [base]}"
BASE="${2:-main}"

# Derive owner/repo from the origin remote. Handles:
#   git@github.com-alias:owner/repo.git   (ssh alias)
#   git@github.com:owner/repo.git         (plain ssh)
#   https://github.com/owner/repo.git     (https)
derive_slug() {
  local url; url="$(git remote get-url origin 2>/dev/null || echo "")"
  url="${url%.git}"
  url="${url#*github.com*:}"        # ssh: strip up to the ':' that follows github.com[-alias]
  url="${url#https://github.com/}"  # https
  url="${url#git@github.com:}"      # plain ssh (belt + suspenders)
  printf '%s' "$url"
}

SLUG="$(derive_slug)"
COMPARE="https://github.com/${SLUG}/compare/${BASE}...${BRANCH}?expand=1"

if [ "${VLKIT_SHIP_NO_GH:-0}" != "1" ] && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  if gh pr create --head "$BRANCH" --base "$BASE" --fill; then
    exit 0
  fi
  echo "(gh pr create failed — falling back to a manual link)" >&2
fi

echo "Open the PR manually — branch '$BRANCH' is pushed:"
echo "  $COMPARE"
exit 0
