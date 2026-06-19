# Security: Secret Management (moved to hht_admin)

> Secret management for the platform — architecture, identity, the secret taxonomy, per-sponsor
> secrets, storage rules, and automated rotation — is owned and documented authoritatively in
> **`hht_admin`**:
>
> - **`hht_admin/spec/ops-secrets-architecture.md`** — the secrets / identity / sponsor-config architecture
> - **`hht_admin/spec/ops-secrets-bootstrap.md`** — the bootstrap procedure
>
> Local pointers:
> - `docs/setup-doppler.md` — quick summary of the model
> - `docs/security/scanning-strategy.md` — repo-local secret scanning (gitleaks pre-commit + CI)

## Summary

Secret **values** live in Doppler (one source of truth). CI fetches them at job time via
Doppler GitHub OIDC + GCP Workload Identity Federation — no static `DOPPLER_TOKEN` service
tokens or JSON keys. Terraform in `hht_admin` (identity) and `hht_sponsor_iac` (sponsor modules)
manages identity and routing — **never values**; sponsor literals live in each sponsor repo's
`sponsor.toml` + `<id>.tfvars`; rotation is automated and PR-gated.
