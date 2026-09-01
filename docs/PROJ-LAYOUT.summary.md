# Project Layout Summary — k8/secret-utils

Secrets-management terminal utility: legacy shell tools + Rust `infisical` CLI/TUI.
Full annotated tree: [PROJ-LAYOUT.md](PROJ-LAYOUT.md).

```
secret-utils/
├── bin/                              # 11 legacy shell CLIs → ~/.local/bin
│   ├── hydrate-envrc
│   ├── infisical-populate-secrets
│   ├── infisical-bootstrap
│   ├── infisical-fetch-secrets
│   ├── infisical-verify
│   ├── infisical-set-secret
│   ├── infisical-audit
│   ├── infisical-rebuild
│   ├── infisical-view-dc
│   ├── infisical-find-dc-line
│   └── export-infisical-secrets
├── lib/
│   └── secret-engine.sh              # Shared shell engine → ~/.local/lib
├── rust/                             # infisical CLI + TUI
│   ├── Cargo.toml · Cargo.lock
│   └── src/                          # main, cli, dc, error, api/, commands/,
│                                     # config/, engine/, tui/
├── tests/
│   └── test_populate_redaction.sh
├── docs/
│   ├── PROJ-ARCH.md · PROJ-ARCH.summary.md
│   ├── PROJ-LAYOUT.md · PROJ-LAYOUT.summary.md
│   ├── PROJ-HOWTO.md · PROJ-HOWTO.summary.md
│   ├── PROJ-FAQ.md · PROJ-FAQ.summary.md
│   ├── PROJ-SCHEMA.md · PROJ-SCHEMA.summary.md
│   ├── arch/                         # data-flow.md, secret-topology.md
│   ├── howto/                        # populate-secrets.md, rebuild-from-infisical.md
│   └── layout/                       # bin.md, rust.md
├── CHANGELOG.md
├── merge-notes.md                  # Branch-sweep/merge journal
├── Makefile                          # compile / test / install
├── README.md
├── envrc.dc.example
└── secrets.yaml.example
```

Detail extracts: [layout/bin.md](layout/bin.md), [layout/rust.md](layout/rust.md).
