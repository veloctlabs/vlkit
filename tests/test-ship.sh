#!/bin/bash
# test-ship.sh — lib/ship/open-pr.sh slug derivation + forced-fallback URL.
# Uses throwaway git repos with different origin URL forms. No gh required.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENPR="$HERE/lib/ship/open-pr.sh"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

# run open-pr in a temp repo with the given origin url, forced fallback
url_for() {  # <origin-url> <branch>
  local url="$1" branch="$2" dir; dir="$(mktemp -d)"
  ( cd "$dir" && git init -q && git remote add origin "$url" \
      && VLKIT_SHIP_NO_GH=1 bash "$OPENPR" "$branch" main ) 2>/dev/null
}

echo "slug derivation across remote URL forms:"
OUT="$(url_for 'git@github.com-yuzuyield:yuzuyield/vlkit.git' featX)"
printf '%s' "$OUT" | grep -q 'github.com/yuzuyield/vlkit/compare/main...featX' && ok || bad "ssh-alias slug: $OUT"

OUT="$(url_for 'git@github.com:acme/widget.git' fix1)"
printf '%s' "$OUT" | grep -q 'github.com/acme/widget/compare/main...fix1' && ok || bad "plain-ssh slug: $OUT"

OUT="$(url_for 'https://github.com/octo/cat.git' devB)"
printf '%s' "$OUT" | grep -q 'github.com/octo/cat/compare/main...devB' && ok || bad "https slug: $OUT"

echo "fallback exits 0 and yields a usable link:"
D="$(mktemp -d)"
( cd "$D" && git init -q && git remote add origin 'git@github.com-yuzuyield:yuzuyield/vlkit.git' \
    && VLKIT_SHIP_NO_GH=1 bash "$OPENPR" branchZ main ); RC=$?
[ "$RC" = "0" ] && ok || bad "fallback exited non-zero ($RC)"
( cd "$D" && VLKIT_SHIP_NO_GH=1 bash "$OPENPR" branchZ main ) | grep -q 'expand=1' && ok || bad "no expand=1 link"

echo "-----------------------------------------"
echo "ship: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
