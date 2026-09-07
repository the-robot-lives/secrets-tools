# secret-utils

**Repo:** https://github.com/the-robot-lives/secrets-tools

Environment file generation and Infisical secret seeding — the CLI fleet behind the Noizu secrets flow (`.envrc` → dc → Infisical → k8s).

## What

A set of bash tools (with a shared `lib/secret-engine.sh` library and a small Rust helper) installed to `~/.local/bin`:

- `hydrate-envrc` — generates `.envrc` from `.envrc.example`, processing generator directives: `generate:password|hex|django`, `inherit:VAR`, and `REQUIRED`. Output written with `chmod 600`.
- `infisical-populate-secrets` — seeds secrets from `.infisical-secrets.yaml` into Infisical for all (or one `--section`) service areas; auto-generates missing secrets, persisted to `secrets/.envrc.auto`. Precedence: explicit env var > `.envrc.auto` > auto-generate. `--dry-run` / `--show-secrets` supported.
- `infisical-bootstrap` — pre-creates the k8s Secrets Infisical needs before it can manage its own (tier-0 chicken-and-egg). Reads `infra-config.yaml` → `infisical_bootstrap`; flags `--dry-run`, `--tls-only`, `--namespace`. Requires `INFISICAL_POSTGRES_PASSWORD`, `INFISICAL_ENCRYPTION_KEY`, `INFISICAL_AUTH_SECRET`, `INFISICAL_REDIS_PASSWORD` (+ optional `TLS_CRT`/`TLS_KEY`); all values overridable via `K8_INFISICAL_BOOTSTRAP_*`.
- `infisical-verify` — verifies chain integrity across `.infisical-secrets.yaml`, `.envrc.dc` (`dc get`), and Infisical remote; `--section`/`--secret`/`--env`/`--fail-fast`/`--report-file`; exit 1 on mismatch.
- `infisical-set-secret <name>` — edits a secret across the chain (dc store, Infisical, declarative mapping); `--value`, `--generate`, `--dry-run`.
- `infisical-audit` — audit reports (markdown/JSON) with mismatch/missing remediation steps; `--show-diff` is SENSITIVE.
- `infisical-fetch-secrets <path>` — fetch secrets from an Infisical path (`--format=env|json|table`).
- `infisical-view-dc` / `infisical-find-dc-line` — inspect and locate `dc get` directives in `.envrc.dc` files.
- `export-infisical-secrets` — full backup of all Infisical secrets to `.tmp/infisical-backup-<env>-<timestamp>.json`.

## Why

The Noizu platform layers secrets declaratively (`.infisical-secrets.yaml` → Infisical → `InfisicalSecret` CRDs → k8s). Keeping every layer in sync by hand is error-prone and exposes values; these tools automate generation, seeding, verification, and repair without printing secrets by default.

## Getting Started

Prerequisites: `jq`, `curl`, `openssl`; Infisical Universal Auth credentials (client ID + secret) via `K8_INFISICAL_CLIENT_ID` / `K8_INFISICAL_CLIENT_SECRET` in the `.envrc.k8.dc` secrets layer (or env). Infisical host/project configured in `infra-config.yaml` → `infisical:`.

```bash
make install    # installs all bin/ tools to ~/.local/bin (make test to verify)
```

Examples:

```bash
hydrate-envrc
infisical-populate-secrets --dry-run
infisical-bootstrap --tls-only
infisical-verify --fail-fast
infisical-fetch-secrets /livebook --format=env
```

## How It Works

- `lib/secret-engine.sh` exposes reusable Infisical API client functions (`infisical_auth/get/set/list`), a `.infisical-secrets.yaml` parser (`secrets_get_by_name`, `secrets_list_names`), an `.envrc.dc` parser/editor (`envrc_find_file`, `envrc_parse_get_lines`, `envrc_edit_line`), and the verification engine (`verify_secret/section/all`) — sourceable from custom scripts.
- `rust/` holds a small Rust component built by `make install-rust`.

## Docs

`docs/` carries PROJ-ARCH / PROJ-HOWTO / PROJ-LAYOUT / PROJ-SCHEMA / PROJ-FAQ digests (plus arch/howto/layout detail dirs). Examples live in `envrc.dc.example` and `secrets.yaml.example`.
