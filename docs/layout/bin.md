# Layout — bin/

Legacy shell CLIs (pre-Rust). All source `lib/secret-engine.sh`; installed to
`~/.local/bin` only when `cargo` is unavailable (`make install-legacy`).

```
bin/
├── export-infisical-secrets     # Export secrets from Infisical (dump/backup)
├── hydrate-envrc                # Populate local .envrc from Infisical values
├── infisical-audit              # Audit Infisical contents vs declarative defs
├── infisical-bootstrap          # Bootstrap tier-0 k8s Secrets (pre-operator)
├── infisical-fetch-secrets      # Fetch secret values from Infisical API
├── infisical-find-dc-line       # Locate a secret's source line in .envrc.dc
├── infisical-populate-secrets   # Seed secrets.yaml definitions → Infisical
├── infisical-rebuild            # Rebuild/re-sync Infisical from definitions
├── infisical-set-secret         # Set a single secret value in Infisical
├── infisical-verify             # Verify Infisical values match expected sources
└── infisical-view-dc            # View direnv-config (dc) sourced values (masked)
```

The Rust `infisical` binary (see [rust.md](rust.md)) supersedes these as
subcommands (`infisical populate`, `infisical audit`, ...).
