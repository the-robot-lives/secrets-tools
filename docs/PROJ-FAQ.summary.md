# k8/secret-utils — FAQ Summary

Question index only. Full answers in [PROJ-FAQ.md](PROJ-FAQ.md).

## Motivation
- Why would I use this instead of just setting env vars or plain `.env` files?
- Why does credential resolution have four layers (dc → env override → auto-generate → default) instead of one?
- Why keep 11 legacy Bash scripts around when the Rust `infisical` binary does everything?

## Fit
- When is this the wrong tool for a secret?
- When should I reach for `infisical bootstrap` versus `populate`?

## Comparison
- How does `infisical set` differ from editing the value directly in the Infisical UI/API?
- How does `--cascade` on `set` differ from actually rotating downstream secrets?

## Capability
- Can `infisical populate` run in parallel across many sections at once?
- Can I recover if I lose `.envrc.dc` entirely and never had a backup?

## Caveats
- Is it safe to run `--show-secrets` or `--show-diff` in a recorded terminal session or CI log?
- If `infisical verify` prints a clean-looking table, is that enough to confirm everything's in sync?
- Does `hydrate-envrc` silently fail if a `.envrc.example` value has no `inherit:` target?

## Trust
- Where do generated secret values actually get persisted, and who can read them?
- Does anything in this package phone home or send secrets anywhere besides my configured Infisical host?
