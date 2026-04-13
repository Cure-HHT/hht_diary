# Diary Platform

Multi-sponsor clinical trial diary platform with FDA 21 CFR Part 11 compliance.

---

## Repository Structure

This is the **core repo** — contains all app source code and shared packages.
Sponsor-specific deployment, content, and infrastructure live in separate repos.

```
apps/
├── daily-diary/
│   ├── clinical_diary/     Flutter mobile app (iOS + Android)
│   ├── diary_server/       Dart shelf HTTP server (Cloud Run)
│   └── diary_functions/    Business logic library
├── sponsor-portal/
│   ├── portal-ui/          Flutter web app
│   ├── portal_server/      Dart shelf HTTP server (Cloud Run)
│   └── portal_functions/   Business logic library
├── common-dart/
│   ├── otel_common/        Shared OpenTelemetry instrumentation
│   ├── trial_data_types/   Shared data types
│   └── shared_functions/   Shared utilities
└── edc/
    └── rave-integration/   Medidata RAVE EDC integration

database/                   PostgreSQL schema, triggers, RLS policies, migrations
infrastructure/terraform/
├── modules/                Reusable Terraform modules (shared via hht_sponsor_iac)
├── sponsor-envs/           Per-sponsor environment configs (migrating to sponsor repos)
└── bootstrap/              Creates GCP projects for new sponsors
```

## Related Repos

| Repo | Purpose |
| --- | --- |
| `hht_diary` (this repo) | Core app source code, shared packages, sponsor-ci base image |
| `hht_admin` | Admin-project Terraform (GAR, Gmail SA, IAM, WIF) |
| `hht_sponsor_iac` | Reusable Terraform modules + workflow templates |
| `hht_diary_{sponsor}` | Sponsor-specific deployment, content, seed data, infrastructure |

---

## CI/CD Architecture

### What This Repo Builds

This repo has one CI/CD responsibility: **building the `sponsor-ci` base image**.

```
hht_diary push to main
  └─→ build-sponsor-ci.yml
        └─→ Builds: ghcr.io/cure-hht/sponsor-ci:main-latest
              Contains: all app source + resolved dependencies (no compilation)
```

Sponsor repos pull this base image, overlay their content, compile, and deploy.
See `hht_diary_callisto/deployment/README.md` for the full container layering.

### What This Repo Does NOT Build

Deployment is owned by sponsor repos. The following workflows were removed
because they were replaced by the sponsor-repo deployment model:

- `build-portal-server.yml` — replaced by `hht_diary_callisto` build workflows
- `build-diary-server.yml` — replaced by `hht_diary_callisto` build workflows
- `deploy-run-service.yml` — replaced by `hht_diary_callisto` deploy workflows

### Terraform

This repo manages **sponsor-envs** Terraform only (Cloud Run, Cloud SQL, VPC
per sponsor environment). Admin-project Terraform moved to `hht_admin`.

| Trigger | What happens |
| --- | --- |
| PR touching `infrastructure/terraform/**` | `terraform plan` for sponsor-envs/dev, posted as PR comment |
| Merge to main | Auto-apply sponsor-envs/dev |
| Manual dispatch (Actions UI) | Plan or apply any sponsor/environment |

### Service Accounts

| SA | GitHub Variable | Purpose |
| --- | --- | --- |
| `admin-cicd-sa@cure-hht-admin...` | `CUREHHT_ADMIN_SA_EMAIL` | Admin-project Terraform (in `hht_admin` repo) |
| `github-actions-sa@cure-hht-admin...` | `GCP_SA_EMAIL` | Sponsor-envs Terraform + Cloud Run deploys |

Both authenticate via Workload Identity Federation (WIF) — no JSON key files.

### Other Workflows

| Workflow | Purpose |
| --- | --- |
| `build-sponsor-ci.yml` | Builds the shared base image on push to main |
| `terraform-validate.yml` | Sponsor-envs Terraform plan/apply |
| `qa-automation.yml` | PR validation (tests, linting, analysis) |
| `reset-db-gcp.yml` | Database schema reset for dev/qa/uat |

---

## Documentation

### spec/ — Formal Requirements

Requirements documents defining WHAT the system does, organized by audience:

- **prd-\*** — Product requirements (no code)
- **ops-\*** — Operations (deployment, monitoring, CLI commands)
- **dev-\*** — Development (implementation details, code examples)

See `spec/README.md` for the complete map and `spec/INDEX.md` for the REQ index.

### docs/ — Implementation Documentation

- `docs/adr/` — Architecture Decision Records
- `docs/gcp/` — GCP setup guides (Cloud SQL, Identity Platform, Cloud Run)
- `docs/ops-incident-response-runbook.md` — Incident response procedures
- `docs/ops-deployment-production-tagging-hotfix.md` — Release process

---

## Development

### Initial Setup

```bash
./tools/setup-repo.sh
```

Configures Git hooks for commit validation, requirement traceability, and secret scanning.

### Local Development

Each app has its own `tool/run_local.sh`:

```bash
# Portal (DB + Firebase emulator + server + UI)
cd apps/sponsor-portal
./tool/run_local.sh

# Diary server
cd apps/daily-diary
./tool/run_local.sh
```

See `apps/sponsor-portal/README.md` and `apps/daily-diary/clinical_diary/README.md`
for detailed setup, environment variables, and troubleshooting.

### Database

Located in `database/`:

| File | Purpose |
| --- | --- |
| `schema.sql` | Core table definitions |
| `triggers.sql` | Event store triggers |
| `roles.sql` | User roles and RLS helper functions |
| `rls_policies.sql` | Row-level security policies |
| `migrations/` | Schema migrations |
| `init.sql` | Master initialization script |

### Deployment Doctor

Health check scripts for deployed services:

```bash
# Portal server
./apps/sponsor-portal/tool/deployment-doctor.sh --url https://portal-service-XXXX.run.app --verbose

# Diary server
./apps/daily-diary/tool/deployment-doctor.sh --url https://diary-service-XXXX.run.app --verbose
```

Checks: health endpoint, versions, HTTPS, API smoke tests, Cloud Logging signals.

### Observability

Both servers use OpenTelemetry via `otel_common`:

| Signal | What | Where |
| --- | --- | --- |
| Traces | Per-request spans, DB queries, FCM sends | Cloud Trace (via OTLP) |
| Logs | Structured JSON with trace correlation | Cloud Logging + OTLP |
| Metrics | Request counts, latencies, auth attempts, FCM, questionnaire ops | Cloud Monitoring |

---

## Target Platform

- **Compute**: GCP Cloud Run (europe-west9)
- **Database**: GCP Cloud SQL PostgreSQL 17 (private VPC)
- **Auth**: GCP Identity Platform (portal), JWT (diary mobile)
- **Secrets**: Doppler
- **Container Registry**: GitHub Container Registry (GHCR) + Google Artifact Registry (GAR)
- **IaC**: Terraform with GCS backend

---

## External Resources

- PostgreSQL Docs: https://www.postgresql.org/docs/
- GCP Identity Platform: https://cloud.google.com/security/products/identity-platform
- FDA 21 CFR Part 11: https://www.fda.gov/regulatory-information
- Flutter Docs: https://docs.flutter.dev/
- Linear (tickets): https://linear.app/cure-hht-diary
