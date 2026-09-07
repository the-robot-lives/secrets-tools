# Project Layout — k8/secret-utils

Terminal utility package for secrets management: local env-file generation
(`hydrate-envrc`) and Infisical lifecycle ops (populate, fetch, verify, set,
audit, rebuild, bootstrap, export). Ships **legacy Bash** (`bin/` + `lib/`)
and a **Rust CLI/TUI** (`rust/` → binary `infisical`). Install:
`make install` or monorepo `make install-utilities`. Dual-path:
`Portfolio/Utilities/source/secret-utils` ↔ `utilities/k8/secret-utils`.

Plain tree: [PROJ-LAYOUT.summary.md](PROJ-LAYOUT.summary.md).
Arch: [PROJ-ARCH.md](PROJ-ARCH.md). How-to: [PROJ-HOWTO.md](PROJ-HOWTO.md).

```
secret-utils/
├── bin/                            # Legacy shell CLIs → [layout/bin.md](layout/bin.md)
│   ├── hydrate-envrc               #   .envrc.example → .envrc (generate:*)
│   ├── infisical-populate-secrets  #   Seed defs → Infisical
│   ├── infisical-bootstrap         #   Tier-0 k8s Secrets (pre-operator)
│   ├── infisical-fetch-secrets     #   Fetch values from Infisical API
│   ├── infisical-verify            #   Verify chain vs expected sources
│   ├── infisical-set-secret        #   Set one secret in Infisical
│   ├── infisical-audit             #   Audit Infisical vs defs / dc
│   ├── infisical-rebuild           #   Rebuild local defs from Infisical
│   ├── infisical-view-dc           #   View dc-sourced values (masked)
│   ├── infisical-find-dc-line      #   Locate secret source line in .envrc.dc
│   └── export-infisical-secrets    #   Export / dump secrets from Infisical
├── lib/
│   └── secret-engine.sh            # Shared shell engine (API, YAML, dc, verify)
├── rust/                           # Rust rewrite → [layout/rust.md](layout/rust.md)
│   ├── Cargo.toml                  #   Package; bin name: infisical
│   ├── Cargo.lock
│   └── src/                        #   main, cli, dc, error, api/, commands/,
│                                   #   config/, engine/, tui/ (ratatui views)
├── tests/
│   └── test_populate_redaction.sh  # Redaction safety (shell + cargo unit hooks)
├── docs/
│   ├── PROJ-ARCH.md(+.summary)     # Architecture + quick reference
│   ├── PROJ-LAYOUT.md(+.summary)   # This file + tree-only companion
│   ├── PROJ-HOWTO.md(+.summary)    # Task guides index + companion
│   ├── PROJ-FAQ.md(+.summary)      # FAQ + companion
│   ├── PROJ-SCHEMA.md(+.summary)   # Config/data artifacts (no DB) + companion
│   ├── arch/
│   │   ├── data-flow.md            #   Secret data-flow diagrams
│   │   └── secret-topology.md      #   Source/destination topology
│   ├── howto/
│   │   ├── populate-secrets.md     #   Populate walkthrough
│   │   └── rebuild-from-infisical.md
│   └── layout/
│       ├── bin.md                  #   Full bin/ inventory
│       └── rust.md                 #   Full rust/src/ inventory
├── CHANGELOG.md                    # Package changelog / milestones
├── merge-notes.md                  # Branch-sweep/merge journal (sep-1 sweep note)
├── .gitignore                      # rust/target, .env, .envrc.local, editor junk
├── Makefile                        # compile / test / install (+ legacy fallback)
├── README.md                       # Start here — prereqs, config, tool table
├── envrc.dc.example                # Template for Infisical UA creds (.envrc.k8.dc)
└── secrets.yaml.example            # Template for declarative secret definitions
```

`rust/target/` is gitignored and omitted above.

## Install mapping (`make install`)

| Source | Install path | Method |
|--------|--------------|--------|
| `rust/target/release/infisical` | `~/.local/bin/infisical` | copy when `cargo` present |
| `bin/*` (11 scripts) | `~/.local/bin/<basename>` | always via `install-legacy` |
| `lib/secret-engine.sh` | `~/.local/lib/secret-engine.sh` | always via `install-lib` |

Override: `INSTALL_DIR` / `LIB_DIR`. No `cargo` → Rust binary skipped; legacy still installs.

## Notes

- **Primary binary**: Rust `infisical` subcommands mirror most shell tools
  (`populate`, `verify`, `audit`, `fetch`, `set`, `view-dc`, `find-dc-line`,
  `rebuild`, `bootstrap`). Shell-only: `hydrate-envrc`, `export-infisical-secrets`.
- **External config** (not in package): monorepo `.infra-config.yaml`
  (`infisical.host` / `project_id`); root `.infisical-secrets.yaml`;
  `.envrc.k8.dc` credentials (`K8_INFISICAL_CLIENT_ID` / `_SECRET`).
- **Prereqs**: `jq`, `curl`, `openssl`; `cargo` for primary binary + rust tests.
- **Tests**: `make test` runs `tests/test_populate_redaction.sh` and selected
  `cargo test` filters when cargo is available.

## Key Files Requiring Setup

| File / artifact | Action |
|-----------------|--------|
| `envrc.dc.example` | Copy/merge → `.envrc.k8.dc` (UA client id/secret, optional host) |
| `secrets.yaml.example` | Shape for root `.infisical-secrets.yaml` (declarative defs) |
| `.infra-config.yaml` (repo) | `infisical.host`, `project_id` |
| Infisical UA credentials | Required for API ops |
| `~/.local/bin` on `PATH` | So `infisical` / legacy scripts resolve |
