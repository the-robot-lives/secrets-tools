# k8/secret-utils Architecture Summary

Secrets-management utility package for the Noizu k8s platform. Primary tool is
a Rust `infisical` binary (clap CLI + ratatui TUI; tokio/reqwest API client)
with subcommands audit, bootstrap, fetch, find-dc-line, populate, rebuild,
set, verify, view-dc; 11 legacy Bash CLIs (sourcing `lib/secret-engine.sh`)
remain as a cargo-free fallback, plus `hydrate-envrc` for `.envrc.example` →
`.envrc` template hydration (generate:password/hex/django, inherit, REQUIRED).

Keeps three secret sources in sync — direnv-config `.envrc.dc`, declarative
`.infisical-secrets.yaml`, and the self-hosted Infisical server — using a
resolution layering of dc → env override → auto-generate → default. Secrets
are organized into 18 service-scoped Infisical folders (with cross-folder
fan-out of shared values); downstream, InfisicalSecret CRDs deployed by
Terraform sync them into k8s Secrets consumed by Helm charts. A tier-0
`bootstrap` command pre-creates Infisical's own k8s Secrets.

Installed to `~/.local/bin` via `make install` (or repo-root
`make install-utilities`); config from repo-level `infra-config.yaml`
(`infisical.host`/`project_id`) and credentials from the `.envrc.k8.dc`
direnv-config layer.
