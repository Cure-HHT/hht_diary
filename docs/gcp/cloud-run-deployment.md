# Cloud Run Deployment Guide

**Version**: 2.0
**Status**: Active
**Updated**: 2026-03-22
**Created**: 2025-11-25

> **Purpose**: Authoritative guide for how Cloud Run services are deployed, managed, and secured in the Clinical Trial Diary Platform. Describes the correct Terraform ↔ GitHub ↔ GCP division of responsibility.

---

## Executive Summary

The Clinical Trial Diary Platform deploys two Cloud Run services per sponsor:

1. **diary-server**: Dart backend handling database operations, authentication, and business logic
2. **portal-server**: Flutter web application for investigators and administrators

**Ownership model**:

| Concern                                      | Owner                          | How                                                                              |
|----------------------------------------------|--------------------------------|----------------------------------------------------------------------------------|
| Service shape (CPU, memory, SA, probes, VPC) | **Terraform**                  | `modules/cloud-run`                                                              |
| Container image (version, tag)               | **CI/CD**                      | `deploy-run-service.yml` via `gcloud run deploy --image`                         |
| Secrets (DB password, API keys)              | **Doppler**                    | Runtime fetch via Doppler SDK / `doppler run --`                                 |
| Doppler service token                        | **Terraform → Secret Manager** | Single bootstrap secret per project                                              |
| Database user/password                       | **Terraform**                  | `modules/cloud-sql` creates user; password from Doppler via `TF_VAR_DB_PASSWORD` |

Terraform explicitly **ignores container image changes** (`lifecycle.ignore_changes`) so CI/CD can update images without Terraform drift.

---

## Architecture Overview

```
                    ┌─────────────────────────────────────────────────┐
                    │           GCP Project (per sponsor/env)         │
                    │                                                 │
 Users ─────────────┼──▶ Cloud Run                                   │
 (HTTPS)            │    ├─ diary-server (Dart)                      │
                    │    │   ├─ Runtime SA (least-privilege)          │
                    │    │   ├─▶ Cloud SQL (private IP via VPC)      │
                    │    │   ├─▶ Doppler (runtime secret fetch)      │
                    │    │   └─▶ Identity Platform (verify JWT)      │
                    │    │                                            │
                    │    └─ portal-server (Flutter/nginx)             │
                    │        ├─ Runtime SA (least-privilege)          │
                    │        └─▶ diary-server (internal)              │
                    │                                                 │
                    │  Secret Manager                                 │
                    │    └─ DOPPLER_TOKEN (single bootstrap secret)   │
                    │                                                 │
 GitHub Actions ────┼──▶ WIF (OIDC) ──▶ Admin SA ──▶ gcloud deploy  │
                    │                                                 │
                    │  Artifact Registry (admin project)              │
                    │    └─ ghcr-remote proxy ──▶ GHCR images        │
                    │                                                 │
                    └─────────────────────────────────────────────────┘
```

---

## Service Account Architecture

There are **three distinct service account roles**. Understanding their separation is critical.

### 1. Deployment SA (GitHub Actions → WIF)

**Identity**: `github-actions-sa@cure-hht-admin.iam.gserviceaccount.com`
**Authentication**: Workload Identity Federation (GitHub OIDC token → GCP)
**No long-lived keys.** GitHub Actions presents a short-lived OIDC token that WIF exchanges for a GCP access token scoped to this SA.

**Permissions** (granted in `sponsor-envs/main.tf`):
- `roles/run.admin` — deploy/update Cloud Run services
- `roles/iam.serviceAccountUser` — act as the runtime SA during deploy
- `roles/cloudsql.client` — for `--set-cloudsql-instances` flag
- `roles/vpcaccess.user` — for `--vpc-connector` flag

**Terraform source**: `sponsor-envs/main.tf` — `google_project_iam_member.github_actions_*`

### 2. Runtime SA (Cloud Run services run as)

**Identity**: `{sponsor}-{env}-run-sa@{project}.iam.gserviceaccount.com`
**Created by**: Terraform `modules/cloud-run/main.tf` — `google_service_account.cloud_run`

This is the identity the Cloud Run containers **run as**. It should have only the permissions the application code needs at runtime.

**Permissions**:
- `roles/cloudsql.client` — connect to Cloud SQL via private IP
- `roles/secretmanager.secretAccessor` — read DOPPLER_TOKEN from Secret Manager
- `roles/logging.logWriter` — write structured logs
- `roles/monitoring.metricWriter` — emit custom metrics
- `roles/cloudtrace.agent` — distributed tracing (OpenTelemetry)

**Security note**: Without a dedicated runtime SA, Cloud Run falls back to the **Compute Engine default SA**, which typically has `roles/editor` — far too broad for a clinical trial system. The dedicated SA enforces least-privilege.

### 3. Terraform SA (infrastructure provisioning)

**Identity**: Per-project SA created by bootstrap (`terraform-sa@{project}.iam.gserviceaccount.com`)
**Used by**: `doppler run -- terraform apply` locally or CI
**Permissions**: Cloud Run Admin, Cloud SQL Admin, Secret Manager Admin, IAM Admin (scoped to project)

### Summary: SA Flow

```
GitHub OIDC token
  └─▶ WIF Pool/Provider (admin project)
        └─▶ impersonates Deployment SA
              └─▶ gcloud run deploy --service-account=Runtime SA
                    └─▶ Container runs AS Runtime SA
                          └─▶ accesses Cloud SQL, Doppler, logs
```

---

## Secrets Architecture: Doppler-First Design

### Current Architecture (ACTIVE)

The platform uses **Doppler as the single source of truth** for all application secrets. GCP Secret Manager stores exactly **one secret per project**: the Doppler service token.

```
Doppler (source of truth)
  ├─ DB_PASSWORD, API keys, Firebase config, etc.
  │
  ├─ Development: `doppler run -- flutter run`
  ├─ CI/Terraform: `doppler run -- terraform apply` (injects TF_VAR_*)
  │
  └─ Production (Cloud Run):
       ├─ DOPPLER_TOKEN stored in Secret Manager (via Terraform)
       ├─ Cloud Run env vars: DOPPLER_PROJECT_ID, DOPPLER_CONFIG_NAME
       └─ App fetches all secrets from Doppler at startup
```

**Terraform resource** (`sponsor-envs/main.tf`):
```hcl
resource "google_secret_manager_secret" "doppler_token" {
  secret_id = "DOPPLER_TOKEN"
  project   = var.project_id
  # ...
}
```

### Why NOT Secret Manager for All Secrets

The consultant's original design stored `DB_PASSWORD` directly in Secret Manager and referenced it via `secret_key_ref` in the Cloud Run module. This was replaced with the Doppler-first approach for these reasons:

| Concern | Doppler-Only | Secret Manager for All | Hybrid (Doppler+SM) |
| ------- | ------------ | ---------------------- | ------------------- |
| **Systems to secure** | 1 (Doppler) | 1 (Secret Manager) | 2 (both) |
| **Attack surface** | Doppler API | GCP IAM | Both surfaces |
| **Developer experience** | `doppler run --` | `gcloud secrets...` + setup | Mixed |
| **Terraform state risk** | Secrets not in state | Secrets in plaintext state | Partial exposure |
| **Cold start / restart** | App fetches from Doppler | Cloud Run injects from SM | Depends on secret |
| **Rotation** | Update in Doppler, restart | New SM version, redeploy | Two rotation paths |
| **Audit** | Doppler audit log | Cloud Audit Logs | Two audit systems |
| **Multi-cloud** | Yes | GCP only | Partial |
| **FDA compliance** | SOC 2, BAA available | SOC 2 (GCP-wide) | Both |

**Decision**: Doppler-only with a single DOPPLER_TOKEN in Secret Manager is the simplest, most auditable design. One system to secure, one audit trail, one rotation process.

### Cold Start Implications

When Cloud Run starts a new instance or restarts after a crash:
- **Doppler approach**: App makes an HTTPS call to Doppler API to fetch secrets (~100-200ms). If Doppler is down, the container fails to start (Cloud Run retries with backoff).
- **Secret Manager approach**: Cloud Run injects env vars from SM before container starts (no app code needed). If SM is down, container also fails.

Both have a single-point-of-failure for secret retrieval at startup. The difference is ~100-200ms of additional startup time for Doppler, which is negligible compared to Dart JIT compilation (30-60s).

### What the DB_PASSWORD Secret Is For

The `DB_PASSWORD` is the PostgreSQL password for the `app_user` role in Cloud SQL. It is used:

1. **By Terraform** (`modules/cloud-sql`): Creates the `google_sql_user.app_user` with this password
2. **By the Dart server**: Connects to Cloud SQL via the Cloud SQL Auth Proxy (private IP)

The database runs as a **managed Cloud SQL instance** (not a container). Cloud SQL is a fully managed PostgreSQL service — there are no "DB containers." The `gcloud sql` commands configure the managed instance; they don't create or run containers.

---

## Terraform ↔ CI/CD Division of Responsibility

### What Terraform Owns

Terraform manages the **infrastructure shape** — everything that doesn't change on every deploy:

```hcl
# infrastructure/terraform/modules/cloud-run/main.tf

resource "google_cloud_run_v2_service" "diary_server" {
  # Terraform owns:
  #   - Service name, region, project
  #   - Runtime service account
  #   - CPU, memory, scaling limits
  #   - VPC connector, egress settings
  #   - Health probes (startup, liveness)
  #   - Execution environment (Gen2)
  #   - Environment variables (non-secret)
  #   - Traffic routing (100% latest)

  lifecycle {
    ignore_changes = [
      client,
      template[0].containers[0].image,  # ← CI/CD owns this
      template[0].containers[0].name,
    ]
  }
}
```

### What CI/CD Owns

CI/CD manages the **container image** — the thing that changes on every deploy:

```yaml
# .github/workflows/deploy-run-service.yml
gcloud run deploy diary-server \
  --image="$GAR_PATH" \          # ← CI/CD sets this
  --set-env-vars="DOPPLER_PROJECT_ID=...,DOPPLER_CONFIG_NAME=...,SPONSOR_ID=..."
```

### The Handoff

1. **First deploy**: `terraform apply` creates the Cloud Run service with a placeholder image
2. **Subsequent deploys**: CI/CD runs `gcloud run deploy --image=NEW_TAG`, updating only the image
3. **Infrastructure changes**: `terraform apply` updates probes, memory, SA, etc. — ignores image
4. **No conflict**: The `lifecycle.ignore_changes` on `image` prevents Terraform from reverting CI/CD's image updates

### Container Image Path

Images flow through a **GHCR remote proxy** in the admin project's Artifact Registry:

```
GHCR (source)                    Artifact Registry (proxy)           Cloud Run
ghcr.io/cure-hht/diary-server → europe-west9-docker.pkg.dev/       → pulls from proxy
                                  cure-hht-admin/ghcr-remote/
                                  cure-hht/diary-server:v1.2.3
```

CI/CD translates the `ghcr.io/...` path to the GAR proxy path before deploying.

---

## Current Deployment Status

### What's Active (via gcloud/CI)

The `deploy-run-service.yml` workflow currently deploys using `gcloud run deploy` directly. Terraform has **not yet been uncommented** for Cloud Run (`sponsor-envs/main.tf` lines 165-195 are commented out).

Current live deploy command:
```yaml
gcloud run deploy $SERVICE_NAME \
  --region=$GCP_REGION \
  --project=$CALLISTO_TARGET_PROJECT_ID \
  --image="$GAR_PATH" \
  --cpu=2 --cpu-boost --memory=4Gi \
  --min-instances=0 --max-instances=2 \
  --set-cloudsql-instances=$CALLISTO_DB_CONNECTION_NAME \
  --vpc-connector $CALLISTO_SERVERLESS_VPC_CONNECTOR \
  --set-env-vars="DOPPLER_PROJECT_ID=hht-diary,DOPPLER_CONFIG_NAME=$ENV,SPONSOR_ID=callisto"
```

### What's Pending (Terraform Module)

The `modules/cloud-run` module is ready but needs two fixes before uncommenting:

1. **Replace `db_password_secret_id`** with Doppler env vars pattern (see "Secrets Architecture" above)
2. **Wire the runtime SA** to the deployment workflow's `--service-account` flag

---

## Prerequisites

1. **GCP Project Configured**: See `docs/gcp/project-structure.md`
2. **Cloud SQL Instance Running**: See `docs/gcp/cloud-sql-setup.md`
3. **Identity Platform Configured**: See `docs/gcp/identity-platform-setup.md`
4. **Doppler Project/Config**: Secrets configured in Doppler for the sponsor/environment
5. **WIF configured**: Admin project has GitHub OIDC pool/provider (see bootstrap)

**Required APIs** (enabled by Terraform bootstrap):
- `run.googleapis.com`
- `artifactregistry.googleapis.com`
- `secretmanager.googleapis.com`
- `vpcaccess.googleapis.com`
- `sqladmin.googleapis.com`

---

## Terraform State Configuration

State is stored in GCS bucket `cure-hht-terraform-state`:

| Workspace | Prefix | Backend |
| --------- | ------ | ------- |
| bootstrap | `bootstrap/{sponsor}` | `gcs {}` (configured via `-backend-config`) |
| admin-project | `admin-project` | `gcs { bucket = "cure-hht-terraform-state" }` |
| sponsor-envs | varies | `gcs {}` (configured via `-backend-config`) |

**Running Terraform** (sponsor-envs):
```bash
# Initialize with backend config
doppler run -- terraform init \
  -backend-config="bucket=cure-hht-terraform-state" \
  -backend-config="prefix=sponsor-envs/callisto4-dev"

# Plan
doppler run -- terraform plan \
  -var-file=sponsor-configs/callisto4-dev.tfvars

# Apply
doppler run -- terraform apply \
  -var-file=sponsor-configs/callisto4-dev.tfvars
```

The `-backend-config` approach allows the same Terraform code to be used across sponsors/environments with different state prefixes.

---

## Security Implications

### Service Account Risks

| Risk | Mitigation |
| ---- | ---------- |
| Default Compute SA has `roles/editor` | Dedicated runtime SA with 5 specific roles |
| Deployment SA could be over-privileged | Scoped to run.admin + sa.user per project |
| SA key leakage | No keys — WIF for CI/CD, SA impersonation for Terraform |
| Cross-sponsor access | Separate projects, separate SAs, no cross-project IAM |

### Secrets Risks

| Risk | Mitigation |
| ---- | ---------- |
| Doppler outage at cold start | Cloud Run retries with backoff; min_instances=1 for prod |
| DOPPLER_TOKEN leaked | Stored in Secret Manager with IAM-scoped access |
| DB password in Terraform state | State in GCS with encryption; consider state encryption |
| Secrets in CI/CD logs | Doppler env vars are non-secret identifiers only |

### FDA 21 CFR Part 11 Compliance

- **Audit trail**: All deploys tracked in GitHub Actions logs + Cloud Audit Logs
- **Access control**: WIF + IAM, no shared credentials
- **Data integrity**: Container images are immutable (SHA-tagged)
- **Electronic signatures**: Git commit signatures + PR approvals

---

## Monitoring and Troubleshooting

### View Service Status

```bash
# List services
gcloud run services list --region=europe-west9 --project=$PROJECT_ID

# Describe a service
gcloud run services describe diary-server --region=europe-west9 --project=$PROJECT_ID

# View recent revisions
gcloud run revisions list --service=diary-server --region=europe-west9 --project=$PROJECT_ID
```

### View Logs

```bash
# Recent errors
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=diary-server AND severity>=ERROR" \
  --limit=20 --project=$PROJECT_ID

# Structured log query
gcloud logging read 'resource.type="cloud_run_revision" severity>=WARNING' \
  --project=$PROJECT_ID --format="table(timestamp,severity,textPayload)"
```

### Database Connection Issues

```bash
# Verify VPC connector
gcloud compute networks vpc-access connectors describe $VPC_CONNECTOR \
  --region=europe-west9 --project=$PROJECT_ID

# Check Cloud SQL instance status
gcloud sql instances describe $INSTANCE_NAME --project=$PROJECT_ID
```

---

## Appendix A: gcloud Script Equivalents

The following `gcloud` commands show what Terraform does declaratively. **Do not run these manually** — they are for reference only. Use Terraform for all infrastructure changes.

### Service Account Creation (Terraform: `modules/cloud-run/main.tf`)

```bash
# What Terraform does:
gcloud iam service-accounts create ${SPONSOR}-${ENV}-run-sa \
  --display-name="Cloud Run Service Account - ${SPONSOR} ${ENV}" \
  --project=$PROJECT_ID

# Grant roles
for ROLE in roles/cloudsql.client roles/secretmanager.secretAccessor \
            roles/logging.logWriter roles/monitoring.metricWriter roles/cloudtrace.agent; do
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SPONSOR}-${ENV}-run-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="$ROLE"
done
```

### Cloud Run Service Creation (Terraform: `modules/cloud-run/main.tf`)

```bash
# What Terraform does for diary-server:
gcloud run deploy diary-server \
  --image=$DIARY_SERVER_IMAGE \
  --region=europe-west9 \
  --project=$PROJECT_ID \
  --service-account=${SPONSOR}-${ENV}-run-sa@${PROJECT_ID}.iam.gserviceaccount.com \
  --cpu=2 --memory=4Gi \
  --min-instances=1 --max-instances=10 \
  --cpu-boost \
  --set-cloudsql-instances=$CLOUDSQL_CONNECTION_NAME \
  --vpc-connector=$VPC_CONNECTOR \
  --vpc-egress=private-ranges-only \
  --execution-environment=gen2 \
  --timeout=300s \
  --set-env-vars="ENVIRONMENT=$ENV,SPONSOR=$SPONSOR,PROJECT_ID=$PROJECT_ID,DB_HOST=$DB_HOST,DB_PORT=5432,DB_NAME=$DB_NAME,DB_USER=$DB_USER,LOG_LEVEL=info" \
  --ingress=all \
  --allow-unauthenticated
```

### Workload Identity Federation (Terraform: `bootstrap/main.tf`)

```bash
# What Terraform does:
gcloud iam workload-identity-pools create github-pool \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  --project=$ADMIN_PROJECT_ID

gcloud iam workload-identity-pools providers create-oidc github-provider \
  --location="global" \
  --workload-identity-pool=github-pool \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --project=$ADMIN_PROJECT_ID

gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/Cure-HHT/hht_diary" \
  --project=$ADMIN_PROJECT_ID
```

### VPC Connector (Terraform: `modules/vpc-network`)

```bash
# What Terraform does:
gcloud compute networks vpc-access connectors create ${SPONSOR}-vpc-connector \
  --region=europe-west9 \
  --network=$VPC_NETWORK \
  --range=$CONNECTOR_CIDR \
  --min-instances=2 \
  --max-instances=10 \
  --project=$PROJECT_ID
```

### Artifact Registry GHCR Proxy (Terraform: `admin-project/main.tf`)

```bash
# What Terraform does in the admin project:
gcloud artifacts repositories create ghcr-remote \
  --repository-format=docker \
  --mode=remote-repository \
  --remote-repo-config-desc="GHCR proxy" \
  --remote-docker-repo="https://ghcr.io" \
  --location=europe-west9 \
  --project=cure-hht-admin
```

---

## Appendix B: Security Checklist

- [x] Dedicated runtime SA with least-privilege roles
- [x] WIF for CI/CD (no long-lived keys)
- [x] VPC connector for private Cloud SQL access
- [x] Single Doppler token in Secret Manager (not individual secrets)
- [x] Container images scanned by Trivy in CI
- [x] HTTPS enforced (automatic with Cloud Run)
- [x] Authentication middleware validates JWT tokens
- [x] CORS configured correctly
- [x] Security headers set in nginx (portal)
- [x] EU data residency enforced (europe-west9)
- [ ] Runtime SA wired to Cloud Run (pending Terraform uncommenting)
- [ ] Secret Manager `db_password_secret_id` replaced with Doppler pattern in module

---

## References

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud Run + Cloud SQL](https://cloud.google.com/sql/docs/postgres/connect-run)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Doppler GCP Integration](https://docs.doppler.com/docs/gcp-secret-manager)
- **Project Structure**: `docs/gcp/project-structure.md`
- **Cloud SQL Setup**: `docs/gcp/cloud-sql-setup.md`
- **Identity Platform**: `docs/gcp/identity-platform-setup.md`
- **Secrets Comparison**: `docs/migration/doppler-vs-secret-manager.md`
- **Terraform Modules**: `infrastructure/terraform/modules/cloud-run/`

---

## Change Log

| Date | Version | Changes | Author |
| ---- | ------- | ------- | ------ |
| 2025-11-25 | 1.0 | Initial Cloud Run deployment guide | Claude |
| 2026-03-22 | 2.0 | Complete rewrite: correct Terraform↔CI/CD ownership model, Doppler-first secrets architecture, dedicated runtime SA documentation, gcloud scripts moved to appendix, security implications added, removed outdated Secret Manager patterns | Claude |
