# Infrastructure as Code Specification

**Audience**: Operations
**Status**: Draft
**Version**: 2.0.0
**Last Updated**: 2025-11-24

---

## Purpose

This document specifies the infrastructure as code (IaC) approach for the Clinical Diary project on Google Cloud Platform, ensuring reproducible, validated, and auditable infrastructure deployments that comply with FDA 21 CFR Part 11 requirements.

---

## Requirements

# REQ-o00041: Infrastructure as Code for Cloud Resources

**Level**: Ops | **Implements**: p00010 | **Status**: Draft

**SHALL** use Terraform for all GCP infrastructure and cloud resources.

**Rationale**: Infrastructure as code provides reproducibility, validation capability, and audit trail required for FDA compliance.

**Acceptance Criteria**:
- All GCP projects defined in Terraform
- All Cloud SQL instances defined in Terraform
- All Cloud Run services defined in Terraform
- Terraform state stored in version-controlled backend (GCS)
- Infrastructure changes validated with `terraform plan` before apply
- Separate configurations maintained for dev/staging/production environments
- Per-sponsor infrastructure isolated in separate GCP projects

**Validation**:
- IQ: Verify Terraform installs correctly and modules are accessible
- OQ: Verify `terraform plan` and `terraform apply` work correctly
- PQ: Verify infrastructure provisions in < 1 hour

*End* *Infrastructure as Code for Cloud Resources* | **Hash**: e42cc806
---

# REQ-o00042: Infrastructure Change Control

**Level**: Ops | **Implements**: o00041, p00010 | **Status**: Draft

**SHALL** require pull request review for all infrastructure changes.

**Rationale**: Change control is required for FDA compliance and prevents unauthorized infrastructure modifications.

**Acceptance Criteria**:
- All Terraform changes submitted via pull request
- Pull requests require 1 reviewer approval (2 for production)
- All infrastructure changes reference ticket/requirement
- Automated `terraform plan` runs on pull requests
- Drift detection runs daily

**Validation**:
- IQ: Verify PR process is documented
- OQ: Verify PR workflow prevents direct commits
- PQ: Verify 100% of infrastructure changes go through PR

*End* *Infrastructure Change Control* | **Hash**: 8b9ee3b1
---

## Architecture

### Directory Structure

```
infrastructure/
├── terraform/
│   ├── modules/
│   │   ├── gcp-project/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   ├── cloud-sql/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   ├── cloud-run/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   ├── identity-platform/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   ├── vpc-networking/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   ├── artifact-registry/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   └── monitoring/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── README.md
│   ├── environments/
│   │   ├── dev/
│   │   │   ├── main.tf
│   │   │   ├── terraform.tfvars
│   │   │   └── README.md
│   │   ├── staging/
│   │   │   ├── main.tf
│   │   │   ├── terraform.tfvars
│   │   │   └── README.md
│   │   └── production/
│   │       ├── main.tf
│   │       ├── terraform.tfvars
│   │       └── README.md
│   ├── sponsors/
│   │   ├── orion/
│   │   │   ├── staging/
│   │   │   │   └── main.tf
│   │   │   └── production/
│   │   │       └── main.tf
│   │   └── andromeda/
│   │       ├── staging/
│   │       │   └── main.tf
│   │       └── production/
│   │           └── main.tf
│   └── shared/
│       ├── backend.tf
│       └── variables.tf
├── docs/
│   ├── terraform-setup.md
│   ├── drift-detection.md
│   └── validation/
│       ├── IQ-terraform.md
│       ├── OQ-terraform.md
│       └── PQ-terraform.md
└── README.md
```

### Technology Stack

**Core Tools**:
- **Terraform** v1.6+: Infrastructure as code
- **Google Cloud Storage**: State backend
- **Google Cloud Provider**: Manage GCP resources

**Providers**:
```hcl
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}
```

---

## Infrastructure Components

### 1. GCP Projects (Per Sponsor)

Each sponsor gets a dedicated GCP project:

```hcl
module "sponsor_project" {
  source = "../../modules/gcp-project"

  project_id      = "clinical-diary-${var.sponsor}-${var.environment}"
  project_name    = "Clinical Diary ${title(var.sponsor)} ${title(var.environment)}"
  billing_account = var.billing_account_id
  org_id          = var.org_id  # Optional, for org-managed projects

  # Enable required APIs
  activate_apis = [
    "sqladmin.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "identitytoolkit.googleapis.com",
    "compute.googleapis.com",
    "vpcaccess.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudscheduler.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
  ]

  labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
    compliance  = "hipaa-fda"
  }
}
```

### 2. Cloud SQL Instance

```hcl
module "cloud_sql" {
  source = "../../modules/cloud-sql"

  project_id = module.sponsor_project.project_id
  region     = var.region

  instance_name = "${var.sponsor}-db"
  database_name = "clinical_diary"

  # Instance sizing based on environment
  tier = var.environment == "production" ? "db-custom-2-8192" : "db-custom-1-3840"

  # High availability for production
  availability_type = var.environment == "production" ? "REGIONAL" : "ZONAL"

  # Backup configuration
  backup_enabled                = true
  backup_start_time             = "02:00"
  point_in_time_recovery_enabled = true
  backup_retained_backups       = var.environment == "production" ? 30 : 7

  # Networking
  private_network = module.vpc.network_self_link
  require_ssl     = true

  # Database flags for audit
  database_flags = [
    {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    },
    {
      name  = "log_checkpoints"
      value = "on"
    },
    {
      name  = "log_connections"
      value = "on"
    },
    {
      name  = "log_disconnections"
      value = "on"
    }
  ]

  # Maintenance window
  maintenance_window_day  = 7  # Sunday
  maintenance_window_hour = 3  # 3 AM

  labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Database user (password from Doppler/Secret Manager)
resource "google_sql_user" "app_user" {
  project  = module.sponsor_project.project_id
  name     = "app_user"
  instance = module.cloud_sql.instance_name
  password = var.database_password  # From Doppler
}
```

### 3. Cloud Run Service

```hcl
module "cloud_run" {
  source = "../../modules/cloud-run"

  project_id = module.sponsor_project.project_id
  region     = var.region

  service_name = "clinical-diary-api"
  image        = "${var.region}-docker.pkg.dev/${module.sponsor_project.project_id}/clinical-diary/api:${var.image_tag}"

  # Service account
  service_account_email = google_service_account.cloud_run.email

  # VPC connector for Cloud SQL access
  vpc_connector = module.vpc.serverless_connector_id
  vpc_egress    = "private-ranges-only"

  # Cloud SQL connection
  cloudsql_instances = [module.cloud_sql.connection_name]

  # Environment variables
  env_vars = {
    ENVIRONMENT      = var.environment
    SPONSOR_ID       = var.sponsor
    GCP_PROJECT_ID   = module.sponsor_project.project_id
    DATABASE_INSTANCE = module.cloud_sql.connection_name
  }

  # Secrets from Secret Manager
  secrets = {
    DATABASE_URL = {
      secret_id = google_secret_manager_secret.database_url.secret_id
      version   = "latest"
    }
  }

  # Scaling
  min_instances = var.environment == "production" ? 1 : 0
  max_instances = var.environment == "production" ? 10 : 3

  # Resources
  cpu    = "1000m"
  memory = "512Mi"

  # Allow unauthenticated (API handles auth via Identity Platform)
  allow_unauthenticated = true

  labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
  }
}
```

### 4. VPC and Networking

```hcl
module "vpc" {
  source = "../../modules/vpc-networking"

  project_id = module.sponsor_project.project_id
  region     = var.region

  network_name = "clinical-diary-vpc"

  # Private Service Access for Cloud SQL
  enable_private_service_access = true

  # Serverless VPC Connector for Cloud Run
  connector_name      = "cloud-run-connector"
  connector_subnet    = "10.8.0.0/28"
  connector_min_instances = 2
  connector_max_instances = var.environment == "production" ? 10 : 3
}
```

### 5. Identity Platform

```hcl
module "identity_platform" {
  source = "../../modules/identity-platform"

  project_id = module.sponsor_project.project_id

  # Sign-in providers
  enable_email_password = true
  enable_google_oauth   = true
  enable_apple_oauth    = var.enable_apple_auth
  enable_microsoft_oauth = true

  # Password policy
  password_policy = {
    min_length            = 12
    require_uppercase     = true
    require_lowercase     = true
    require_numeric       = true
    require_special_char  = true
  }

  # MFA configuration
  mfa_enabled = var.environment == "production"

  # Authorized domains
  authorized_domains = [
    "clinical-diary-${var.sponsor}-${var.environment}.web.app",
    var.custom_domain
  ]
}
```

### 6. Artifact Registry

```hcl
module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id = module.sponsor_project.project_id
  region     = var.region

  repository_id = "clinical-diary"
  description   = "Container images for Clinical Diary ${var.sponsor}"
  format        = "DOCKER"

  # Cleanup policy
  cleanup_policies = [
    {
      id     = "keep-minimum-versions"
      action = "KEEP"
      most_recent_versions = {
        keep_count = 10
      }
    },
    {
      id     = "delete-old-images"
      action = "DELETE"
      condition = {
        older_than = "2592000s"  # 30 days
      }
    }
  ]

  # Vulnerability scanning
  enable_vulnerability_scanning = true

  labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
  }
}
```

### 7. Monitoring

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  project_id = module.sponsor_project.project_id

  # Uptime checks
  uptime_checks = [
    {
      display_name = "API Health"
      host         = module.cloud_run.service_url
      path         = "/health"
      period       = "60s"
      timeout      = "10s"
      regions      = ["usa-oregon", "usa-virginia", "europe-belgium"]
    }
  ]

  # Alert policies
  alert_policies = [
    {
      display_name = "High Error Rate"
      condition_type = "threshold"
      filter        = "resource.type=\"cloud_run_revision\" AND metric.type=\"logging.googleapis.com/log_entry_count\" AND metric.labels.severity=\"ERROR\""
      threshold     = 10
      duration      = "300s"
    },
    {
      display_name = "High API Latency"
      condition_type = "threshold"
      filter        = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\""
      threshold     = 2000
      duration      = "300s"
      aggregation   = "ALIGN_PERCENTILE_95"
    },
    {
      display_name = "Database High CPU"
      condition_type = "threshold"
      filter        = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
      threshold     = 0.8
      duration      = "300s"
    }
  ]

  # Notification channels
  notification_channels = var.notification_channels
}
```

---

## State Management

### Backend Configuration

**GCS Backend** (Recommended for GCP):
```hcl
terraform {
  backend "gcs" {
    bucket = "clinical-diary-terraform-state"
    prefix = "sponsors/${var.sponsor}/${var.environment}"
  }
}
```

### State Bucket Setup

```bash
# Create state bucket (one-time setup)
gsutil mb -l us-central1 -b on gs://clinical-diary-terraform-state

# Enable versioning for state recovery
gsutil versioning set on gs://clinical-diary-terraform-state

# Set lifecycle for old versions
cat > lifecycle.json << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"numNewerVersions": 10}
      }
    ]
  }
}
EOF
gsutil lifecycle set lifecycle.json gs://clinical-diary-terraform-state
```

### State Security

**MUST**:
- Encrypt state at rest (GCS default)
- Use object versioning for recovery
- Restrict access via IAM (bucket-level permissions)
- Never commit state files to Git
- Use state locking (GCS provides automatic locking)

---

## Workflow

### Development Flow

1. **Make Infrastructure Changes**:
   ```bash
   cd infrastructure/terraform/sponsors/${SPONSOR}/${ENV}
   # Edit main.tf or terraform.tfvars
   ```

2. **Plan Changes**:
   ```bash
   doppler run -- terraform plan -out=tfplan
   # Review output carefully
   ```

3. **Create Pull Request**:
   ```bash
   git checkout -b infra/add-monitoring
   git add .
   git commit -m "[INFRA] Add monitoring resources

   Implements: REQ-o00045"
   git push origin infra/add-monitoring
   gh pr create
   ```

4. **Automated CI Checks**:
   - `terraform fmt -check` (formatting)
   - `terraform validate` (syntax)
   - `terraform plan` (preview changes)
   - `tflint` (linting)
   - Security scanning

5. **Review & Approval**:
   - Reviewer examines `terraform plan` output
   - Reviewer verifies ticket reference
   - Reviewer approves PR

6. **Apply Changes**:
   ```bash
   # After merge to main
   doppler run -- terraform apply tfplan
   ```

### Production Deployment

**Additional Requirements**:
- 2 reviewer approvals (not 1)
- Change control ticket
- Scheduled maintenance window (if applicable)
- Rollback plan documented
- Post-deployment verification

---

## Drift Detection

### Automated Drift Detection

**GitHub Actions Workflow**:
```yaml
# .github/workflows/terraform-drift-detection.yml
name: Terraform Drift Detection

on:
  schedule:
    - cron: '0 9 * * *'  # 9 AM daily
  workflow_dispatch:

jobs:
  detect-drift:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        sponsor: [orion, andromeda]
        environment: [staging, production]

    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.WIF_PROVIDER }}
          service_account: ${{ vars.TERRAFORM_SA }}

      - name: Terraform Init
        run: terraform init
        working-directory: infrastructure/terraform/sponsors/${{ matrix.sponsor }}/${{ matrix.environment }}

      - name: Terraform Plan
        id: plan
        run: terraform plan -detailed-exitcode -no-color
        working-directory: infrastructure/terraform/sponsors/${{ matrix.sponsor }}/${{ matrix.environment }}
        continue-on-error: true

      - name: Alert on Drift
        if: steps.plan.outputs.exitcode == 2
        uses: slackapi/slack-github-action@v1
        with:
          channel-id: ${{ vars.SLACK_CHANNEL }}
          payload: |
            {
              "text": "Terraform drift detected in ${{ matrix.sponsor }}-${{ matrix.environment }}!"
            }
```

### Manual Drift Check

```bash
# Check for drift
cd infrastructure/terraform/sponsors/${SPONSOR}/${ENV}
doppler run -- terraform plan -detailed-exitcode

# Exit codes:
# 0 = no changes
# 1 = error
# 2 = changes detected (drift)
```

---

## Validation

### Installation Qualification (IQ)

**Verify**:
- [ ] Terraform v1.6+ installed
- [ ] Google Cloud provider available
- [ ] GCS backend configured correctly
- [ ] Modules are accessible
- [ ] Documentation complete

**Test**:
```bash
terraform version
terraform init
terraform validate
```

### Operational Qualification (OQ)

**Verify**:
- [ ] `terraform plan` works for all environments
- [ ] `terraform apply` provisions resources correctly
- [ ] State locking prevents concurrent modifications
- [ ] Drift detection identifies manual changes
- [ ] Rollback procedures work

**Test**:
```bash
# Create test resource
terraform apply

# Manually modify resource in GCP Console
# (e.g., change Cloud Run environment variable)

# Detect drift
terraform plan
# Should show difference

# Revert to desired state
terraform apply
```

### Performance Qualification (PQ)

**Metrics**:
- [ ] Infrastructure provisioning time < 1 hour
- [ ] `terraform plan` completes in < 5 minutes
- [ ] Drift detection runs daily without failures
- [ ] No unauthorized infrastructure changes in 30 days

---

## Security

### Secrets Management

**NEVER** store in Terraform:
- Database passwords
- API keys
- Service tokens

**USE** Doppler or GCP Secret Manager:
```hcl
variable "database_password" {
  description = "Database password from Doppler"
  type        = string
  sensitive   = true
}

# Reference Secret Manager secrets in Cloud Run
resource "google_secret_manager_secret" "db_password" {
  project   = var.project_id
  secret_id = "database-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.database_password
}
```

**Retrieve from Doppler**:
```bash
doppler run -- terraform apply
```

### Access Control

**IAM Roles for Terraform**:
```hcl
# Service account for Terraform
resource "google_service_account" "terraform" {
  account_id   = "terraform"
  display_name = "Terraform Service Account"
}

# Required roles
locals {
  terraform_roles = [
    "roles/cloudsql.admin",
    "roles/run.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/secretmanager.admin",
    "roles/compute.networkAdmin",
    "roles/artifactregistry.admin",
    "roles/monitoring.admin",
  ]
}

resource "google_project_iam_member" "terraform_roles" {
  for_each = toset(local.terraform_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform.email}"
}
```

**Workload Identity Federation** (for GitHub Actions):
```hcl
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}
```

---

## Rollback Procedures

### Rollback Infrastructure Changes

**Using Git**:
```bash
# Revert to previous commit
git revert <commit-hash>

# Apply reverted configuration
doppler run -- terraform plan
doppler run -- terraform apply
```

**Using Terraform State**:
```bash
# List state versions in GCS
gsutil ls -la gs://clinical-diary-terraform-state/sponsors/${SPONSOR}/${ENV}/

# Download previous state
gsutil cp gs://clinical-diary-terraform-state/sponsors/${SPONSOR}/${ENV}/default.tfstate#<version> ./previous-state.tfstate

# Import previous state (DANGEROUS - last resort)
terraform state push previous-state.tfstate
```

**Best Practice**: Use Git to revert infrastructure code, not state manipulation.

---

## Compliance & Audit

### Audit Trail

**Git History**:
- All infrastructure changes in Git
- Commit messages reference tickets
- Timestamps and authors tracked

**Terraform Logs**:
- `terraform plan` output saved in CI/CD
- `terraform apply` output saved
- State changes logged via GCS versioning

**Change Control**:
- Pull requests document changes
- Approvals documented in PR
- Merge commits provide audit trail

### Compliance Evidence

**For FDA Audit**:
1. Git history of infrastructure code
2. Pull request history (approvals)
3. Terraform plan/apply logs
4. Drift detection reports
5. Validation documentation (IQ/OQ/PQ)
6. GCS state version history

---

## Multi-Sponsor Management

### Adding a New Sponsor

1. **Create Sponsor Directory**:
   ```bash
   mkdir -p infrastructure/terraform/sponsors/${NEW_SPONSOR}/{staging,production}
   ```

2. **Create Configuration**:
   ```hcl
   # infrastructure/terraform/sponsors/${NEW_SPONSOR}/staging/main.tf
   module "clinical_diary" {
     source = "../../../modules/clinical-diary-stack"

     sponsor      = "new-sponsor"
     environment  = "staging"
     region       = "us-central1"

     # Sponsor-specific configuration
     billing_account_id = var.billing_account_id
     custom_domain      = "new-sponsor-staging.clinical-diary.com"
   }
   ```

3. **Initialize and Apply**:
   ```bash
   cd infrastructure/terraform/sponsors/${NEW_SPONSOR}/staging
   doppler run --config staging -- terraform init
   doppler run --config staging -- terraform plan
   doppler run --config staging -- terraform apply
   ```

### Sponsor Isolation

Each sponsor's infrastructure is completely isolated:
- Separate GCP project
- Separate Cloud SQL instance
- Separate Identity Platform tenant
- Separate VPC
- Separate Terraform state

---

## Troubleshooting

### State Lock Issues

```bash
# View lock info
gsutil stat gs://clinical-diary-terraform-state/sponsors/${SPONSOR}/${ENV}/default.tflock

# Force unlock (DANGEROUS - use with caution)
terraform force-unlock <lock-id>

# Better: Wait for lock to release or investigate
terraform show
```

### Provider Authentication Failures

```bash
# Check gcloud authentication
gcloud auth application-default print-access-token

# Re-authenticate
gcloud auth application-default login

# For CI/CD, verify Workload Identity
gcloud iam workload-identity-pools providers describe github-provider \
  --workload-identity-pool=github-pool \
  --location=global
```

### Drift Detected

```bash
# Review drift
terraform plan

# Options:
# 1. Accept drift (update code to match reality)
terraform refresh

# 2. Revert drift (apply desired state)
terraform apply
```

---

## Maintenance

### Regular Tasks

**Daily**:
- Automated drift detection runs
- Review drift reports

**Weekly**:
- Review GCP billing
- Review state file size

**Monthly**:
- Update Terraform version
- Update provider versions
- Review and archive old workspaces

**Quarterly**:
- Review access permissions
- Audit infrastructure changes
- Update validation documentation

---

## References

**Internal**:
- `infrastructure/README.md` - Getting started
- `docs/terraform-setup.md` - Detailed setup guide

**External**:
- [Terraform Documentation](https://www.terraform.io/docs)
- [Google Cloud Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCP Cloud SQL Terraform](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance)
- [GCP Cloud Run Terraform](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service)

---

## Change History

| Date | Version | Author | Changes |
| --- | --- | --- | --- |
| 2025-10-27 | 1.0.0 | Dev Team | Initial specification (Supabase) |
| 2025-11-24 | 2.0.0 | Claude | Migration to GCP (Cloud SQL, Cloud Run, IAM) |

---

**Approval Required**: DevOps Lead, QA Lead
**Validation Required**: IQ/OQ/PQ before production use
**Review Frequency**: Quarterly or when major changes needed
