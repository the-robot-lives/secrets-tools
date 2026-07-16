# k8/secret-utils — How To (Summary)

Quick index of available guides. Full steps in [PROJ-HOWTO.md](PROJ-HOWTO.md).

- **Install the tools** — get `infisical` (or the legacy scripts fallback) onto `PATH`.
- **Configure credentials and the secrets config file** — wire up `.envrc.k8.dc` creds and confirm `.infisical-secrets.yaml` discovery.
- **Seed or update secrets in Infisical** — push declarative definitions into the live server (`infisical populate`).
- **Populate just one section, fast** *(→ [howto/populate-secrets.md](howto/populate-secrets.md))* — section targeting, `--list`, and the legacy script's `zellij`-based parallel fan-out across sections/groups.
- **Check whether secrets have drifted** — compare `.envrc.dc`, YAML, and live Infisical (`infisical verify`/`audit`).
- **Change a secret's value everywhere** — rotate/set a secret across dc + Infisical, with `--cascade` reference-flagging.
- **Find where a secret is wired up** — jump to the `.envrc.dc` line or view resolved directives.
- **Bootstrap Infisical's own tier-0 secrets** — pre-create the k8s Secrets Infisical needs before it can manage itself.
- **Recover from a lost or out-of-sync `.envrc.dc`/config** *(→ [howto/rebuild-from-infisical.md](howto/rebuild-from-infisical.md))* — regenerate local files from live Infisical state via `infisical rebuild`'s scan/analyze/generate phases.
- **Generate a fresh `.envrc` from a template** — `hydrate-envrc` template processing (`generate:`/`inherit:`/`REQUIRED` directives).
- **Sharp edges** — `infisical` vs `infisical-*` install-path confusion, `dc` must be on `PATH`, TUI vs `--no-tui` for scripting/CI.
