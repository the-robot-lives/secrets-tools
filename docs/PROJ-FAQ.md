# k8/secret-utils — FAQ

Why/when/compared-to-what questions. For step-by-step procedures see
[PROJ-HOWTO.md](PROJ-HOWTO.md); for design rationale see
[PROJ-ARCH.md](PROJ-ARCH.md).

## Motivation

### Why would I use this instead of just setting env vars or plain `.env` files?

Because a plain `.env`/env-var approach has no source of truth beyond
whatever is currently on disk or in your shell — nothing declares what
*should* exist, nothing checks the live Infisical server still agrees, and
nothing regenerates a lost file. `secret-utils` keeps three sources
(`.envrc.dc`, the declarative `.infisical-secrets.yaml`, and Infisical
itself) explicitly reconciled, with `verify`/`audit` telling you when they
drift and `rebuild` recovering local state from the server if a laptop dies.
The honest trade-off: for a single throwaway script with one or two secrets,
this is more ceremony than a `.env` file, not less.

→ *See [PROJ-HOWTO.md#how-to-check-whether-secrets-have-drifted](PROJ-HOWTO.md#how-to-check-whether-secrets-have-drifted).*

### Why does credential resolution have four layers (dc → env override → auto-generate → default) instead of one?

Because the same config needs to work in three different situations without
being edited: a developer's local machine (`dc` files), CI or an operator's
shell (`override:` env vars for a one-off), first-time bootstrap of a secret
nobody has set yet (`auto:` generation), and a safe non-secret fallback
(`default:`). Collapsing this to one layer would mean either committing real
values somewhere or hand-generating every new secret before first use.

### Why keep 11 legacy Bash scripts around when the Rust `infisical` binary does everything?

Because `cargo`/Rust isn't guaranteed to be on every machine that needs to
run these tools (bootstrap boxes, minimal CI images, a teammate's fresh
laptop), and the tier-0 bootstrap problem means secret-utils sometimes has
to work *before* a full dev environment exists. The Bash scripts are the
cargo-free fallback for exactly that case — `make install` picks Rust
automatically when available and only falls back to `install-legacy`
otherwise. The cost is real: two implementations to keep behaviorally
aligned, and the Bash path is not where new features land first.

→ *See [PROJ-HOWTO.md#how-to-install-the-tools](PROJ-HOWTO.md#how-to-install-the-tools).*

## Fit

### When is this the wrong tool for a secret?

When the value isn't meant to live in Infisical at all — e.g. a per-developer
local override you deliberately don't want synced, or a secret scoped to a
single ephemeral environment that will be torn down before drift ever
matters. Also skip it for anything outside the k8s/Infisical chain this
package targets (a third-party SaaS's own secret store, for instance) —
`secret-utils` has no concept of those.

### When should I reach for `infisical bootstrap` versus `populate`?

Only reach for `bootstrap` once, at tier 0, before Infisical itself is
running — it pre-creates the raw k8s Secrets (Postgres password, encryption
key, auth secret, Redis password, optional TLS) that Infisical's own Helm
chart needs to start. Every secret after that — the ones Infisical itself
will manage — goes through `populate`. Running `bootstrap` again against an
already-initialized Infisical does *not* roll its credentials; it's not a
rotation tool.

→ *See [PROJ-HOWTO.md#how-to-bootstrap-infisicals-own-tier-0-secrets](PROJ-HOWTO.md#how-to-bootstrap-infisicals-own-tier-0-secrets).*

## Comparison

### How does `infisical set` differ from editing the value directly in the Infisical UI/API?

`set` additionally updates the local `dc` store and re-checks the
`.infisical-secrets.yaml` definition, so all three sources stay consistent
in one command. Editing Infisical directly is faster for a single quick fix
but leaves `.envrc.dc` stale until you separately run `verify`/`rebuild` to
notice and fix the gap — `set` exists specifically to avoid that follow-up
step.

### How does `--cascade` on `set` differ from actually rotating downstream secrets?

`--cascade` only *flags* other secret definitions that reference the one
you changed — it does not rewrite or re-derive their values. If a
downstream secret was itself generated from the old value (rare, but
possible with composite auto-generated secrets), you still have to run
`set` on it separately. Treat `--cascade` as a "here's what else to check,"
not an automated rotation cascade.

→ *See [PROJ-HOWTO.md#how-to-change-a-secrets-value-everywhere](PROJ-HOWTO.md#how-to-change-a-secrets-value-everywhere).*

## Capability

### Can `infisical populate` run in parallel across many sections at once?

Yes, via `--section` dispatch: it fans out one `zellij` tab per section and
falls back to sequential execution automatically when `zellij` isn't
installed. This matters once your `.infisical-secrets.yaml` has grown past
a handful of sections, since one-at-a-time population is the slow path the
CHANGELOG's `m3-populate-secrets-rework` milestone specifically addressed.

→ *See [howto/populate-secrets.md](howto/populate-secrets.md).*

### Can I recover if I lose `.envrc.dc` entirely and never had a backup?

Yes — `infisical rebuild` regenerates both `.envrc.dc` and
`.infisical-secrets.yaml` from whatever is actually live on the Infisical
server. It needs nothing local to already exist, only working Infisical
credentials. What it *can't* recover is anything that was only ever
`default:`-layered or never pushed to Infisical in the first place — those
were never stored server-side to rebuild from.

→ *See [howto/rebuild-from-infisical.md](howto/rebuild-from-infisical.md).*

## Caveats

### Is it safe to run `--show-secrets` or `--show-diff` in a recorded terminal session or CI log?

No. Both flags print real secret values to stdout by design — they exist
for interactive human debugging, not for automation output. A CI log,
screen-share recording, or shared terminal multiplexer session with either
flag on will leak the actual credential text. Use plain `populate`/`audit`
(no value flags) for anything that gets logged or recorded, and reserve
`--show-secrets`/`--show-diff` for an ad hoc interactive shell only.

### If `infisical verify` prints a clean-looking table, is that enough to confirm everything's in sync?

No — check the exit code, not just the printed table. A non-zero exit
(`1`) is the authoritative mismatch signal; `--fail-fast` in particular
stops at the *first* mismatch, so a clean-looking partial table under
`--fail-fast` can mean "stopped early," not "everything else checked out."
Drop `--fail-fast` for a full interactive audit and rely on `audit` (with
`--export`) when you need a complete, shareable picture.

→ *See [PROJ-HOWTO.md#how-to-check-whether-secrets-have-drifted](PROJ-HOWTO.md#how-to-check-whether-secrets-have-drifted).*

### Does `hydrate-envrc` silently fail if a `.envrc.example` value has no `inherit:` target?

Yes, and this is the one genuinely sharp edge in template hydration:
forward references (a var defined *later* in the file) resolve correctly on
the second pass, but a reference to a variable that's never defined
anywhere silently leaves the field blank instead of erroring. Only
`REQUIRED` directives get flagged in the output for manual follow-up —
broken `inherit:` targets do not.

→ *See [PROJ-HOWTO.md#how-to-generate-a-fresh-envrc-from-a-template](PROJ-HOWTO.md#how-to-generate-a-fresh-envrc-from-a-template).*

## Trust

### Where do generated secret values actually get persisted, and who can read them?

Auto-generated values (`password`/`hex`/`django` types) are written to
Infisical itself and cached locally so reruns of `populate` stay idempotent
instead of regenerating a different value each time. Anyone with the
credentials configured in `.envrc.k8.dc` (Infisical Universal Auth
client ID/secret) can read them back — the tool itself adds no separate
access control beyond what Infisical's own project permissions already
enforce.

### Does anything in this package phone home or send secrets anywhere besides my configured Infisical host?

No — every network call is the Infisical API client talking to the single
`infisical.host` configured in `infra-config.yaml`. There's no telemetry,
no secondary endpoint, and no default fallback host baked into the binary;
if `host` is misconfigured or unreachable, commands fail rather than
silently talking to somewhere else.
