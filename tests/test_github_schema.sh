#!/usr/bin/env bash
# Schema-validation tests for the github: secret-sync block in
# infisical-populate-secrets. Drives the SHIPPED functions extracted from
# bin/infisical-populate-secrets — not a reimplementation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="${TEST_SCRATCH:-$(mktemp -d)}"
BIN="$ROOT/bin/infisical-populate-secrets"
PASS=0
FAIL=0

echo "== extract github-sync region + is_redaction_sentinel from shipped bin =="
# shellcheck disable=SC1090
eval "$(sed -n '/^# -- github-sync BEGIN --/,/^# -- github-sync END --/p' "$BIN")"
# shellcheck disable=SC1090
eval "$(sed -n '/^is_redaction_sentinel()/,/^}/p' "$BIN")"

FIX="$SCRATCH/fixture.yaml"
mkcfg() { # mkcfg <github-block-body-indented-8> [top-level-extra]
  cat > "$FIX" <<EOF
apiVersion: secrets-tools/v1
${2:-}
sections:
  - id: registry
    title: Registry
    path: /registry
    secrets:
      OPS_PASSWORD:
        default: dummy-not-a-real-value
        github:
$1
EOF
}

expect_fail() { # expect_fail <name> <stderr-pattern> <cmd...>
  local name="$1" pat="$2"; shift 2
  if "$@" >/dev/null 2>"$SCRATCH/last.err"; then
    echo "  FAIL  $name (expected failure, got success)"
    FAIL=$((FAIL + 1))
    return
  fi
  if grep -q "$pat" "$SCRATCH/last.err"; then
    echo "  PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name (failed, but stderr lacks pattern '$pat'): $(head -2 "$SCRATCH/last.err" | tr '\n' ' ')"
    FAIL=$((FAIL + 1))
  fi
}

expect_ok() { # expect_ok <name> <cmd...>
  local name="$1"; shift
  if "$@" >/dev/null 2>"$SCRATCH/last.err"; then
    echo "  PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name (expected success): $(head -2 "$SCRATCH/last.err" | tr '\n' ' ')"
    FAIL=$((FAIL + 1))
  fi
}

echo "== github_validate_config: happy paths =="
mkcfg "          as: REGISTRY_PASSWORD
          repo:
            - noizu-labs/trl-infra
            - noizu-labs-ml/elixirgenai.dev
          environment:
            - repo: noizu-labs/trl-infra
              env: production"
expect_ok "valid block (repo + environment) passes" github_validate_config "$FIX"

mkcfg "          as: PEM_KEY
          trailing_newline: preserve
          repo: [noizu-labs/trl-infra]"
expect_ok "trailing_newline preserve passes" github_validate_config "$FIX"

echo "== github_validate_config: 'as' rules =="
mkcfg "          repo: [noizu-labs/trl-infra]"
expect_fail "missing as is refused" "missing required key 'as'" github_validate_config "$FIX"

mkcfg "          as: 9bad-name
          repo: [noizu-labs/trl-infra]"
expect_fail "name starting with digit refused" "not a valid GitHub secret name" github_validate_config "$FIX"

mkcfg "          as: has-dash
          repo: [noizu-labs/trl-infra]"
expect_fail "name with dash refused" "not a valid GitHub secret name" github_validate_config "$FIX"

mkcfg "          as: GITHUB_TOKEN
          repo: [noizu-labs/trl-infra]"
expect_fail "GITHUB_* prefix refused" "not a valid GitHub secret name" github_validate_config "$FIX"

LONG_NAME="N$(printf 'A%.0s' $(seq 1 100))"
mkcfg "          as: $LONG_NAME
          repo: [noizu-labs/trl-infra]"
expect_fail "name over 100 chars refused" "not a valid GitHub secret name" github_validate_config "$FIX"

echo "== github_validate_config: v2-deferred scopes reject with reason =="
mkcfg "          as: REGISTRY_PASSWORD
          org:
            - org: noizu-labs
              visibility: selected"
expect_fail "org scope rejected as v2-deferred" "'org:' scope is deferred to v2" github_validate_config "$FIX"

mkcfg "          as: REGISTRY_PASSWORD
          dependabot: [noizu-labs/trl-infra]"
expect_fail "dependabot scope rejected as v2-deferred" "'dependabot:' scope is deferred to v2" github_validate_config "$FIX"

mkcfg "          as: REGISTRY_PASSWORD
          app: agents
          repo: [noizu-labs/trl-infra]"
expect_fail "app key rejected" "'app:' is not supported" github_validate_config "$FIX"

mkcfg "          as: REGISTRY_PASSWORD
          banana: true
          repo: [noizu-labs/trl-infra]"
expect_fail "random unknown key rejected with allowed list" "unknown key" github_validate_config "$FIX"

echo "== github_validate_config: target shape =="
mkcfg "          as: X
          repo: [not-a-slug]"
expect_fail "malformed repo slug refused" "repo entry 'not-a-slug' is malformed" github_validate_config "$FIX"

mkcfg "          as: X
          repo: [random-org/trl-infra]"
expect_fail "owner outside allowlist refused" "not in the tracked allowlist" github_validate_config "$FIX"

mkcfg "          as: X
          repo: [noizu-forks/trl-infra]"
expect_fail "noizu-forks hard-denied" "on the hard denylist" github_validate_config "$FIX"

mkcfg "          as: X
          repo: noizu-labs/trl-infra"
expect_fail "repo as scalar string refused" "repo must be a LIST" github_validate_config "$FIX"

mkcfg "          as: X
          repo: [noizu-labs/trl-infra, noizu-labs/trl-infra]"
expect_fail "duplicate repo entries refused" "duplicate entries" github_validate_config "$FIX"

mkcfg "          as: X
          environment:
            - repo: noizu-labs/trl-infra"
expect_fail "environment entry missing env refused" "requires BOTH 'repo'" github_validate_config "$FIX"

mkcfg "          as: X
          environment:
            - env: production"
expect_fail "environment entry missing repo refused" "requires BOTH 'repo'" github_validate_config "$FIX"

mkcfg "          as: X
          environment:
            - repo: noizu-labs/trl-infra
              env: production
              visibility: all"
expect_fail "environment unknown key refused" "environment entry has unknown key" github_validate_config "$FIX"

mkcfg "          as: X
          environment:
            - repo: noizu-labs/trl-infra
              env: pro duction"
expect_fail "malformed env name refused" "malformed" github_validate_config "$FIX"

mkcfg "          as: X"
expect_fail "zero targets refused" "no targets" github_validate_config "$FIX"

mkcfg "          as: X
          repo: [noizu-labs/trl-infra]
          trailing_newline: sometimes"
expect_fail "bad trailing_newline refused" "trailing_newline must be" github_validate_config "$FIX"

echo "== github_validate_config: supply-chain guards =="
mkcfg "          as: X
          repo: [noizu-labs/trl-infra]" "github_owners: [evil-org]"
expect_fail "top-level github_owners refused" "REFUSED" github_validate_config "$FIX"

cat > "$FIX" <<'EOF'
apiVersion: secrets-tools/v1
templates:
  reg: &ops_registry
    path: /registry
    secrets:
      OPS_PASSWORD:
        default: dummy
        github:
          as: REGISTRY_PASSWORD
          repo: [noizu-labs/trl-infra]
sections:
  - id: a
    <<: *ops_registry
EOF
expect_fail "github inside an anchor definition refused" "inside a YAML anchor definition" github_validate_config "$FIX"

cat > "$FIX" <<'EOF'
apiVersion: secrets-tools/v1
sections:
  - id: registry
    path: /registry
    secrets:
      OPS_PASSWORD:
        default: dummy
        gh_alias: &gha
          as: REGISTRY_PASSWORD
          repo: [noizu-labs/trl-infra]
      OTHER:
        default: dummy
        github: *gha
EOF
expect_fail "github as alias value refused" "anchor/alias" github_validate_config "$FIX"

cat > "$FIX" <<'EOF'
apiVersion: secrets-tools/v1
templates:
  anchor_with_github: &awg
    github:
      as: REGISTRY_PASSWORD
      repo: [noizu-labs/trl-infra]
sections:
  - id: registry
    path: /registry
    secrets:
      OPS_PASSWORD:
        default: dummy
        github: *awg
EOF
expect_fail "alias-valued github (resolvable) refused by scan" "anchor/alias" github_validate_config "$FIX"

echo "== CLI-level flag refusals (parse-time; no gh, no config needed) =="
cli_rc() { # cli_rc <expected-rc> <name> <args...>
  local want="$1" name="$2"; shift 2
  local rc=0
  "$BIN" "$@" >/dev/null 2>"$SCRATCH/cli.err" || rc=$?
  if [[ "$rc" == "$want" ]]; then
    echo "  PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name (rc=$rc want=$want): $(head -1 "$SCRATCH/cli.err")"
    FAIL=$((FAIL + 1))
  fi
}

cli_rc 2 "--show-secrets refused loudly" --show-secrets
cli_rc 2 "--github-repo malformed slug refused" --github-push --github-repo=not-a-slug
cli_rc 2 "--github-repo without push/apply refused" --github-repo=noizu-labs/x
cli_rc 2 "--targets bogus token refused" --targets=banana --github-push
cli_rc 2 "--targets github without push/apply refused" --targets=github

if grep -q 'SHOW_SECRETS' "$BIN"; then
  echo "  FAIL  SHOW_SECRETS variable fully removed"
  FAIL=$((FAIL + 1))
else
  echo "  PASS  SHOW_SECRETS variable fully removed"
  PASS=$((PASS + 1))
fi

echo ""
echo "Results: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
