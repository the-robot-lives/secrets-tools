# Project Layout — k8/secret-utils

Terminal utility package for secrets management: environment-file generation
(`hydrate-envrc`) and Infisical secret seeding/auditing. Ships both legacy
shell tools (`bin/` + `lib/`) and a Rust CLI/TUI (`rust/`, installed as
`infisical`). Installed to `~/.local/bin` via `make install` (or the repo-root
`make install-utilities`).

```
secret-utils/
├── bin/                        # Legacy shell CLIs → [layout/bin.md](layout/bin.md)
│   ├── hydrate-envrc           #   Populate .envrc from Infisical
│   ├── infisical-populate-secrets  # Seed secrets.yaml defs → Infisical
│   ├── infisical-bootstrap     #   Bootstrap tier-0 k8s Secrets
│   └── ... (8 more)            #   audit / verify / fetch / set / view tools
├── lib/                        # Shared shell library
│   └── secret-engine.sh        #   Secret resolution/generation engine (sourced by bin/*)
├── rust/                       # Rust rewrite: `infisical` CLI + TUI → [layout/rust.md](layout/rust.md)
│   ├── Cargo.toml              #   Package manifest (bin name: infisical)
│   ├── Cargo.lock              #   Locked dependency versions
│   └── src/                    #   cli, commands/, engine/, api/, tui/, config/
├── docs/                       # Documentation
│   ├── PROJ-ARCH.md            #   Architecture overview
│   ├── PROJ-ARCH.summary.md    #   Architecture quick reference
│   ├── PROJ-LAYOUT.md          #   This file
│   ├── PROJ-LAYOUT.summary.md  #   Layout quick reference
│   ├── arch/                   #   Architecture detail docs
│   │   ├── data-flow.md        #     Secret data-flow diagrams
│   │   └── secret-topology.md  #     Secret source/destination topology
│   └── layout/                 #   Layout detail docs (bin.md, rust.md)
├── .gitignore                  # Ignores rust/target, .env, .envrc.local, editor droppings
├── Makefile                    # compile/test/install (Rust binary; legacy fallback w/o cargo)
├── README.md                   # Start here — install, config, usage
├── envrc.dc.example            # Example direnv-config (.envrc.dc) credential layout
└── secrets.yaml.example        # Example declarative secret definitions file
```

Note: `rust/target/` (build output) is gitignored and excluded above.

## Key Files Requiring Setup

| File | Action |
|------|--------|
| `envrc.dc.example` | Template for `.envrc.k8.dc` — Infisical Universal Auth creds (`K8_INFISICAL_CLIENT_ID`/`_SECRET`) |
| `secrets.yaml.example` | Template for declarative secret definitions (real file lives at repo root as `.infisical-secrets.yaml`) |
| `infra-config.yaml` | Not in this package — repo-level config providing `infisical.host` / `project_id` |
