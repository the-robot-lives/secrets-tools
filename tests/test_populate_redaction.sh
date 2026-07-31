#!/usr/bin/env bash
# Unit/integration tests for infisical-populate-secrets redaction safety.
# Drives the SHIPPED functions extracted from bin/infisical-populate-secrets
# (and lib/secret-engine.sh) — not a reimplementation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="${TEST_SCRATCH:-$(mktemp -d)}"
BIN="$ROOT/bin/infisical-populate-secrets"
LIB="$ROOT/lib/secret-engine.sh"
PASS=0
FAIL=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name (expected='$expected' actual='$actual')"
    FAIL=$((FAIL + 1))
  fi
}

assert_true() {
  local name="$1"
  shift
  if "$@"; then
    echo "  PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name"
    FAIL=$((FAIL + 1))
  fi
}

assert_false() {
  local name="$1"
  shift
  if "$@"; then
    echo "  FAIL  $name (expected false)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS  $name"
    PASS=$((PASS + 1))
  fi
}

echo "== extract is_redaction_sentinel from shipped bin =="
# shellcheck disable=SC1090
eval "$(sed -n '/^is_redaction_sentinel()/,/^}/p' "$BIN")"

assert_true "emoji redaction is sentinel" is_redaction_sentinel '🔒 **redacted**'
assert_true "plain **redacted** is sentinel" is_redaction_sentinel '**redacted**'
assert_false "real long secret is not sentinel" is_redaction_sentinel \
  'a-real-64-byte-secret-value-that-is-long-enough-abcdefghijklmnop'
assert_false "empty is not sentinel" is_redaction_sentinel ''

echo "== lib/secret-engine.sh is_redaction_sentinel =="
# secret-engine.sh has set -euo and dies on missing dc for auth helpers;
# only eval the redaction helpers.
eval "$(sed -n '/^is_redaction_sentinel()/,/^}/p' "$LIB")"
assert_true "lib: emoji redaction" is_redaction_sentinel '🔒 **redacted**'
assert_false "lib: real secret" is_redaction_sentinel 'not-a-redaction-token-at-all-really-long-value-ok'

echo "== resolve_dc_value uses --reveal --raw (mock dc) =="
MOCKBIN="$SCRATCH/mockbin"
mkdir -p "$MOCKBIN"
cat >"$MOCKBIN/dc" <<'EOF'
#!/usr/bin/env bash
# Record argv for assertion; emit redaction unless --reveal present.
printf '%s\n' "$*" >>"${DC_ARGS_LOG:-/dev/null}"
if [[ "$*" == *"--reveal"* ]]; then
  printf '%s' 'REVEALED_SECRET_VALUE_64_CHARS_abcdefghijklmnopqrstuvwxyz0123'
  exit 0
fi
printf '%s' '🔒 **redacted**'
exit 0
EOF
chmod +x "$MOCKBIN/dc"
export DC_ARGS_LOG="$SCRATCH/dc-args.log"
: >"$DC_ARGS_LOG"
export PATH="$MOCKBIN:$PATH"

# Extract resolve_dc_value from the SHIPPED bin (nested under v1 engine; unindent).
# Do not reimplement — this is the production function body.
eval "$(sed -n '/^is_redaction_sentinel()/,/^}/p' "$BIN")"
eval "$(sed -n '/^  resolve_dc_value() {/,/^  }/p' "$BIN" | sed 's/^  //')"

# Structural check: shipped bin must contain --reveal --raw on dc get line
if rg -q 'dc get "\$dc_config" "\$dc_path" --reveal --raw' "$BIN"; then
  echo "  PASS  shipped bin resolve_dc_value uses --reveal --raw"
  PASS=$((PASS + 1))
else
  echo "  FAIL  shipped bin missing --reveal --raw on dc get"
  FAIL=$((FAIL + 1))
fi

got=$(resolve_dc_value '{"dc":"services apps.therobotdrafts_secret_key_base"}')
assert_eq "resolve returns revealed value" \
  'REVEALED_SECRET_VALUE_64_CHARS_abcdefghijklmnopqrstuvwxyz0123' "$got"

if rg -q -- '--reveal' "$DC_ARGS_LOG" && rg -q -- '--raw' "$DC_ARGS_LOG"; then
  echo "  PASS  mock dc invoked with --reveal and --raw"
  PASS=$((PASS + 1))
else
  echo "  FAIL  mock dc args missing --reveal/--raw: $(cat "$DC_ARGS_LOG")"
  FAIL=$((FAIL + 1))
fi

# Without --reveal, mock returns sentinel; is_redaction_sentinel must catch it
no_reveal=$("$MOCKBIN/dc" get services apps.x)
assert_true "mock without reveal is sentinel" is_redaction_sentinel "$no_reveal"

echo "== set_secret refuses redaction sentinel (dry structural) =="
if rg -q 'is_redaction_sentinel "\$value"' "$BIN" && rg -q 'REDACTION SENTINEL' "$BIN"; then
  echo "  PASS  set_secret guards redaction sentinel"
  PASS=$((PASS + 1))
else
  echo "  FAIL  set_secret missing redaction sentinel guard"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
