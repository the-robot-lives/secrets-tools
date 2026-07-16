# Project Layout Summary — k8/secret-utils

Secrets-management terminal utility: legacy shell tools + Rust `infisical` CLI/TUI.

```
secret-utils/
├── bin/                        # Legacy shell CLIs (11 tools; see layout/bin.md)
├── lib/
│   └── secret-engine.sh        # Shared shell secret engine
├── rust/                       # Rust `infisical` CLI + TUI (see layout/rust.md)
│   ├── Cargo.toml
│   ├── Cargo.lock
│   └── src/                    # main, cli, dc, error, api/, commands/, config/, engine/, tui/
├── docs/
│   ├── PROJ-ARCH.md / PROJ-ARCH.summary.md
│   ├── PROJ-LAYOUT.md / PROJ-LAYOUT.summary.md
│   ├── arch/                   # data-flow.md, secret-topology.md
│   └── layout/                 # bin.md, rust.md
├── .gitignore
├── Makefile                    # compile / test / install (legacy fallback)
├── README.md
├── envrc.dc.example            # Credential template (.envrc.k8.dc)
└── secrets.yaml.example        # Declarative secret-definitions template
```
