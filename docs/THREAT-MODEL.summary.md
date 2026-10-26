# Threat Model Summary — k8/secret-utils

`secret-utils` moves credential values between `.envrc.dc`, `.infisical-secrets.yaml`,
the Infisical API, GitHub Actions, and (tier-0) k8s Secrets. The tools persist
nothing; risk lives in in-flight handling and endpoint trust. Derived from source
structure only — no secret values are reproduced.

Full model: [THREAT-MODEL.md](THREAT-MODEL.md).

## Trust Boundaries

1. Local shell/env ↔ encrypted dc store (`--reveal --raw`; redaction masks refused)
2. CLI ↔ Infisical API (Universal Auth bearer, config-driven host, optional CF Access)
3. CLI ↔ GitHub API (`gh` token, values on stdin, owner allowlist)
4. CLI ↔ k8s API (tier-0 `kubectl` bootstrap)
5. `.infisical-secrets.yaml` (reviewed-but-untrusted input) ↔ engine
6. Downstream: Infisical operator + CRDs → k8s Secrets → pods

## Register (14 entries)

- **Mitigated (9)**: T-001/T-002 argv value leaks → stdin; T-003 redaction
  sentinel refused; T-004 whole-file populate scope gate; T-005 `<<` merge-key
  injection; T-006 failed writes exit non-zero; T-007 GitHub plan-sha drift;
  T-008 GitHub fan-out to foreign target (allowlist/anchor/identity gates);
  T-014 `hydrate-envrc` `chmod 600`.
- **Partial (3)**: T-010 interactive `--show-secrets`/`--show-diff` value flags;
  T-012 no Infisical host certificate pinning; T-013 supply chain (only
  `Cargo.lock` pinned).
- **Open (1)**: T-009 `infisical-bootstrap` passes values in `kubectl
  --from-literal` argv (visible via `ps`); recommended fix = manifest on stdin.
- **Accepted (1)**: T-011 local credential custody — anyone who can read the
  dc store/env can read every value; no added ACL beyond Infisical permissions.

## Residual Risk

Interactive value flags, local credential custody, and host trust are accepted
and documented. T-009 is the one open item, mitigated by running bootstrap once,
on a controlled, non-shared host.
