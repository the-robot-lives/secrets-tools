# Layout — bin/

Legacy shell CLIs (pre-Rust). All source `lib/secret-engine.sh` (installed to
`~/.local/lib`). `make install` always runs `install-legacy` (even when the
Rust `infisical` binary is installed). Parent map:
[../PROJ-LAYOUT.md](../PROJ-LAYOUT.md).

```
bin/
├── export-infisical-secrets     # Export secrets from Infisical (dump/backup)
├── hydrate-envrc                # .envrc.example → .envrc (generate:* directives)
├── infisical-audit              # Audit Infisical contents vs declarative defs / dc
├── infisical-bootstrap          # Bootstrap tier-0 k8s Secrets (pre-operator)
├── infisical-fetch-secrets      # Fetch secret values from Infisical API
├── infisical-find-dc-line       # Locate a secret's source line in .envrc.dc
├── infisical-populate-secrets   # Seed secrets.yaml definitions → Infisical
├── infisical-rebuild            # Rebuild/re-sync local defs from Infisical
├── infisical-set-secret         # Set a single secret value in Infisical
├── infisical-verify             # Verify Infisical values match expected sources
└── infisical-view-dc            # View direnv-config (dc) sourced values (masked)
```

Rust `infisical` subcommands cover most of these (`populate`, `audit`, …).
Shell-only: `hydrate-envrc`, `export-infisical-secrets`.
