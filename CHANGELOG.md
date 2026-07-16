# Changelog — utilities/k8/secret-utils

## [Unreleased]
- (none currently)

## [m4-npl-docs-scaffolding] — 2026-07-16 — tag: `utilities-k8-secret-utils/m4-npl-docs-scaffolding`
NPL-style architecture and layout docs added/expanded under `docs/`, giving the utility its own PROJ-ARCH/PROJ-LAYOUT reference pair plus per-directory layout notes.

### Added
- `docs/PROJ-LAYOUT.md` + `docs/PROJ-LAYOUT.summary.md`, and `docs/layout/bin.md`, `docs/layout/rust.md` directory notes
### Changed
- `docs/PROJ-ARCH.md` and `docs/PROJ-ARCH.summary.md` expanded with more detail

## [m3-populate-secrets-rework] — 2026-07-09 — tag: `utilities-k8-secret-utils/m3-populate-secrets-rework`
`infisical-populate-secrets` reworked into a parallel, section-aware dispatcher: it can now fan sections out across `zellij` tabs (or fall back to sequential execution), re-invokes itself via a resolved absolute path so children stay pinned to the right binary, and carries assorted doc-pointer and correctness fixes.

### Added
- `--section` dispatch mode with `zellij`-based parallel fan-out (one tab per section) and a sequential fallback when `zellij` is unavailable
- Shell/KDL quoting helpers (`_shell_quote`, `_kdl_quote`) to safely build re-invocation command lines
### Changed
- Script now resolves its own absolute path (`SELF_PATH`) and re-invokes itself for per-section children instead of relying on `PATH` lookup
- Assorted doc-pointer and populate-secrets fixes

## [m2-hardening-and-docs] — 2026-06-14 — tag: `utilities-k8-secret-utils/m2-hardening-and-docs`
Post-import hardening pass across the bash wrapper scripts and the Rust config engine, plus a `dc bat --flat` mode and secret-management documentation.

### Added
- `dc bat --flat` mode for flat-listing secret config
- Secret-management documentation
### Changed
- `.gitignore`, `Makefile`, `README.md`, and `envrc.dc.example` refined
- `export-infisical-secrets`, `infisical-populate-secrets`, `infisical-rebuild`, `lib/secret-engine.sh` hardened (stricter arg handling)
- `rust/src/config/mod.rs`, `rust/src/error.rs` adjusted
### Fixed
- Legacy secret wrappers (`infisical-view-dc`) corrected

## [m1-initial-import] — 2026-06-13 — tag: `utilities-k8-secret-utils/m1-initial-import`
`secret-utils` lands in the monorepo as a squashed subtree import: the full bash CLI surface (`bin/`) plus a Rust-based config/secret engine (`rust/`), covering Infisical populate/fetch/audit/bootstrap/rebuild/verify/set flows and direnv-config (`dc`) tooling.

### Added
- Bash CLI: `export-infisical-secrets`, `hydrate-envrc`, `infisical-audit`, `infisical-bootstrap`, `infisical-fetch-secrets`, `infisical-find-dc-line`, `infisical-populate-secrets`, `infisical-rebuild`, `infisical-set-secret`, `infisical-verify`, `infisical-view-dc`
- `rust/` — direnv-config (`dc`) engine backing the secret-management workflow
- `README.md`, `Makefile`, `envrc.dc.example`, `secrets.yaml.example`
