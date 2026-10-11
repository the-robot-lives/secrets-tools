# How-To: Sync secrets to GitHub Actions

`infisical-populate-secrets --github-push` extends the declarative
`.infisical-secrets.yaml` flow: a secret that carries a `github:` block is
resolved once (dc/env/ref/template/file/fallback_dc/auto/default — unchanged)
and then fanned out to GitHub Actions secrets in addition to its normal
Infisical upload.

```
sections:
  - id: registry
    path: /registry
    secrets:
      REGISTRY_USER:
        dc: secrets registry.ghcr_user
        github:
          as: REGISTRY_USER
          repo: [noizu-labs/trl-infra]
      DEPLOY_KEY:
        file: .secrets/tls/deploy.pem
        github:
          as: DEPLOY_KEY
          trailing_newline: preserve
          environment:
            - repo: noizu-labs/trl-infra
              env: production
```

Schema reference: [../PROJ-SCHEMA.md](../PROJ-SCHEMA.md) § `SecretSpec.github`.

## Workflow — plan, then apply

The tool is **write-shy by construction**: `--github-push` alone is always
**plan-only** and performs zero writes. Applying requires a second, separately
gated invocation.

```bash
# 1. Plan (no writes, no gates beyond identity/config validation)
infisical-populate-secrets --github-push

# 2. Apply — all three gates must pass
export SECRET_UTILS_GITHUB_WRITES=1
infisical-populate-secrets --github-apply          # TTY: retype the plan sha when prompted
infisical-populate-secrets --github-apply --yes --github-plan-sha=<sha-from-plan>   # non-TTY
```

The plan sha covers the displayed rows (targets + names + ops + value sha8s),
so any drift between plan and apply — a config edit, a different value — is
rejected. `--github-repo=owner/repo` narrows both plan and apply to one repo
(for smoke-testing a rollout). `--dry-run` forces plan-only even with apply
flags. `--targets github` runs the GitHub leg without touching Infisical
(Infisical auth is skipped entirely); default is both.

## The three gates

1. **Environment**: `SECRET_UTILS_GITHUB_WRITES=1` must be set. No flag can
   substitute (there is deliberately no `--force`).
2. **Plan-first**: apply requires the plan sha — typed on a TTY, or supplied
   via `--yes --github-plan-sha=<sha>` off-TTY (exact match).
3. **Identity**: `gh api user` must resolve to a login in the tracked
   `GITHUB_SYNC_EXPECTED_LOGINS` list (`noizu`). This is the guard against
   ambient bot tokens (e.g. `GH_TOKEN` from a CI shell) quietly writing
   secrets as the wrong principal. By default the tool **strips**
   `GH_TOKEN`/`GITHUB_TOKEN` (and `GH_HOST`/`GH_REPO`) from the gh environment
   so the keyring identity is used; `--github-use-env-token` opts into the env
   token, which still must pass the expected-logins gate. `GH_BIN` overrides
   which `gh` binary runs (absolute path to a real executable — aliases like
   the local `agh` wrapper are refused).

## What the tool refuses (and why)

| Refusal | Rationale |
|---------|-----------|
| `org:` / `dependabot:` blocks | **Deferred to v2** — parsed, then rejected with a pointer here (see below) |
| Top-level `github_owners:` in YAML | The owner allowlist (`noizu-labs`, `noizu-labs-ml`, `the-robot-lives`; `noizu-forks` hard-denied) is **tracked code** — the YAML can select within it, never extend it |
| `github:` via YAML anchor/alias, or `github:` inside any anchor definition | An anchor could smuggle a target list past review; blocks must be literal and per-secret |
| `--env=staging --github…` | GitHub has **one namespace per repo** — a "staging" GitHub secret set can drift silently from prod; promote by rotating values, not by scoping names |
| Environment that does not exist | Prints the exact `gh api --method PUT /repos/{owner}/{repo}/environments/{env}` command; **never auto-creates** (creating an environment changes deployment-protection semantics). Also warns loudly when the environment exists with empty `protection_rules` |
| Repo failing the canonical check | `full_name` must match byte-for-byte (lowercased) — GitHub silently redirects renamed/transferred repos and a write would land somewhere else. Also requires `private: true`, `fork: false`, `archived: false`, `permissions.admin: true` |
| Values that resolved empty, or redaction sentinels | Refuses to write blanks or `🔒 **redacted**` masks over real secrets |

## Safety invariants

- **Values ride stdin, never argv.** The writer is `printf '%s' "$value" |
  gh secret set NAME -R owner/repo [--env ENV]`. `--body`, `-b`, `--env-file`
  are banned by construction (never emitted). gh encrypts client-side
  (libsodium sealed box) before the API call.
- **No value ever reaches a log.** stdout/stderr/ledger/plan show name,
  target, op and an 8-hex sha256 prefix of the value — enough to diff plans,
  not enough to reconstruct. Failed-write stderr is scrubbed (`<redacted>`)
  even when gh echoes the payload back in an error.
- **xtrace-safe**: the apply path does `set +x` before any write; tests assert
  the value never appears in a trace.
- **Fail-fast + rotation banner.** First failed write aborts the run
  (remaining targets untouched, no retry) and prints
  `ROTATION REQUIRED FOR:` with every target already written this run —
  GitHub secrets cannot be read back or unwritten, so a partial run means
  rotation at the source.
- **Append-only ledger** at `${XDG_STATE_HOME:-~/.local/state}/secret-utils/
  github-writes.log` (0600): UTC, identity, scope, repo, env, name, op, sha8.
- **Plan honesty.** `gh secret list` exposes only name/`updatedAt` — the plan
  distinguishes `create` vs `update` (and shows `updatedAt` for existing
  names) and **never** claims a value is "unchanged". Duplicated identical
  targets collapse into one row (`x2-sources`); two *different* store keys
  mapping to one GitHub slot hard-error.

## Verification status (honesty labels)

- **Repo scope — LIVE-VERIFIABLE (user's step, not the tool's)**:
  `noizu-labs/trl-infra` already carries `REGISTRY_USER`/`REGISTRY_PASSWORD`
  GitHub secrets; the first live run should target exactly that repo (values
  intentionally identical, so a confirmed run changes nothing observable).
- **Environment scope — MOCK-ONLY so far**: `trl-infra` has **zero**
  environments today; no environment write has been exercised against GitHub.
  Covered by `tests/test_github_writer.sh` against a mock gh only.
- **Org / Dependabot — NOT IMPLEMENTED (v2)**.
- No live GitHub write was performed during development; all behavior is
  covered by `tests/test_github_schema.sh` (32 assertions) and
  `tests/test_github_writer.sh` (63 assertions, mock gh + leakage scans).

## v2: org + Dependabot requirements (when implemented)

Deferred **not** because it is hard, but because the blast radius (every repo
in an org) needs its own review. The seam is in place (the validator rejects
`org:`/`dependabot:` with a stable message; `github_apply` carries a marked
extension point). When v2 lands it must:

1. **Preflight `admin:org`** on the token (org secrets need it; repo `admin`
  does not imply it) and refuse before planning otherwise.
2. **Create with `--no-repos-selected`**, then `PUT` the explicit repo
   allowlist as a separate step — never create with `visibility: all`
   (hard-refuse that value in the schema).
3. **Delete-on-allowlist-failure**: if the allowlist PUT fails, immediately
   delete the just-created org secret rather than leave an all-repos-exposed
   (or partially exposed) one.
4. **Allowlist drift handling**: on later runs, diff the secret's selected
   repos against the config and reconcile (the plan must surface
   additions/removals as rows).
5. **`-r` takes bare repo names** in org scope (`-r trl-infra`), not
   `owner/repo` — the org is the block's context.

## Rotation runbook (after an unintended or partial write)

1. Read the ledger: `~/.local/state/secret-utils/github-writes.log` — every
   line names the identity, target, and value sha8 that was written.
2. Rotate at the **source** (Infisical/dc): generate a new value, let the
   normal populate flow upload it.
3. Re-run `--github-push` → `--github-apply` to fan the rotated value out.
   Overwriting a GitHub secret with the rotated value is safe; GitHub keeps
   no readable copy of the old one (only workflow runs that already fetched
   it retain it — audit those runs if the exposure matters).
