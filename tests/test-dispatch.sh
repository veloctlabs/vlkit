#!/bin/bash
# test-dispatch.sh — waves planning + worktree provision/merge/conflict/cleanup.
# Builds a throwaway git repo; no Claude Code required.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAVES="$HERE/lib/dispatch/waves.sh"
WT="$HERE/lib/dispatch/worktree.sh"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

echo "waves grouping:"
SPEC=$(mktemp)
cat > "$SPEC" <<'EOF'
## Tasks
1. alpha — x
2. beta — y
3. [heavy] gamma (deps: 1 2) — z
4. delta (deps: 3) — w

## Acceptance criteria
EOF
OUT=$(bash "$WAVES" "$SPEC")
printf '%s\n' "$OUT" | grep -qx 'wave 1: 1 2' && ok || bad "wave1: got [$(printf '%s' "$OUT" | tr '\n' '/')]"
printf '%s\n' "$OUT" | grep -qx 'wave 2: 3'   && ok || bad "wave2"
printf '%s\n' "$OUT" | grep -qx 'wave 3: 4'   && ok || bad "wave3"
rm -f "$SPEC"

echo "cycle detection:"
CYC=$(mktemp)
cat > "$CYC" <<'EOF'
## Tasks
1. a (deps: 2) — x
2. b (deps: 1) — y

## End
EOF
if bash "$WAVES" "$CYC" >/dev/null 2>&1; then bad "cycle not rejected"; else ok; fi
rm -f "$CYC"

echo "worktree provision / merge / conflict / cleanup:"
REPO=$(mktemp -d)
(
  cd "$REPO"
  git init -q; git config user.email t@t.dev; git config user.name tester
  printf '.vlkit/\n' > .gitignore   # consumer repos ignore vlkit's worktree dir (as vlkit itself does)
  printf 'line1\nline2\nline3\n' > f.txt
  git add -A; git commit -qm "feat: base"

  # non-conflicting: t1 appends a line, merge should land
  bash "$WT" provision t1 >/dev/null
  git branch --list vlkit/t1 | grep -q vlkit/t1 || echo FLAG:nobranch
  ( cd .vlkit/worktrees/t1 && printf 'line1\nline2\nline3\nline4\n' > f.txt && git add -A && git commit -qm "feat: add line4" )
  M=$(bash "$WT" merge t1); [ "$M" = "MERGED t1" ] || echo "FLAG:mergefail($M)"
  grep -q line4 f.txt || echo FLAG:noland

  # conflicting: t2 edits line1, base also edits line1 → CONFLICT + clean abort
  bash "$WT" provision t2 >/dev/null
  ( cd .vlkit/worktrees/t2 && printf 'CHANGED\nline2\nline3\nline4\n' > f.txt && git add -A && git commit -qm "feat: t2 line1" )
  printf 'BASEEDIT\nline2\nline3\nline4\n' > f.txt && git add -A && git commit -qm "feat: base line1"
  if bash "$WT" merge t2 > m2.out 2>m2.err; then echo FLAG:conflictnotdetected; fi
  grep -q "CONFLICT t2" m2.out || echo FLAG:noconflictmsg
  [ -z "$(git status --porcelain --untracked-files=no)" ] || echo FLAG:dirtyafterabort
  grep -q '<<<<<<<' f.txt && echo FLAG:markers

  # cleanup removes worktree + branch
  bash "$WT" cleanup t1 >/dev/null; bash "$WT" cleanup t2 >/dev/null
  git branch --list vlkit/t1 | grep -q . && echo FLAG:t1branchleft
  [ -d .vlkit/worktrees/t1 ] && echo FLAG:t1dirleft
) > "$REPO/out.txt" 2>&1

check() { if grep -q "FLAG:$1" "$REPO/out.txt"; then bad "$2"; else ok; fi; }
check nobranch           "provision did not create branch"
check "mergefail"        "non-conflicting merge failed"
check noland             "merge did not land the change"
check conflictnotdetected "conflict not detected"
check noconflictmsg      "no CONFLICT message on stdout"
check dirtyafterabort    "base tree dirty after abort"
check markers            "conflict markers left in file"
check t1branchleft       "cleanup left the branch"
check t1dirleft          "cleanup left the worktree dir"
rm -f "$REPO/out.txt" "$REPO/m2.out" "$REPO/m2.err" 2>/dev/null

echo "-----------------------------------------"
echo "dispatch: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
