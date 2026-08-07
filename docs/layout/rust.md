# Layout — rust/

Rust rewrite of the shell tooling: single `infisical` binary (CLI + ratatui
TUI). Built via `make compile`; installed by `make install` when `cargo` is
present. Parent map: [../PROJ-LAYOUT.md](../PROJ-LAYOUT.md).

```
rust/
├── Cargo.toml                  # Package manifest — bin "infisical"
├── Cargo.lock                  # Locked dependency versions
├── target/                     # Build output (gitignored)
└── src/
    ├── main.rs                 # Entry point
    ├── cli.rs                  # clap argument/subcommand definitions
    ├── dc.rs                   # direnv-config (.envrc.dc) parsing/integration
    ├── error.rs                # Error types
    ├── api/                    # Infisical HTTP API client
    │   ├── mod.rs              #   Client + auth (Universal Auth)
    │   └── types.rs            #   Request/response types
    ├── commands/               # One module per subcommand (+ helpers)
    │   ├── mod.rs
    │   ├── audit.rs            #   Audit Infisical vs definitions / dc
    │   ├── bootstrap.rs        #   Bootstrap tier-0 k8s Secrets
    │   ├── creds.rs            #   Credential resolution (shared helper)
    │   ├── fetch.rs            #   Fetch secret values
    │   ├── find_dc_line.rs     #   Locate secret source line in .envrc.dc
    │   ├── populate.rs         #   Seed definitions → Infisical
    │   ├── rebuild.rs          #   Rebuild local defs from Infisical
    │   ├── set_secret.rs       #   Set a single secret
    │   ├── verify.rs           #   Verify values vs expected sources
    │   └── view_dc.rs          #   View dc-sourced values (masked)
    ├── config/                 # Secret-definition config loading
    │   ├── mod.rs
    │   ├── v1.rs               #   Current schema
    │   └── legacy.rs           #   Legacy schema support
    ├── engine/                 # Secret resolution engine
    │   ├── mod.rs
    │   ├── resolve.rs          #   Source layering (dc/override/auto/default)
    │   └── generate.rs         #   Auto-generated password/value creation
    └── tui/                    # ratatui interactive views
        ├── mod.rs
        ├── theme.rs            #   Shared styling
        ├── fetch_view.rs       #   Fetch progress view
        ├── populate_view.rs    #   Populate progress view
        └── verify_view.rs      #   Verify results view
```

Public subcommands (`infisical --help`): `audit`, `bootstrap`, `fetch`,
`find-dc-line`, `populate`, `rebuild`, `set`, `verify`, `view-dc`.
