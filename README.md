# secrets-tools — Secrets Management

Environment file generation and Infisical secret seeding.

## Installation

```bash
make install    # Installs hydrate-envrc, infisical-populate-secrets to ~/.local/bin
```

## Prerequisites

- `jq` for JSON parsing
- `curl` for Infisical API calls
- `openssl` for secret generation
- Infisical Universal Auth credentials (client ID + secret)

## Configuration

### Required (in config.env)

```bash
K8_INFISICAL_HOST="https://infisical.noizu.com/api"
K8_INFISICAL_CLIENT_ID="..."
K8_INFISICAL_CLIENT_SECRET="..."
```

Or set equivalent environment variables:

```bash
export OPERATOR_CLIENT_ID="..."
export OPERATOR_CLIENT_SECRET="..."
export INFISICAL_HOST="https://infisical.noizu.com/api"
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
