# AGENT-README

> Orientation for AI coding agents working in this repo. Human docs: README.md.

## Type

cli-tool

## Purpose

The Noizu secrets-flow CLI fleet (`.envrc` → dc → Infisical → k8s): generate `.envrc` (`hydrate-envrc`), seed/verify/audit/set/fetch Infisical secrets, bootstrap tier-0 k8s Secrets, and export backups — without printing secret values.

## Stack

Bash tools in `bin/` over the shared `lib/secret-engine.sh` library (Infisical API client, `.infisical-secrets.yaml` + `.envrc.dc` parsers, verification engine); small Rust helper (`rust/`, built by `make install` → `~/.local/bin/infisical`); deps: jq, curl, openssl.

## Dev mode

```bash
make install    # builds the Rust binary, installs bin/ tools to ~/.local/bin (+ lib to ~/.local/lib)
make test
```

## Ports / URLs

- none (library/CLI)

## Tests

```bash
make test    # shell redaction/safety/github suites + targeted Rust tests
```

## Gotchas

- Never print secret values; `--show-secrets` (populate) and `--show-diff` (audit) are the only reveal paths — treat their output as SENSITIVE.
- Infisical Universal Auth creds: `K8_INFISICAL_CLIENT_ID` / `K8_INFISICAL_CLIENT_SECRET` via the `.envrc.k8.dc` secrets layer; host/project configured in `infra-config.yaml` → `infisical:`.
- `infisical-populate-secrets` refuses whole-file runs without `--all` (scope via `--section`/`--include`); failed reads, empty sources, redaction sentinels, and literal `<<` merge keys are never written.
- `infisical-bootstrap` requires `INFISICAL_POSTGRES_PASSWORD`, `INFISICAL_ENCRYPTION_KEY`, `INFISICAL_AUTH_SECRET`, `INFISICAL_REDIS_PASSWORD` (overridable via `K8_INFISICAL_BOOTSTRAP_*`).
- GitHub Actions secret-sync fan-out is gated: `SECRET_UTILS_GITHUB_WRITES=1` + typed plan-sha confirmation + expected-logins identity assertion; values via stdin only.
