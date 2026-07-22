#!/bin/bash
# test-hooks.sh — feed crafted event JSON into each hook and assert exit code +
# stderr. No Claude Code required. Runs on macOS bash 3.2 and Linux.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VLKIT_LOG_DIR="$(mktemp -d)"
export VLKIT_ROOT="$HERE"
PASS=0; FAIL=0

# run <hook> <json> ; sets RC and ERR
run() {
  local hook="$1" json="$2"
  ERR="$(printf '%s' "$json" | bash "$HERE/hooks/$hook" 2>&1 >/dev/null)"; RC=$?
}

expect_rc() {  # <label> <want-rc>
  if [ "$RC" = "$2" ]; then PASS=$((PASS+1)); # echo "  ok: $1"
  else FAIL=$((FAIL+1)); echo "  FAIL: $1 — want rc=$2 got rc=$RC ${ERR:+($ERR)}"; fi
}

bash_json() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"; }
read_json() { printf '{"tool_name":"Read","tool_input":{"file_path":%s}}' "$(printf '%s' "$1" | jq -Rs .)"; }

echo "safety-gate:"
run safety-gate.sh "$(bash_json 'git push origin main')";            expect_rc "block push main" 2
run safety-gate.sh "$(bash_json 'git push origin feature/x')";       expect_rc "allow push feature" 0
run safety-gate.sh "$(bash_json 'git push --force origin dev')";     expect_rc "block force push" 2
run safety-gate.sh "$(bash_json 'rm -rf /some/project/src')";        expect_rc "block rm -rf src" 2
run safety-gate.sh "$(bash_json 'rm -rf node_modules')";             expect_rc "allow rm -rf node_modules" 0
run safety-gate.sh "$(bash_json 'git reset --hard HEAD~1')";         expect_rc "block reset --hard" 2
run safety-gate.sh "$(bash_json 'echo "do not rm -rf things"')";     expect_rc "prose not matched" 0
run safety-gate.sh "$(bash_json 'psql -c "DROP TABLE users"')";      expect_rc "block drop table" 2
run safety-gate.sh "$(bash_json 'ls -la && git status')";           expect_rc "allow safe compound" 0

echo "secrets-guard:"
run secrets-guard.sh "$(read_json '.env')";                          expect_rc "block .env read" 2
run secrets-guard.sh "$(read_json '/home/u/.ssh/id_rsa')";           expect_rc "block ssh key read" 2
run secrets-guard.sh "$(read_json 'src/app.ts')";                    expect_rc "allow source read" 0
run secrets-guard.sh "$(bash_json 'cat ~/.aws/credentials')";        expect_rc "block aws creds via bash" 2

echo "commit-format:"
run commit-format.sh "$(bash_json 'git commit -m "stuff"')";         expect_rc "block non-conventional" 2
run commit-format.sh "$(bash_json 'git commit -m "feat: add flag"')"; expect_rc "allow conventional" 0
run commit-format.sh "$(bash_json 'git commit -m "feat(auth): add refresh flow"')"; expect_rc "allow scoped" 0
run commit-format.sh "$(bash_json 'ls')";                            expect_rc "ignore non-commit" 0

echo "ship-gate:"
# From a temp NON-repo dir HEAD is empty → fail-open (rc 0).
ERR="$(cd "$VLKIT_LOG_DIR" && printf '%s' "$(bash_json 'git push origin x')" | bash "$HERE/hooks/ship-gate.sh" 2>&1 >/dev/null)"; RC=$?
expect_rc "no repo → fail-open" 0
# Override always allows.
export VLKIT_SHIP_OVERRIDE=1
run ship-gate.sh "$(bash_json 'git push origin main')";              expect_rc "override allows" 0
unset VLKIT_SHIP_OVERRIDE
# Non-publish command is ignored.
run ship-gate.sh "$(bash_json 'git status')";                        expect_rc "ignore non-publish" 0

echo "advisory hooks never block (rc 0):"
run context-readiness.sh '{}';                                       expect_rc "context-readiness rc0" 0
run context-hints.sh '{"prompt":"hello"}';                           expect_rc "context-hints rc0" 0
run anti-rationalization.sh '{}';                                    expect_rc "anti-rationalization rc0" 0
run session-state-save.sh '{}';                                      expect_rc "session-state-save rc0" 0

rm -rf "$VLKIT_LOG_DIR"
echo "-----------------------------------------"
echo "hooks: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
