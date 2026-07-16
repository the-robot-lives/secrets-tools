# k8/secret-utils — How To

Task-oriented guides for the things you'll actually do with this package.
For *what it is*, see [PROJ-ARCH.md](PROJ-ARCH.md); for *where things live*,
see [PROJ-LAYOUT.md](PROJ-LAYOUT.md).

All examples use the Rust `infisical` binary (installed by default when
`cargo` is present). Legacy Bash equivalents (`infisical-populate-secrets`,
`infisical-verify`, …) accept the same flags — swap `infisical <cmd>` for
`infisical-<cmd>` if you installed the fallback (`make install-legacy`).

## How to: install the tools

**Goal:** get `infisical` (and, if no Rust toolchain, the legacy scripts) onto your `PATH`.
**Prereqs:** `jq`, `curl`, `openssl`; Rust/`cargo` for the primary binary.

1. From this directory:
   ```bash
   make install
   ```
2. Confirm it picked the Rust path (falls back to `install-legacy` automatically if `cargo` is missing):
   ```bash
   which infisical
   ```

**Verify:** `infisical --help` lists all subcommands.
**Gotchas:**
- No `cargo` on `PATH` → you silently get only the legacy Bash scripts; `infisical` won't exist. Install Rust or use `infisical-<cmd>` names instead.
- Binary installs to `$INSTALL_DIR` (default `~/.local/bin`) — make sure that's on `PATH`.

## How to: configure credentials and the secrets config file

**Goal:** point the tool at your Infisical server and declarative secrets file.
**Prereqs:** Infisical Universal Auth client ID/secret; repo-root `.infra-config.yaml`.

1. Copy the example direnv-config layer and fill in credentials:
   ```bash
   cp envrc.dc.example .envrc.k8.dc   # or merge into your existing .envrc.k8.dc
   ```
   Set `K8_INFISICAL_CLIENT_ID` / `K8_INFISICAL_CLIENT_SECRET` (and optionally `K8_INFISICAL_HOST`).
2. Confirm `infra-config.yaml` at repo root has:
   ```yaml
   infisical:
     host: "https://infisical.noizu.com/api"
     project_id: "..."
   ```
3. The declarative secrets file is auto-discovered by walking up from your CWD, in this order: `.infisical-secrets.yaml`, `.infra-config.yaml`, `infisical-secrets.yaml`, `secrets.yaml`. Override with `-c/--config <path>` or `INFISICAL_SECRETS_FILE` if it's somewhere else.

**Verify:**
```bash
infisical view-dc --scope secrets   # confirms .envrc.dc is found and parses
```
**Gotchas:**
- Config discovery walks *up* from CWD — running from deep inside a project subtree still finds a repo-root config; running outside the repo tree entirely won't.
- Credentials live in `.envrc.k8.dc`, not `.infisical-secrets.yaml` — the YAML is definitions only, never values.

## How to: seed or update secrets in Infisical

**Goal:** push your declarative secret definitions into the live Infisical server.
**Prereqs:** credentials configured (above); `.infisical-secrets.yaml` populated.

1. Preview first:
   ```bash
   infisical populate --dry-run
   ```
2. Run for real:
   ```bash
   infisical populate --env prod
   ```

**Verify:** exit code 0 and a per-secret create/patch/skip summary; missing secrets are auto-generated (password/hex/django) and persisted so reruns are idempotent.
**Gotchas:**
- Large configs are slow one-at-a-time — see *"populate just one section, fast"* below for scoped/parallel runs.
- `--show-secrets` prints real values to your terminal — don't use it over a recorded/shared session.

→ *See [howto/populate-secrets.md](howto/populate-secrets.md) for section targeting, listing sections, and parallel fan-out.*

## How to: check whether secrets have drifted

**Goal:** confirm `.envrc.dc`, `.infisical-secrets.yaml`, and live Infisical all agree.
**Prereqs:** same as populate.

1. Full check:
   ```bash
   infisical verify --env prod
   ```
2. Narrow to one section or secret when you already suspect where the drift is:
   ```bash
   infisical verify --section data-postgres
   infisical verify --secret POSTGRES_PASSWORD
   ```

**Verify:** exit code `1` means a mismatch was found — non-zero is the signal, not just the printed table.
**Gotchas:**
- `--fail-fast` stops at the first mismatch — good for CI, bad for getting the full picture; drop it for an interactive audit.
- For a shareable report instead of a terminal read, use `infisical audit --export ./audit-report.md` (add `--show-diff` only when the audience is trusted with real values).

## How to: change a secret's value everywhere

**Goal:** rotate/update one secret and have it land in `dc`, Infisical, and stay consistent with its definition.
**Prereqs:** same as populate; know the secret's `name` as it appears in the config.

1. Preview:
   ```bash
   infisical set POSTGRES_PASSWORD --generate --dry-run
   ```
2. Apply:
   ```bash
   infisical set POSTGRES_PASSWORD --generate     # or: --value "explicit-value"
   ```
3. Find anything else that might reference the old value:
   ```bash
   infisical set POSTGRES_PASSWORD --cascade --dry-run
   ```

**Verify:** `infisical verify --secret POSTGRES_PASSWORD` shows all three sources matching.
**Gotchas:**
- `--cascade` only *flags* referencing secrets — it doesn't rewrite them. Follow up manually (or with another `set`) on anything it surfaces.
- Auto-generation types are limited to `password`, `hex`, `django` — anything else needs `--value`.

## How to: find where a secret is wired up

**Goal:** jump straight to the `.envrc.dc` line (or Infisical path) backing a secret name.
**Prereqs:** none beyond a checked-out `.envrc.dc`.

```bash
infisical find-dc-line secrets infisical.host          # file:line:content
infisical find-dc-line --inline secrets infisical.host # one-liner, editor-friendly
infisical view-dc --scope secrets --show-values        # broader listing, resolved values
```

**Verify:** output includes a real file path and line number.
**Gotchas:** if nothing prints, the scope/item_path pair doesn't exist yet in `.envrc.dc` — check spelling against `infisical view-dc` first.

## How to: bootstrap Infisical's own tier-0 secrets

**Goal:** create the k8s Secrets Infisical itself needs before it can manage anything (chicken-and-egg at tier 0).
**Prereqs:** `INFISICAL_POSTGRES_PASSWORD`, `INFISICAL_ENCRYPTION_KEY`, `INFISICAL_AUTH_SECRET`, `INFISICAL_REDIS_PASSWORD` env vars set; optionally `TLS_CRT`/`TLS_KEY`; cluster context pointed at the target k8s cluster.

1. Preview the `kubectl` commands it would run:
   ```bash
   infisical bootstrap --dry-run
   ```
2. Apply:
   ```bash
   infisical bootstrap
   ```

**Verify:** `kubectl get secret infisical-core-secrets -n infisical` exists.
**Gotchas:**
- This is a one-time, tier-0-only operation — running it against an already-initialized Infisical will not roll credentials; use `set`/`populate` for ongoing changes.
- `--tls-only` limits it to the TLS secret when cert material changed but core secrets haven't.

## How to: recover from a lost or out-of-sync `.envrc.dc`/config

**Goal:** regenerate `.envrc.dc` and `.infisical-secrets.yaml` from what's actually live in Infisical.
**Prereqs:** working Infisical credentials; nothing local needs to exist yet.

→ *See [howto/rebuild-from-infisical.md](howto/rebuild-from-infisical.md)*

## How to: generate a fresh `.envrc` from a template

**Goal:** turn `.envrc.example` (with `generate:`/`inherit:`/`REQUIRED` directives) into a real, populated `.envrc`.
**Prereqs:** an `.envrc.example` in the current directory.

```bash
hydrate-envrc
```

**Verify:** `.envrc` exists with mode `600`; any `REQUIRED` directive lines are flagged in the command's output for manual follow-up.
**Gotchas:** `inherit:VAR` references are resolved in a second pass — forward references (a var defined later in the file) work, but a reference to a var that's *never* defined silently leaves the field blank.

## Sharp edges

- **`infisical` vs `infisical-*`**: only one install path wins per machine — check `which infisical` if a command "isn't found" after `make install`; you may only have the legacy scripts.
- **`dc` must be on `PATH`**: the Rust binary shells out to the separate `dc` (direnv-config) CLI for `view-dc`/`find-dc-line`/`set`. If `dc` isn't installed, those commands fail with "is 'dc' on PATH?".
- **TUI vs scripting**: most commands render a `ratatui` progress view by default; pass `--no-tui` when piping output or running in CI/non-interactive shells.
