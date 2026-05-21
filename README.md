# secrets-tools — Secrets Management

Environment file generation and Infisical secret seeding.

## Installation

```bash
make install    # Installs hydrate-envrc, infisical-populate-secrets, infisical-bootstrap to ~/.local/bin
```

## Prerequisites

- `jq` for JSON parsing
- `curl` for Infisical API calls
- `openssl` for secret generation
- Infisical Universal Auth credentials (client ID + secret)

## Configuration

All configuration lives in `k8-util-config.yaml` with credentials in `.k8-secrets.yaml` (see [k8-lib README](../k8-lib/README.md) for setup).

### Relevant Sections

In `k8-util-config.yaml`:

```yaml
infisical:
  host: "https://infisical.noizu.com/api"
  project_id: "..."
```

In `.k8-secrets.yaml` (gitignored):

```yaml
infisical:
  client_id: "..."
  client_secret: "..."
```

Or set equivalent environment variables:

```bash
export K8_INFISICAL_HOST="https://infisical.noizu.com/api"
export K8_INFISICAL_CLIENT_ID="..."
export K8_INFISICAL_CLIENT_SECRET="..."
```

## Tools

### hydrate-envrc

Generates `.envrc` from `.envrc.example` by processing generator directives:

```bash
hydrate-envrc                   # Generate .envrc from .envrc.example in CWD
```

Supported directives (in `.envrc.example` comments):

| Directive | Example | Action |
|-----------|---------|--------|
| `generate:password` | `export DB_PASS="" # generate:password` | Random 32-char password |
| `generate:hex` | `export SECRET="" # generate:hex` | Random 64-char hex string |
| `generate:django` | `export KEY="" # generate:django` | Django-style secret key |
| `inherit:VAR` | `export COPY="" # inherit:DB_PASS` | Copy value from another variable |
| `REQUIRED` | `export API_KEY="" # REQUIRED` | Left blank, flagged in output |

Output is written to `.envrc` with `chmod 600`.

### infisical-populate-secrets

Seeds secrets into Infisical for all service areas:

```bash
infisical-populate-secrets                  # Populate all sections
infisical-populate-secrets --section webui  # Single section only
infisical-populate-secrets --dry-run        # Preview without writing
infisical-populate-secrets --show-secrets   # Display values in output
```

Auto-generates missing secrets and persists them to `secrets/.envrc.auto` for reuse across runs. Precedence: explicit env var > `.envrc.auto` > auto-generate.

### infisical-bootstrap

Pre-creates the K8s Secrets that Infisical needs before it can manage its own secrets (tier 0 chicken-and-egg). Reads connection details from `k8-util-config.yaml` → `infisical_bootstrap` section.

```bash
infisical-bootstrap                             # Create app + TLS secrets
infisical-bootstrap --dry-run                   # Preview without creating
infisical-bootstrap --tls-only                  # Only create TLS secret
infisical-bootstrap --namespace my-ns           # Override namespace
```

#### Configuration

In `k8-util-config.yaml`:

```yaml
infisical_bootstrap:
  namespace: infisical
  secret_name: infisical-core-secrets
  tls_secret_name: cloudflare-infisical.example.com-tls
  site_url: https://infisical.example.com
  pg_user: infisical
  pg_db: infisicalDB
  db_host: postgresql
  redis_host: redis
```

All values overridable via `K8_INFISICAL_BOOTSTRAP_*` env vars (e.g., `K8_INFISICAL_BOOTSTRAP_SITE_URL`).

#### Required Environment Variables

| Variable | Purpose |
|----------|---------|
| `INFISICAL_POSTGRES_PASSWORD` | PostgreSQL password |
| `INFISICAL_ENCRYPTION_KEY` | Encryption key (hex) |
| `INFISICAL_AUTH_SECRET` | Auth secret |
| `INFISICAL_REDIS_PASSWORD` | Redis password |
| `TLS_CRT` / `TLS_KEY` | Base64-encoded TLS certificate and key (optional) |
