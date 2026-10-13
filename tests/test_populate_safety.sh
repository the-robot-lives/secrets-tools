#!/usr/bin/env bash
# Safety tests for infisical-populate-secrets: scope gate, explicit read
# outcomes, empty-source / sentinel / failure handling, merge-key hygiene,
# dry-run isolation, and the per-key summary. Drives the SHIPPED bin under
# PATH-stubbed curl/dc — no network, no real Infisical, no real secrets.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/bin/infisical-populate-secrets"
SCRATCH="${TEST_SCRATCH:-$(mktemp -d)}"
PASS=0
FAIL=0

[[ -x "$BIN" ]] || { echo "FATAL: $BIN not found/executable"; exit 1; }

assert_rc() { # name expected_rc actual_rc
  if [[ "$2" == "$3" ]]; then
    echo "  PASS  $1 (rc=$3)"; PASS=$((PASS+1))
  else
    echo "  FAIL  $1 (expected rc=$2 got rc=$3)"; FAIL=$((FAIL+1))
  fi
}
assert_contains() { # name haystack_file needle
  if grep -qF -- "$3" "$2" 2>/dev/null; then
    echo "  PASS  $1"; PASS=$((PASS+1))
  else
    echo "  FAIL  $1 (missing: $3)"; FAIL=$((FAIL+1))
  fi
}
assert_not_contains() {
  if grep -qF -- "$3" "$2" 2>/dev/null; then
    echo "  FAIL  $1 (unexpected: $3)"; FAIL=$((FAIL+1))
  else
    echo "  PASS  $1"; PASS=$((PASS+1))
  fi
}
assert_count() { # name haystack_file needle expected
  local n
  n=$(grep -cF -- "$3" "$2" 2>/dev/null || true)
  if [[ "$n" == "$4" ]]; then
    echo "  PASS  $1 (count=$n)"; PASS=$((PASS+1))
  else
    echo "  FAIL  $1 (expected $4 of '$3', got $n)"; FAIL=$((FAIL+1))
  fi
}

MOCKBIN="$SCRATCH/mockbin"
mkdir -p "$MOCKBIN"

# --- mock curl: stateful fake Infisical --------------------------------------
# Remote state: $SCRATCH/remote.tsv rows "key<TAB>httpcode<TAB>value".
# Request log:   $SCRATCH/curl.tsv   rows "METHOD<TAB>url".
cat > "$MOCKBIN/curl" <<'EOF'
#!/usr/bin/env bash
STATE="${IPS_STATE:?IPS_STATE unset}"
LOG="${IPS_CURL_LOG:?IPS_CURL_LOG unset}"
method=""; url=""
prev=""
for a in "$@"; do
  [[ "$prev" == "-X" ]] && method="$a"
  case "$a" in http*) url="$a";; esac
  prev="$a"
done
[[ -z "$method" ]] && method="GET"
printf '%s\t%s\n' "$method" "$url" >> "$LOG"

case "$url" in
  *"universal-auth/login"*)
    printf '%s' '{"accessToken":"test-token"}'; exit 0 ;;
esac

case "$url" in
  *"/api/v3/secrets/raw/"*)
    key="${url##*/secrets/raw/}"; key="${key%%\?*}"
    case "$method" in
      GET)
        row=$(awk -F'\t' -v k="$key" '$1==k {print $2 "\t" $3; exit}' "$STATE" 2>/dev/null)
        if [[ -z "$row" ]]; then
          printf '\n404'; exit 0
        fi
        code="${row%%$'\t'*}"; val="${row#*$'\t'}"
        esc=$(printf '%s' "$val" | sed 's/"/\\"/g')
        printf '{"secret":{"secretValue":"%s"}}\n%s' "$esc" "$code"
        exit 0 ;;
      POST)
        printf '%s\t201\tPLACEHOLDER\n' "$key" >> "$STATE"
        printf '201'; exit 0 ;;
      PATCH)
        tmp="${STATE}.tmp"
        awk -F'\t' -v k="$key" 'BEGIN{OFS="\t"} $1==k {$2=200} {print}' "$STATE" > "$tmp" \
          && mv "$tmp" "$STATE"
        printf '200'; exit 0 ;;
    esac ;;
  *"/api/v2/folders"*)
    printf ''; exit 0 ;;
esac
printf '000'; exit 0
EOF
chmod +x "$MOCKBIN/curl"

# --- mock dc: never resolves (empty output) ----------------------------------
cat > "$MOCKBIN/dc" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "dc $*" >> "${IPS_DC_LOG:-/dev/null}"
exit 0
EOF
chmod +x "$MOCKBIN/dc"

NOK8="$SCRATCH/nok8-lib"; mkdir -p "$NOK8"
export PATH="$MOCKBIN:$PATH"
export K8_LIB_DIR="$NOK8"
export INFISICAL_HOST="http://127.0.0.1:1"
export INFISICAL_PROJECT_ID="pid-test"
export INFISICAL_ENV="prod"
export EKS_OPERATOR_CLIENT_ID="cid-test"
export EKS_OPERATOR_CLIENT_SECRET="cs-test"

run_case() { # name -- extra args... ; captures out/err/rc
  local name="$1"; shift
  STATE="$SCRATCH/remote.tsv"; : > "$STATE"
  CURLLOG="$SCRATCH/curl.tsv"; : > "$CURLLOG"
  OUT="$SCRATCH/out.txt"; ERR="$SCRATCH/err.txt"
  local rc=0
  IPS_STATE="$STATE" IPS_CURL_LOG="$CURLLOG" \
    bash "$BIN" "$@" >"$OUT" 2>"$ERR" || rc=$?
  RC=$rc
}

CONFIG_A="$SCRATCH/secrets-a.yaml"
cat > "$CONFIG_A" <<'YAML'
apiVersion: secrets-tools/v1
sections:
  - id: app
    title: App
    path: /app
    vars: {}
    secrets:
      FROM_ENV:    {env: TST_FROM_ENV}
      EMPTY_SRC:   {env: TST_MISSING_VAR}
      SENTINEL_KEY: {default: "🔒 **redacted**"}
      UNCHANGED:   {env: TST_UNCHANGED}
      CREATE_ME:   {env: TST_CREATE}
      CHANGE_ME:   {env: TST_CHANGE}
YAML

CONFIG_M="$SCRATCH/secrets-merge.yaml"
cat > "$CONFIG_M" <<'YAML'
apiVersion: secrets-tools/v1
_defaults: &base_secrets
  K_ONE: {env: TST_K1}
  K_TWO: {env: TST_K2}
sections:
  - id: merged
    title: Merged
    path: /merged
    secrets:
      <<: *base_secrets
      K_THREE: {env: TST_K3}
YAML

echo "== scope gate and flag handling =="
run_case gate-no-section --config "$CONFIG_A"
assert_rc "refusal rc" 2 "$RC"
assert_contains "refusal message" "$ERR" "Refusing an implicit whole-file run."
assert_contains "refusal names --all" "$ERR" "--all"

run_case gate-no-args --config "$CONFIG_A"
assert_rc "no-args rc" 2 "$RC"
assert_contains "no-args mentions --section" "$ERR" "--section"

run_case gate-all-passes --config "$CONFIG_A" --list
assert_rc "list rc" 0 "$RC"
assert_contains "list shows Sections" "$OUT" "Sections:"
assert_contains "list shows section id" "$OUT" "app"
assert_count "list makes no HTTP requests" "$CURLLOG" "" 0

run_case unknown-flag --config "$CONFIG_A" --bogus
assert_rc "unknown flag rc" 2 "$RC"
assert_contains "unknown flag message" "$ERR" "Unknown flag"

echo "== empty run: --all with no writes needed =="
run_case all-unchanged --config "$CONFIG_A" --all
STATE="$SCRATCH/remote.tsv"
printf 'FROM_ENV\t200\talpha-value-1\n' >> "$STATE"
printf 'EMPTY_SRC\t200\tremote-keeps\n' >> "$STATE"
printf 'SENTINEL_KEY\t200\tremote-keeps-2\n' >> "$STATE"
printf 'UNCHANGED\t200\tsame-value-here\n' >> "$STATE"
RC=0; TST_FROM_ENV="alpha-value-1" TST_UNCHANGED="same-value-here" \
  IPS_STATE="$STATE" IPS_CURL_LOG="$CURLLOG" \
  bash "$BIN" --config "$CONFIG_A" --all >"$OUT" 2>"$ERR" || RC=$?
assert_rc "unchanged run rc" 0 "$RC"
assert_contains "empty source skipped (remote has value)" "$OUT" "skipped: empty source (remote has a value"
assert_contains "sentinel refused" "$OUT" "REDACTION SENTINEL"
assert_count "no PATCH for unchanged" "$CURLLOG" "PATCH"$'\t'"$INFISICAL_HOST/api/v3/secrets/raw/UNCHANGED" 0
assert_count "no writes for empty source" "$CURLLOG" "POST"$'\t'"$INFISICAL_HOST/api/v3/secrets/raw/EMPTY_SRC" 0
assert_count "no PATCH for empty source" "$CURLLOG" "PATCH"$'\t'"$INFISICAL_HOST/api/v3/secrets/raw/EMPTY_SRC" 0
assert_count "no writes for sentinel key" "$CURLLOG" "POST"$'\t'"$INFISICAL_HOST/api/v3/secrets/raw/SENTINEL_KEY" 0
assert_contains "summary printed" "$OUT" "key names only"

echo "== mixed run: create / update / skip / error =="
STATE="$SCRATCH/remote.tsv"; : > "$STATE"
printf 'UNCHANGED\t200\tsame-value-here\n' >> "$STATE"
printf 'FROM_ENV\t500\t\n' >> "$STATE"
printf 'CHANGE_ME\t200\told-remote-value\n' >> "$STATE"
CURLLOG="$SCRATCH/curl.tsv"; : > "$CURLLOG"
RC=0; TST_FROM_ENV="alpha-value-2" TST_UNCHANGED="same-value-here" TST_CREATE="brand-new-value" TST_CHANGE="replacement-value" \
  IPS_STATE="$STATE" IPS_CURL_LOG="$CURLLOG" \
  bash "$BIN" --config "$CONFIG_A" --all >"$OUT" 2>"$ERR" || RC=$?
assert_rc "mixed run rc (one GET error)" 1 "$RC"
assert_contains "GET error recorded loudly" "$OUT" "remote GET failed (HTTP 500)"
assert_contains "error names key" "$OUT" "app/FROM_ENV"
assert_count "no POST despite 500 GET" "$CURLLOG" "POST	$INFISICAL_HOST/api/v3/secrets/raw/FROM_ENV" 0
assert_contains "empty+remote-404 skips create" "$OUT" "remote absent"
assert_count "no POST for EMPTY_SRC" "$CURLLOG" "POST	$INFISICAL_HOST/api/v3/secrets/raw/EMPTY_SRC" 0
assert_count "created via POST" "$CURLLOG" "POST"$'\t'"$INFISICAL_HOST/api/v3/secrets/raw/CREATE_ME" 1
assert_count "updated via PATCH" "$CURLLOG" "PATCH"$'\t'"$INFISICAL_HOST/api/v3/secrets/raw/CHANGE_ME" 1
assert_contains "summary counts errors" "$OUT" "error"
assert_contains "summary lists error key name" "$OUT" "FROM_ENV"
assert_not_contains "summary never prints values" "$OUT" "same-value-here"

echo "== merge-key yaml: no literal << ever written =="
STATE="$SCRATCH/remote.tsv"; : > "$STATE"
CURLLOG="$SCRATCH/curl.tsv"; : > "$CURLLOG"
RC=0; TST_K1="v-one" TST_K2="v-two" TST_K3="v-three" \
  IPS_STATE="$STATE" IPS_CURL_LOG="$CURLLOG" \
  bash "$BIN" --config "$CONFIG_M" --section merged >"$OUT" 2>"$ERR" || RC=$?
assert_rc "merge run rc" 0 "$RC"
for k in K_ONE K_TWO K_THREE; do
  assert_count "merge key $k written" "$CURLLOG" "POST"$'\t'"$INFISICAL_HOST/api/v3/secrets/raw/$k" 1
done
assert_count "no literal << key request" "$CURLLOG" "secrets/raw/%3C%3C" 0
assert_count "no literal << key request (raw)" "$CURLLOG" "secrets/raw/<<" 0

echo "== dry-run: observes, never writes =="
STATE="$SCRATCH/remote.tsv"; : > "$STATE"
printf 'UNCHANGED\t200\tsame-value-here\n' >> "$STATE"
CURLLOG="$SCRATCH/curl.tsv"; : > "$CURLLOG"
RC=0; TST_FROM_ENV="alpha-value-3" TST_UNCHANGED="same-value-here" TST_CREATE="dry-run-value" TST_CHANGE="dry-change" \
  IPS_STATE="$STATE" IPS_CURL_LOG="$CURLLOG" \
  bash "$BIN" --config "$CONFIG_A" --all --dry-run >"$OUT" 2>"$ERR" || RC=$?
assert_rc "dry-run rc" 0 "$RC"
n=$(grep -cE "^(POST|PATCH)\t.*secrets/raw/" "$CURLLOG" 2>/dev/null || true)
if [[ "$n" == "0" ]]; then echo "  PASS  dry-run makes no secret writes"; PASS=$((PASS+1)); else echo "  FAIL  dry-run makes no secret writes (got $n writes)"; FAIL=$((FAIL+1)); fi
assert_contains "dry-run plans a create" "$OUT" "created"

echo ""
echo "Results: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
