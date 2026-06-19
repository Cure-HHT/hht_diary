# Secrets Setup (moved to hht_admin)

> **Secrets management is no longer set up from this repo.** Secrets, identity, and per-sponsor
> configuration are managed cross-org and documented authoritatively in **`hht_admin`**:
>
> - **`hht_admin/spec/ops-secrets-architecture.md`** — the secrets / identity / sponsor-config architecture
> - **`hht_admin/spec/ops-secrets-bootstrap.md`** — the bootstrap procedure

## How it works (summary)

- Every app/runtime secret **value** lives in **Doppler** (one source of truth) — nowhere else.
- Machine-to-machine boundaries use **ephemeral identity**: **Doppler GitHub OIDC** + **GCP
  Workload Identity Federation** (no static `DOPPLER_TOKEN` service tokens or JSON keys).
- **Terraform** in `hht_admin` (identity) and `hht_sponsor_iac` (sponsor modules) manages
  **identity and routing — never values**. Sponsor literals live in each sponsor repo's
  `sponsor.toml` + `<id>.tfvars`.
- Rotation is automated and PR-gated.
- The runtime mechanism is the `doppler-oidc-auth` / `gcp-wif-auth` composite actions in
  **`hht_workflows`**.
