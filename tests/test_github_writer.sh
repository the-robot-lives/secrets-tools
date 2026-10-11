#!/usr/bin/env bash
# Writer-safety tests for the github: secret-sync path in
# infisical-populate-secrets. Uses a mock gh that logs argv + stdin; asserts
# values reach gh ONLY via stdin and never appear in argv, stdout, stderr, an
# xtrace trace, the ledger, or any scratch file. Drives the SHIPPED functions
# (extract-and-eval) plus two end-to-end runs of the real script.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="${TEST_SCRATCH:-$(mktemp -d)}"
BIN="$ROOT/bin/infisical-populate-secrets"
PASS=0
FAIL=0

GH_ARGV_LOG="$SCRATCH/gh-argv.log"
GH_STDIN_LOG="$SCRATCH/gh-stdin.log"
export GH_ARGV_LOG GH_STDIN_LOG

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }
assert_file_has() { # <name> <pattern> <file>
  if grep -q -- "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1 ($3 lacks '$2')"; fi
}
assert_file_lacks() { # <name> <pattern> <file>
  if grep -q -- "$2" "$3" 2>/dev/null; then fail "$1 ($3 contains '$2')"; else pass "$1"; fi
}
expect_rc() { # <want-rc> <name> <cmd...>
  local want="$1" name="$2"; shift 2; local rc=0
  "$@" >/dev/null 2>"$SCRATCH/rc.err" || rc=$?
  if [[ "$rc" == "$want" ]]; then pass "$name"; else fail "$name (rc=$rc want=$want): $(head -1 "$SCRATCH/rc.err")"; fi
}

echo "== extract github-sync region + is_redaction_sentinel from shipped bin =="
# shellcheck disable=SC1090
eval "$(sed -n '/^# -- github-sync BEGIN --/,/^# -- github-sync END --/p' "$BIN")"
# shellcheck disable=SC1090
eval "$(sed -n '/^is_redaction_sentinel()/,/^}/p' "$BIN")"

# Region eval resets globals — configure AFTER it.
GH_BIN="$SCRATCH/mockbin/gh"
mkdir -p "$SCRATCH/mockbin" "$SCRATCH/ledgerdir"
cat > "$GH_BIN" <<'MOCKEOF'
#!/usr/bin/env bash
# Mock gh: logs full argv; for `secret set` captures stdin (the value) and can
# be told to fail a given secret name, echoing the value back on stderr to
# exercise the scrub path.
printf '%s\n' "$*" >> "${GH_ARGV_LOG:?}"
if [[ "${1:-}" == "secret" && "${2:-}" == "set" ]]; then
  v="$(cat)"
  printf '%s' "$v" >> "${GH_STDIN_LOG:?}"
  if [[ -n "${MOCK_SET_FAIL_NAME:-}" && "${3:-}" == "$MOCK_SET_FAIL_NAME" ]]; then
    printf 'gh: boom! value was >>%s<< (HTTP 403)\n' "$v" >&2
    exit 1
  fi
  exit 0
fi
case "$1" in
  api)
    shift
    inc=""
    if [[ "${1:-}" == "--include" ]]; then inc=1; shift; fi
    case "$1" in
      user) printf '{"login":"%s"}\n' "${MOCK_LOGIN:-noizu}" ;;
      repos/*)
        slug="${1#repos/}"
        if [[ "$slug" == *environments* ]]; then
          en="${slug##*/environments/}"
          if [[ "$en" == "${MOCK_MISSING_ENV:-__none__}" ]]; then
            echo "gh: Not Found (HTTP 404)" >&2; exit 1
          fi
          printf '{"environment_name":"%s","protection_rules":%s}\n' "$en" "${MOCK_ENV_PROT:-[]}"
        else
          if [[ "$slug" == "${MOCK_MISSING_REPO:-__none__}" ]]; then
            echo "gh: Not Found (HTTP 404)" >&2; exit 1
          fi
          [[ -n "$inc" ]] && printf 'HTTP/2.0 200 OK\ncontent-type: application/json\n\n'
          printf '{"full_name":"%s","private":true,"fork":false,"archived":false,"permissions":{"admin":true}}\n' \
            "${MOCK_FULLNAME_OVERRIDE:-$slug}"
        fi ;;
    esac ;;
  auth)
    cat >&2 <<'AUTH'
github.com
  ✓ Logged in to github.com account noizu (keyring)
  - Active account: true
  - Token: ghp_**** (classic) with 'gist', 'read:org', 'repo' scopes
AUTH
    ;;
  secret)
    shift
    if [[ "${1:-}" == "list" ]]; then
      shift
      repo=""; env=""
      while [[ $# -gt 0 ]; do :; done 2>/dev/null || true
      set -- "$@"
      repo=""; env=""
      # re-parse from the ORIGINAL argv via GH_ARGV_LOG tail is fragile; use MOCK knobs
      if [[ -n "${MOCK_LIST_WANT_ENV:-}" ]]; then printf '%s\n' "${MOCK_ENV_SECRET_JSON:-[]}"; exit 0; fi
      printf '%s\n' "${MOCK_REPO_SECRET_JSON:-[]}"
    fi ;;
esac
exit 0
MOCKEOF
chmod +x "$GH_BIN"

GH_USE_ENV_TOKEN=false
GH_MODE="apply"; GH_REPO_FILTER=""; GH_PLAN_SHA_ARG=""
ASSUME_YES=false; DRY_RUN=false
GITHUB_SYNC_LEDGER_DIR="$SCRATCH/ledgerdir"

# secret list needs repo/env distinction — rewrite that branch cleanly
python3 - "$GH_BIN" <<'PYEOF'
import sys, re
p = sys.argv[1]
src = open(p).read()
src = src.replace('''  secret)
    shift
    if [[ "${1:-}" == "list" ]]; then
      shift
      repo=""; env=""
      while [[ $# -gt 0 ]; do :; done 2>/dev/null || true
      set -- "$@"
      repo=""; env=""
      # re-parse from the ORIGINAL argv via GH_ARGV_LOG tail is fragile; use MOCK knobs
      if [[ -n "${MOCK_LIST_WANT_ENV:-}" ]]; then printf '%s\\n' "${MOCK_ENV_SECRET_JSON:-[]}"; exit 0; fi
      printf '%s\\n' "${MOCK_REPO_SECRET_JSON:-[]}"
    fi ;;''', '''  secret)
    shift
    if [[ "${1:-}" == "list" ]]; then
      shift
      env=""
      args=("$@")
      i=0
      while (( i < ${#args[@]} )); do
        if [[ "${args[$i]}" == "--env" ]]; then env="${args[$((i+1))]}"; fi
        i=$((i+1))
      done
      if [[ -n "$env" ]]; then printf '%s\\n' "${MOCK_ENV_SECRET_JSON:-[]}"
      else printf '%s\\n' "${MOCK_REPO_SECRET_JSON:-[]}"; fi
    fi ;;''')
open(p, 'w').write(src)
PYEOF

S1='VAL_ONE z9q$pecial"quote'
S2='VAL_TWO pem
multi
line'

reset_logs() { : > "$GH_ARGV_LOG"; : > "$GH_STDIN_LOG"; }

echo "== identity =="
MOCK_LOGIN=noizu; export MOCK_LOGIN
github_identity 2>/dev/null && pass "expected login accepted" || fail "expected login accepted"
MOCK_LOGIN=someone-else
github_identity 2>"$SCRATCH/id.err" && fail "unexpected login refused" || pass "unexpected login refused"
assert_file_has "identity refusal names the login" "someone-else" "$SCRATCH/id.err"
MOCK_LOGIN=noizu

echo "== plan phase never writes =="
reset_logs
GH_JOB_META=(); GH_JOB_VALUE=()
github_collect registry /registry OPS_PASSWORD '{"github":{"as":"REGISTRY_PASSWORD","repo":["noizu-labs/trl-infra"]}}' "$S1"
github_collect deploy /apps/foo X_TOKEN '{"github":{"as":"X_TOKEN","environment":[{"repo":"noizu-labs/trl-infra","env":"production"}]}}' "$S2"
MOCK_REPO_SECRET_JSON='[{"name":"REGISTRY_PASSWORD","updatedAt":"2026-09-09T00:00:00Z"}]' \
  github_plan_build 2>"$SCRATCH/plan.err" \
  && pass "plan build succeeds" || { fail "plan build succeeds"; cat "$SCRATCH/plan.err"; }
github_plan_print > "$SCRATCH/plan.out" 2>/dev/null
assert_file_lacks "plan made zero gh writes" "secret set" "$GH_ARGV_LOG"
assert_file_has "plan shows repo row as update" "noizu-labs/trl-infra | repo | - | /registry/OPS_PASSWORD | REGISTRY_PASSWORD | update" "$SCRATCH/plan.out"
assert_file_has "plan shows env row as create" "X_TOKEN | create" "$SCRATCH/plan.out"
assert_file_has "plan shows updatedAt honesty note" "updatedAt 2026-09-09" "$SCRATCH/plan.out"
assert_file_has "plan prints sha" "plan sha256" "$SCRATCH/plan.out"
assert_file_lacks "plan stdout carries no value" "VAL_ONE" "$SCRATCH/plan.out"
assert_file_lacks "plan stderr carries no value" "VAL_ONE" "$SCRATCH/plan.err"

echo "== apply gates =="
reset_logs
( github_confirm_apply ) 2>"$SCRATCH/g1.err" && fail "env gate blocks" || pass "env gate blocks"
export SECRET_UTILS_GITHUB_WRITES=1
( github_confirm_apply ) 2>"$SCRATCH/g2.err" && fail "non-tty requires --yes" || pass "non-tty requires --yes"
ASSUME_YES=true GH_PLAN_SHA_ARG=wrongsha github_confirm_apply 2>"$SCRATCH/g3.err" && fail "wrong sha refused" || pass "wrong sha refused"
GH_PLAN_SHA_ARG="$GH_PLAN_SHA" ASSUME_YES=true github_confirm_apply 2>/dev/null && pass "correct sha passes" || fail "correct sha passes"

echo "== apply writes via stdin only =="
reset_logs
ASSUME_YES=true github_apply > "$SCRATCH/apply.out" 2>"$SCRATCH/apply.err" \
  && pass "apply succeeds" || { fail "apply succeeds"; cat "$SCRATCH/apply.err"; }
assert_file_has "repo-scope argv exact" "secret set REGISTRY_PASSWORD -R noizu-labs/trl-infra" "$GH_ARGV_LOG"
assert_file_has "env-scope argv exact" "secret set X_TOKEN -R noizu-labs/trl-infra --env production" "$GH_ARGV_LOG"
assert_file_has "value arrives on stdin" "VAL_ONE" "$GH_STDIN_LOG"
assert_file_has "second value arrives on stdin" "VAL_TWO" "$GH_STDIN_LOG"
assert_file_lacks "value never in argv" "VAL_ONE" "$GH_ARGV_LOG"
assert_file_lacks "value never in apply stdout" "VAL_ONE" "$SCRATCH/apply.out"
assert_file_lacks "value never in apply stderr" "VAL_ONE" "$SCRATCH/apply.err"
assert_file_lacks "no --body flag" -- "--body" "$GH_ARGV_LOG"
assert_file_lacks "no -b flag" -- "-b " "$GH_ARGV_LOG"
assert_file_lacks "no --env-file flag" -- "--env-file" "$GH_ARGV_LOG"
assert_file_lacks "no --app flag" -- "--app" "$GH_ARGV_LOG"
assert_file_lacks "no --no-store flag" -- "--no-store" "$GH_ARGV_LOG"
LEDGER="$SCRATCH/ledgerdir/github-writes.log"
assert_file_has "ledger records write" "noizu-labs/trl-infra" "$LEDGER"
assert_file_lacks "ledger never carries values" "VAL_ONE" "$LEDGER"

echo "== xtrace never captures the value =="
GH_JOB_META=(); GH_JOB_VALUE=()
reset_logs
S3='VAL_THREE xtrace-canary'
github_collect third /apps/bar Y_TOKEN '{"github":{"as":"Y_TOKEN","repo":["noizu-labs/trl-infra"]}}' "$S3"
GH_PLAN_ROWS=(); GH_PLAN_SHA=""
github_plan_build 2>/dev/null
exec 3>"$SCRATCH/xtrace.log"
BASH_XTRACEFD=3
set -x
ASSUME_YES=true github_apply >/dev/null 2>&1
set +x
exec 3>&-
assert_file_has "xtrace control: third value written" "VAL_THREE" "$GH_STDIN_LOG"
assert_file_lacks "xtrace carries no value" "VAL_THREE" "$SCRATCH/xtrace.log"

echo "== scratch-wide value scan (stdin log is the ONLY home) =="
LEAKFILES=$(grep -rl -- 'VAL_ONE\|VAL_TWO\|VAL_THREE\|z9q\$pecial' "$SCRATCH" 2>/dev/null | grep -v 'gh-stdin.log$' || true)
if [[ -z "$LEAKFILES" ]]; then
  pass "no secret material outside the stdin log"
else
  fail "no secret material outside the stdin log (found in: $(echo "$LEAKFILES" | tr '\n' ' '))"
fi

echo "== failure path: scrub + rotation banner + fail-fast =="
# Plan rows sort by display (which includes the store path), so the secret that
# must SUCCEED lives under an earlier-sorting path than the one that fails.
GH_JOB_META=(); GH_JOB_VALUE=(); GH_PLAN_ROWS=()
reset_logs
github_collect registry /apps/a_first OPS_PASSWORD '{"github":{"as":"FIRST_TOKEN","repo":["noizu-labs/trl-infra"]}}' "$S1"
github_collect deploy /apps/z_later X_TOKEN '{"github":{"as":"X_TOKEN","repo":["noizu-labs/trl-infra"]}}' "$S2"
github_plan_build 2>/dev/null
MOCK_SET_FAIL_NAME=X_TOKEN; export MOCK_SET_FAIL_NAME
ASSUME_YES=true github_apply > "$SCRATCH/apply2.out" 2>"$SCRATCH/apply2.err" \
  && fail "failing write aborts apply" || pass "failing write aborts apply"
assert_file_has "stderr scrubbed to <redacted>" "<redacted>" "$SCRATCH/apply2.err"
assert_file_lacks "failed-write stderr carries no value" "VAL_TWO" "$SCRATCH/apply2.err"
assert_file_has "rotation banner printed" "ROTATION REQUIRED FOR" "$SCRATCH/apply2.err"
assert_file_has "banner names already-written target" "FIRST_TOKEN" "$SCRATCH/apply2.err"
assert_file_has "already-written target marked done" "wrote scope=repo target=noizu-labs/trl-infra env=- name='FIRST_TOKEN'" "$SCRATCH/apply2.out"
XTOK_COUNT=$(grep -c 'secret set X_TOKEN ' "$GH_ARGV_LOG" || true)
if [[ "${XTOK_COUNT:-0}" -le 1 ]]; then
  pass "fail-fast: failed target not retried"
else
  fail "fail-fast: failed target not retried (${XTOK_COUNT} attempts)"
fi
unset MOCK_SET_FAIL_NAME MOCK_FULLNAME_OVERRIDE MOCK_MISSING_ENV

echo "== empty and sentinel values refuse =="
GH_JOB_META=(); GH_JOB_VALUE=(); GH_PLAN_ROWS=()
github_collect empty /registry EMPTY_ONE '{"github":{"as":"EMPTY_ONE","repo":["noizu-labs/trl-infra"]}}' ""
github_plan_build 2>/dev/null && pass "empty plans as skip-empty" || fail "empty plans as skip-empty"
github_plan_print 2>/dev/null | grep -q "skip-empty" && pass "skip-empty visible in plan" || fail "skip-empty visible in plan"
ASSUME_YES=true github_apply > /dev/null 2>"$SCRATCH/empty.err" && fail "apply refuses empties" || pass "apply refuses empties"
assert_file_has "empty refusal explains why" "resolved EMPTY" "$SCRATCH/empty.err"

GH_JOB_META=(); GH_JOB_VALUE=(); GH_PLAN_ROWS=()
github_collect sent /registry SENT_ONE '{"github":{"as":"SENT_ONE","repo":["noizu-labs/trl-infra"]}}' '🔒 **redacted**'
github_plan_build 2>"$SCRATCH/sent.err" && fail "sentinel refuses to plan" || pass "sentinel refuses to plan"
assert_file_has "sentinel refusal message" "redaction sentinel" "$SCRATCH/sent.err"

echo "== dedupe / collision =="
GH_JOB_META=(); GH_JOB_VALUE=(); GH_PLAN_ROWS=()
github_collect secA /registry OPS_PASSWORD '{"github":{"as":"REGISTRY_PASSWORD","repo":["noizu-labs/trl-infra"]}}' "$S1"
github_collect secB /registry OPS_PASSWORD '{"github":{"as":"REGISTRY_PASSWORD","repo":["noizu-labs/trl-infra"]}}' "$S1"
github_plan_build 2>/dev/null && pass "same store key dedupes" || fail "same store key dedupes"
github_plan_print 2>/dev/null | grep -q 'x2-sources' && pass "xN sources displayed" || fail "xN sources displayed"

github_collect secC /registry2 OTHER '{"github":{"as":"REGISTRY_PASSWORD","repo":["noizu-labs/trl-infra"]}}' "$S1"
github_plan_build 2>"$SCRATCH/col.err" && fail "different store keys collide" || pass "different store keys collide"
assert_file_has "collision names both keys" "Name collision" "$SCRATCH/col.err"

echo "== repo redirect and missing-environment refusals =="
GH_JOB_META=(); GH_JOB_VALUE=(); GH_PLAN_ROWS=()
MOCK_FULLNAME_OVERRIDE=evil-org/renamed; export MOCK_FULLNAME_OVERRIDE
github_collect registry /registry OPS_PASSWORD '{"github":{"as":"R","repo":["noizu-labs/trl-infra"]}}' "$S1"
github_plan_build 2>"$SCRATCH/rd.err" && fail "redirect refused" || pass "redirect refused"
assert_file_has "redirect message shows both names" "evil-org/renamed" "$SCRATCH/rd.err"
unset MOCK_FULLNAME_OVERRIDE

GH_JOB_META=(); GH_JOB_VALUE=(); GH_PLAN_ROWS=()
MOCK_MISSING_ENV=production; export MOCK_MISSING_ENV
github_collect deploy /apps/foo X_TOKEN '{"github":{"as":"X","environment":[{"repo":"noizu-labs/trl-infra","env":"production"}]}}' "$S1"
github_plan_build 2>"$SCRATCH/me.err" && fail "missing environment refused" || pass "missing environment refused"
assert_file_has "missing-env prints exact PUT command" "api --method PUT /repos/noizu-labs/trl-infra/environments/production" "$SCRATCH/me.err"
assert_file_has "missing-env explains no auto-create" "REFUSING to auto-create" "$SCRATCH/me.err"
unset MOCK_MISSING_ENV

echo "== end-to-end: real script, plan-only run (--github-push) =="
E2E_CFG="$SCRATCH/e2e.yaml"
cat > "$E2E_CFG" <<EOF
apiVersion: secrets-tools/v1
sections:
  - id: registry
    title: Registry
    path: /registry
    secrets:
      OPS_PASSWORD:
        default: E2E_VALUE_one
        github:
          as: REGISTRY_PASSWORD
          repo: [noizu-labs/trl-infra]
EOF
reset_logs
rc=0
GH_BIN="$GH_BIN" env GH_ARGV_LOG="$GH_ARGV_LOG" GH_STDIN_LOG="$GH_STDIN_LOG" \
  env -u GH_TOKEN -u GITHUB_TOKEN \
  "$BIN" --github-push --config="$E2E_CFG" > "$SCRATCH/e2e.out" 2>"$SCRATCH/e2e.err" || rc=$?
if [[ "$rc" == "0" ]]; then pass "e2e plan run exits 0"; else fail "e2e plan run exits 0 (rc=$rc): $(head -3 "$SCRATCH/e2e.err")"; fi
assert_file_has "e2e prints plan table row" "REGISTRY_PASSWORD | create" "$SCRATCH/e2e.out"
assert_file_has "e2e says PLAN ONLY" "PLAN ONLY" "$SCRATCH/e2e.out"
assert_file_lacks "e2e plan wrote nothing" "secret set" "$GH_ARGV_LOG"
assert_file_lacks "e2e stdout carries no value" "E2E_VALUE_one" "$SCRATCH/e2e.out"
assert_file_lacks "e2e stderr carries no value" "E2E_VALUE_one" "$SCRATCH/e2e.err"

echo "== end-to-end: staging refusal =="
rc=0
GH_BIN="$GH_BIN" env GH_ARGV_LOG="$GH_ARGV_LOG" GH_STDIN_LOG="$GH_STDIN_LOG" \
  env -u GH_TOKEN -u GITHUB_TOKEN \
  "$BIN" --github-push --env=staging --config="$E2E_CFG" > /dev/null 2>"$SCRATCH/e2e-staging.err" || rc=$?
if [[ "$rc" == "1" ]]; then pass "staging + github refused"; else fail "staging + github refused (rc=$rc)"; fi
assert_file_has "staging refusal message" "ONE GitHub secret namespace" "$SCRATCH/e2e-staging.err"

echo ""
echo "Results: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
