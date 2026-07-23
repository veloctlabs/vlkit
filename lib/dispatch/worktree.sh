#!/bin/bash
# worktree.sh — isolated git worktrees for parallel task execution, with a
# sequential, conflict-surfacing merge. No disjointness gate (by design,
# SPEC-003): collisions are caught here at merge time, never auto-resolved.
#
# Usage:
#   worktree.sh provision <id> [base]   # add .vlkit/worktrees/<id> on branch vlkit/<id>
#   worktree.sh merge <id>              # merge vlkit/<id> into the current base checkout
#   worktree.sh cleanup <id>            # remove the worktree + branch
#   worktree.sh list                    # list active vlkit worktrees

set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "worktree.sh: not a git repo" >&2; exit 1; }
WT_DIR="$ROOT/.vlkit/worktrees"

provision() {  # <id> [base]
  local id="${1:?id}" base="${2:-HEAD}"
  mkdir -p "$WT_DIR"
  git worktree add "$WT_DIR/$id" -b "vlkit/$id" "$base" >/dev/null
  echo "$WT_DIR/$id"
}

merge() {  # <id>
  local id="${1:?id}" files
  if git merge --no-ff --no-edit "vlkit/$id" >/dev/null 2>&1; then
    echo "MERGED $id"; return 0
  fi
  files=$(git diff --name-only --diff-filter=U 2>/dev/null | tr '\n' ' ')
  git merge --abort 2>/dev/null || true
  echo "CONFLICT $id ${files}" >&2
  echo "CONFLICT $id"
  return 1
}

cleanup() {  # <id>
  local id="${1:?id}"
  git worktree remove --force "$WT_DIR/$id" 2>/dev/null || true
  git branch -D "vlkit/$id" 2>/dev/null || true
  echo "cleaned $id"
}

list() { git worktree list 2>/dev/null | grep -F "$WT_DIR/" || true; }

case "${1:-}" in
  provision) shift; provision "$@" ;;
  merge)     shift; merge "$@" ;;
  cleanup)   shift; cleanup "$@" ;;
  list)      list ;;
  *) echo "usage: worktree.sh {provision <id> [base]|merge <id>|cleanup <id>|list}" >&2; exit 1 ;;
esac
