# GCP Project Structure

**Version**: 1.0
**Status**: Active
**Created**: 2025-11-25

> **Purpose**: Define the GCP project organization for the Clinical Trial Diary Platform, implementing multi-sponsor isolation through separate GCP projects.

---

## Executive Summary

The Clinical Trial Diary Platform uses a **one GCP project per sponsor per environment** model to ensure complete data isolation between pharmaceutical sponsors. This architecture supports HIPAA, GDPR, and FDA 21 CFR Part 11 compliance requirements.

**Key Principles**:
- Each sponsor operates in isolated GCP projects
- Core platform code is shared; infrastructure is isolated
- Environment separation (dev, staging, production) per sponsor
- Centralized billing with per-sponsor cost tracking

---

## Project Hierarchy

### Organization Structure

```
Anspar Organization (or Customer Org)
├── Folders
│   ├── clinical-diary-platform/
│   │   ├── clinical-diary-core-dev        # Platform development
│   │   └── clinical-diary-core-staging    # Platform testing
│   │
│   ├── sponsor-orion/
│   │   ├── hht-diary-orion-staging        # Orion UAT/staging
│   │   └── hht-diary-orion-prod           # Orion production
│   │
│   ├── sponsor-andromeda/
│   │   ├── hht-diary-andromeda-staging    # Andromeda UAT/staging
│   │   └── hht-diary-andromeda-prod       # Andromeda production
│   │
│   └── sponsor-{name}/                    # Template for new sponsors
│       ├── hht-diary-{name}-staging
│       └── hht-diary-{name}-prod
│
└── Billing Account
    └── Sub-accounts per sponsor (optional)
```

### Project Naming Convention

**Format**: `hht-diary-{sponsor}-{environment}`

| Component | Values | Example |
| --- | --- | --- |
| Prefix | `hht-diary` | `hht-diary` |
| Sponsor | Sponsor code (lowercase) | `orion`, `andromeda` |
| Environment | `dev`, `staging`, `prod` | `prod` |

**Examples**:
- `hht-diary-orion-prod` - Orion production
- `hht-diary-orion-staging` - Orion staging/UAT
- `hht-diary-andromeda-prod` - Andromeda production
- `hht-diary-core-dev` - Core platform development

---

## Per-Project Resources

Each sponsor project contains isolated instances of:

### Compute & Hosting

| Resource | Purpose | Naming |
| --- | --- | --- |
| Cloud Run (API) | Dart backend server | `api-{sponsor}-{env}` |
| Cloud Run (Portal) | Flutter web portal | `portal-{sponsor}-{env}` |

### Database

| Resource | Purpose | Naming |
| --- | --- | --- |
| Cloud SQL | PostgreSQL database | `{sponsor}-db-{env}` |
| VPC Connector | Private DB access | `{sponsor}-vpc-connector` |

### Authentication

| Resource | Purpose | Naming |
| --- | --- | --- |
| Identity Platform | User authentication | Per-project (automatic) |
| Custom Claims Function | RBAC claims | `custom-claims-{env}` |

### Secrets & Config

| Resource | Purpose | Naming |
| --- | --- | --- |
| Secret Manager | Production secrets | `{secret-name}` |
| Runtime Config | Feature flags | `{sponsor}-config` |

### Storage

| Resource | Purpose | Naming |
| --- | --- | --- |
| Cloud Storage | Backups, exports | `{project-id}-backups` |
| Artifact Registry | Container images | `{sponsor}-images` |

### Monitoring

| Resource | Purpose | Naming |
| --- | --- | --- |
| Cloud Logging | Centralized logs | Automatic |
| Cloud Monitoring | Metrics/alerts | Per-project dashboards |
| Uptime Checks | Health monitoring | `{service}-health` |

---

## Network Architecture

### VPC Configuration

Each project uses a dedicated VPC with private connectivity:

```
┌─────────────────────────────────────────────────────────────┐
│  GCP Project: hht-diary-orion-prod                          │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  VPC: orion-prod-vpc                                │   │
│  │                                                     │   │
│  │  ┌─────────────┐    ┌─────────────────────────┐    │   │
│  │  │ Cloud Run   │────│ Serverless VPC Access   │    │   │
│  │  │ (API)       │    │ Connector               │    │   │
│  │  └─────────────┘    └───────────┬─────────────┘    │   │
│  │                                 │                   │   │
│  │  ┌─────────────┐                │                   │   │
│  │  │ Cloud Run   │────────────────┤                   │   │
│  │  │ (Portal)    │                │                   │   │
│  │  └─────────────┘                │                   │   │
│  │                                 ▼                   │   │
│  │                     ┌─────────────────────────┐    │   │
│  │                     │ Cloud SQL (Private IP)  │    │   │
│  │                     │ PostgreSQL              │    │   │
│  │                     └─────────────────────────┘    │   │
│  │                                                     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  External Access (HTTPS only):                              │
│  - api-orion.clinicaltrial.app                             │
│  - portal-orion.clinicaltrial.app                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### IP Ranges

| Component | CIDR | Notes |
| --- | --- | --- |
| VPC Primary | `10.{sponsor_id}.0.0/20` | Main subnet |
| VPC Connector | `10.{sponsor_id}.16.0/28` | Serverless access |
| Cloud SQL | `10.{sponsor_id}.32.0/24` | Private Services |

---

## IAM Structure

### Project-Level Roles

| Role | Purpose | Principals |
| --- | --- | --- |
| Owner | Full admin | Platform team leads |
| Editor | Deploy/manage | DevOps engineers |
| Viewer | Read-only | Support, auditors |
| Cloud Run Admin | Service management | CI/CD service account |
| Cloud SQL Admin | Database management | DBAs |
| Secret Manager Admin | Secrets management | Security team |

### Service Accounts

Each project has dedicated service accounts:

```
# Cloud Run API server
api-server@{project-id}.iam.gserviceaccount.com
  - roles/cloudsql.client
  - roles/secretmanager.secretAccessor
  - roles/logging.logWriter

# Cloud Run Portal
portal-server@{project-id}.iam.gserviceaccount.com
  - roles/logging.logWriter

# CI/CD deployment
cicd-deployer@{project-id}.iam.gserviceaccount.com
  - roles/run.admin
  - roles/artifactregistry.writer
  - roles/secretmanager.secretAccessor

# Database migrations
db-migrator@{project-id}.iam.gserviceaccount.com
  - roles/cloudsql.client
  - roles/cloudsql.admin (limited scope)
```

---

## Billing & Cost Management

### Billing Structure

```
Organization Billing Account
├── hht-diary-core-dev          (platform development costs)
├── hht-diary-core-staging      (platform testing costs)
├── hht-diary-orion-staging     (Orion sponsor - staging)
├── hht-diary-orion-prod        (Orion sponsor - production)
├── hht-diary-andromeda-staging (Andromeda sponsor - staging)
└── hht-diary-andromeda-prod    (Andromeda sponsor - production)
```

### Cost Allocation Labels

All resources tagged with:

| Label | Purpose | Example Values |
| --- | --- | --- |
| `sponsor` | Cost attribution | `orion`, `andromeda` |
| `environment` | Env classification | `dev`, `staging`, `prod` |
| `service` | Service identification | `api`, `portal`, `database` |
| `managed-by` | IaC identification | `terraform` |

### Budget Alerts

Per-project budget alerts:
- 50% - Notification to project owner
- 80% - Notification to finance team
- 100% - Escalation to platform leads

---

## Environment Isolation

### Development (`*-dev`)
- Shared core platform development
- Internal testing only
- Relaxed security (dev credentials)
- May use smaller instance sizes

### Staging (`*-staging`)
- Per-sponsor UAT environment
- Mirrors production configuration
- Test data only (no PHI)
- Used for sponsor acceptance testing

### Production (`*-prod`)
- Per-sponsor production environment
- Contains real PHI/PII data
- Full security controls
- HIPAA BAA in place
- Audit logging enabled

---

## Creating a New Sponsor Project

### Prerequisites

1. Sponsor agreement signed
2. Billing arrangement confirmed
3. Domain/subdomain allocated
4. Sponsor code assigned (lowercase, no spaces)

### Provisioning Steps

```bash
# 1. Set variables
export SPONSOR="newsponsor"
export ENV="prod"
export PROJECT_ID="hht-diary-${SPONSOR}-${ENV}"
export REGION="europe-west1"  # EU region for GDPR compliance
export BILLING_ACCOUNT="XXXXXX-XXXXXX-XXXXXX"

# 2. Create project
gcloud projects create $PROJECT_ID \
  --name="HHT Diary ${SPONSOR} ${ENV}" \
  --folder=FOLDER_ID

# 3. Link billing
gcloud billing projects link $PROJECT_ID \
  --billing-account=$BILLING_ACCOUNT

# 4. Enable APIs
gcloud services enable \
  sqladmin.googleapis.com \
  run.googleapis.com \
  secretmanager.googleapis.com \
  identitytoolkit.googleapis.com \
  artifactregistry.googleapis.com \
  compute.googleapis.com \
  --project=$PROJECT_ID

# 5. Run Terraform
cd infrastructure/terraform/environments/${ENV}
terraform workspace new ${SPONSOR}
terraform apply -var="sponsor=${SPONSOR}"
```

### Terraform Module Usage

```hcl
# infrastructure/terraform/environments/prod/main.tf
module "sponsor_project" {
  source = "../../modules/gcp-sponsor-project"

  sponsor     = var.sponsor
  environment = "prod"
  region      = "europe-west1"  # EU region for GDPR compliance

  # Database configuration
  db_tier     = "db-custom-2-8192"
  db_ha       = true

  # Networking
  vpc_cidr    = "10.${var.sponsor_id}.0.0/20"

  # Labels
  labels = {
    sponsor     = var.sponsor
    environment = "prod"
    managed-by  = "terraform"
  }
}
```

---

## Cross-Project Resources

Some resources are shared across sponsors:

### Artifact Registry (Optional)
- Can use shared registry with sponsor-specific repositories
- Or per-project registries for complete isolation

### Cloud Build
- Shared Cloud Build configuration in core repository
- Per-project service accounts for deployment

### Monitoring
- Optional: Cross-project monitoring dashboard for platform team
- Per-sponsor dashboards for sponsor-specific views

---

## Security Considerations

### Project Isolation

- No VPC peering between sponsor projects
- No shared service accounts
- No cross-project IAM bindings
- Separate encryption keys per project (optional CMEK)

### Data Residency (GDPR Compliance)

**All Clinical Trial Diary deployments use EU regions exclusively** for GDPR compliance and EU user data protection.

| Region | Location | Use Case |
| --- | --- | --- |
| `europe-west1` | Belgium | **Primary** - Default for all services |
| `europe-west4` | Netherlands | **Secondary** - HA failover, backup storage |
| `europe-west3` | Frankfurt | Alternative if German data residency required |

**Important**: US regions are NOT used for any production workloads containing EU user data.

### Compliance

Each production project includes:
- HIPAA BAA coverage (GCP organization-level)
- Audit logging enabled
- VPC Service Controls (optional, for sensitive data)
- Access Transparency logs

---

## References

- **Cloud SQL Setup**: docs/gcp/cloud-sql-setup.md
- **Cloud Run Deployment**: docs/gcp/cloud-run-deployment.md
- **Identity Platform**: docs/gcp/identity-platform-setup.md
- **Terraform Modules**: infrastructure/terraform/modules/
- **Migration Checklist**: docs/migration/supabase-to-gcp-migration-checklist.md

---

## Change Log

| Date | Version | Changes | Author |
| --- | --- | --- | --- |
| 2025-11-25 | 1.0 | Initial GCP project structure documentation | Claude |
