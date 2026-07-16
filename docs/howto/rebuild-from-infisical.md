# How to: recover from a lost or out-of-sync .envrc.dc / config

**Goal:** regenerate `.envrc.dc` and `.infisical-secrets.yaml` from what's
actually live on the Infisical server, when local files are missing, stale,
or you've inherited a project with no local secrets config at all.
**Prereqs:** working Infisical credentials (`K8_INFISICAL_CLIENT_ID`/`_SECRET`); nothing local needs to pre-exist.

## Run it in phases

`rebuild` inventories, analyzes, then generates — you can stop after any
phase to inspect its output before continuing:

```bash
infisical rebuild --phase scan       # inventory what's live in Infisical
infisical rebuild --phase analyze    # group/classify against existing local files (if any)
infisical rebuild --phase generate --show-secrets   # write .envrc.dc + .infisical-secrets.yaml
```

Or just run everything in one pass:

```bash
infisical rebuild --dry-run          # preview the full pipeline first
infisical rebuild                    # then for real
```

Output lands in `.rebuild/` (override with `--output-dir`) before being
promoted — check that directory if you want to review before it touches
your real `.envrc.dc`.

**Verify:**
```bash
infisical verify --env prod
```
should show no mismatches once the rebuilt files are in place.

**Gotchas:**
- `--phase generate` needs `--show-secrets` — without it there are no values
  to write, and the phase produces empty/placeholder entries instead of
  failing loudly, so pass it explicitly for `generate` and `all`.
- This is a recovery tool, not a normal workflow step — prefer `populate`/`set`
  for day-to-day changes; `rebuild` should be rare enough that you always
  `--dry-run` it first.
- Values retrieved this way land in the `--output-dir` staging area, not
  directly overwriting your live files — a stale `.rebuild/` from a previous
  run can be mistaken for fresh output if you forget to re-run before generate.
