# Changelog — utilities/k8/secret-utils

## 2026-10-28

- docs: add AGENT-README.md (agent orientation)

## 2026-10-26

- docs: correct stale "main is CI/CD-only" deploy note — merging into main triggers CI/CD (user-verified 2026-10-26)
- docs: doc-sweep — PROJ-LAYOUT synced to current inventory (4 test suites, sync-github-secrets.md, schema/threat-model digests); PROJ-ARCH documents the GitHub Actions fan-out; new THREAT-MODEL (+summary) with T-001–T-014 register (T-009 bootstrap argv exposure open)

## [Unreleased]
GitHub Actions secret sync (repo + environment scopes, v1) plus safety fixes to existing flows.

### Added
- `infisical-populate-secrets` safety rails: whole-file runs refused without `--all`/`--section` (unknown flags now fail loudly instead of being ignored); `--include=` alias for `--section=`; remote GET is outcome-explicit (failed read aborts the key, never treated as absent); locally-empty sources never overwrite/create; redaction sentinels refused pre-write; `<<` merge keys exploded (feature-checked) and surviving literal `<<` entries dropped — a key named `<<` can no longer be created; per-key `created/updated/unchanged/skipped/error` recording with a name-only end-of-run summary and non-zero exit on any error; body-on-stdin kept, argv kept value-free.
- `tests/test_populate_safety.sh` (39 assertions: scope gate, read-outcome branches, empty-source/sentinel refusal, merge-key hygiene, dry-run write isolation, summary shape) wired into `make test`; README + `docs/howto/populate-secrets.md` document the new contract.
- `SecretSpec.github` block in `secrets.yaml`: fan a resolved secret out to GitHub Actions secrets (`as`, `repo` list, `environment` list, `trailing_newline`) — plan/apply workflow, three independent gates (`SECRET_UTILS_GITHUB_WRITES=1` env, typed/exact plan-sha confirmation, expected-logins identity assertion), tracked owner allowlist, canonical-repo checks (byte-identical `full_name`, private/non-fork/non-admin-refused), values via stdin only, append-only write ledger, fail-fast + `ROTATION REQUIRED FOR:` rotation banner. **Verification status: repo scope live-verifiable via `noizu-labs/trl-infra` (user's step — no live write was made during development); environment scope mock-only (trl-infra has zero environments); org/dependabot deferred to v2 (parsed, rejected with a pointer to the v2 requirements).** See `docs/howto/sync-github-secrets.md`.
- New flags: `--github-push` (plan-only), `--github-apply`, `--github-repo=owner/repo` (filter), `--github-plan-sha=<sha>` + `--yes` (non-TTY confirm), `--github-use-env-token` (opt into env token; default strips `GH_TOKEN`/`GITHUB_TOKEN`), `--targets=infisical|github` (github-only runs skip Infisical auth).
- `tests/test_github_schema.sh` (32 assertions) and `tests/test_github_writer.sh` (63 assertions incl. value-leakage scans: argv/stdout/stderr/xtrace/scratch), wired into `make test`.
- `docs/howto/sync-github-secrets.md` (workflow, refusals, safety invariants, verification honesty labels, v2 org/dependabot requirements, rotation runbook).
- Allowlist is tracked code: top-level `github_owners:` in the YAML is refused; `github:` via YAML anchor/alias is refused.

### Changed
- `docs/PROJ-SCHEMA.md` (+ summary): authoritative parser is now the **bash engine** (`bin/infisical-populate-secrets`); the Rust parser (`rust/src/config/v1.rs`) is documented as broken against the live schema (`dc: invalid type: string, expected struct DcRef`) — it cannot load the monorepo config today.
- `--env=staging` + github targets is hard-refused (one GitHub secret namespace); plan flag use is incompatible with the `zellij` section fan-out.
- Plan honesty: `gh secret list` exposes only name/`updatedAt`, so the plan distinguishes create vs update and never claims "unchanged"; duplicate identical targets collapse (`x2-sources` display), different store keys colliding on one GitHub slot hard-error.

### Fixed
- **Value leak into argv (urlencode)**: `render_template`'s urlencode passed the value as `python3 -c` argv; it now reads the value from stdin (`python3 -c … <<<"$val"` heredoc form with a single trailing-newline strip).
- **Value leak into argv (Infisical writes)**: `set_secret` built JSON payloads via `curl -d "{...}"`; all three request bodies now go via `curl -d @-` with the body on stdin.
- **Exit-0-on-failed-writes**: failed Infisical writes (and staging copies) now increment a failure counter and the script exits non-zero, including the Infisical path (both v1 and legacy engines).
- **`--show-secrets` dead code**: the flag parsed but did nothing; it now hard-errors (exit 2) so nobody relies on a no-op that suggests values could be shown.
- `GH_BIN` environment override was dead code (region init wiped it before the resolver read it).


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
