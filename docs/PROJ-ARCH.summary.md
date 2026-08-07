# secret-utils Architecture Summary

Secrets-management package for the Noizu k8s platform. Primary tool is the Rust
`infisical` binary (clap CLI + ratatui; tokio/reqwest Infisical client) with
subcommands audit, bootstrap, fetch, find-dc-line, populate, rebuild, set,
verify, view-dc. Eleven Bash CLIs under `bin/` (plus shared
`lib/secret-engine.sh`) are always installed as a cargo-free fallback;
`hydrate-envrc` remains shell-only for `.envrc.example` → `.envrc` generation.

Three sources stay aligned: direnv-config (`.envrc.dc` via `dc get/set
--reveal`), declarative `secrets-tools/v1` YAML (discovered as
`.infisical-secrets.yaml` et al.), and live Infisical. Value resolution order
is override → dc → env → ref → template → file → fallback_dc → auto → default.
Populate ensures folders then create/patch/skips secrets; verify compares dc vs
Infisical; bootstrap seeds Infisical’s own tier-0 k8s Secrets via kubectl.
Downstream: InfisicalSecret CRDs + operator → k8s Secrets → Helm.
