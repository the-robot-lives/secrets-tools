# How to: populate just one section, fast

**Goal:** seed or refresh a subset of secrets without waiting on the full config, and fan multiple sections out in parallel when there's more than one.
**Prereqs:** credentials + config discovery already working (see main [PROJ-HOWTO.md](../PROJ-HOWTO.md)).

## List what's available

```bash
infisical populate --list
```

Shows every section/group id defined in the config so you know what to target.

## Run one section

```bash
infisical populate --section webui --dry-run   # preview
infisical populate --section webui             # apply
```

## Run several sections, or a group, at once

The Rust binary's `--section` only accepts one value per invocation. The
**legacy Bash script** (`infisical-populate-secrets`) additionally supports
passing `--section` more than once, or naming a `v1`-schema *group* that
expands to multiple member sections:

```bash
infisical-populate-secrets --section data-postgres --section data-redis
infisical-populate-secrets --section data-tier          # a group, if defined
```

When the expansion resolves to 2+ distinct sections, the script fans them out:

- **With `zellij` on `PATH`**: launches (or, if already inside a zellij
  session, adds tabs to it) one tab per section, each running
  `infisical-populate-secrets --section <sec>` via a re-invocation of the
  script's own resolved absolute path — not a `PATH` lookup, so it stays
  pinned to the binary you actually ran even if another `infisical-populate-secrets`
  is earlier on `PATH`.
- **Without `zellij`**: falls back to running each section sequentially in
  the current terminal, printing a `═══ section: <name> ═══` banner between
  them.

A single resolved section (even from a group that happens to expand to just
one) always runs inline — no zellij, no fan-out.

**Verify:** with zellij, you'll be dropped into (or see new tabs in) a
session named after the run; without it, each section's summary prints in
turn in the same terminal.

**Gotchas:**
- Flags other than `--section` (env, `--dry-run`, `--show-secrets`, etc.) are
  forwarded to every child invocation automatically — set them once on the
  outer command.
- If you're already inside a zellij session, the script adds tabs to *that*
  session rather than nesting a new one.
- Unknown section/group ids fail fast with `❌ Unknown section/group: <name>`
  before anything launches.
