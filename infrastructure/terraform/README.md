# Terraform Infrastructure

Infrastructure as Code (IaC) for the HHT Clinical Trial Diary Platform using Terraform.

**Implements Requirements:**
- REQ-o00056: IaC for portal deployment
- REQ-p00008: Multi-sponsor deployment model
- REQ-p00042: Infrastructure audit trail for FDA compliance

## Overview

This infrastructure supports a multi-sponsor clinical trial platform with strict FDA 21 CFR Part 11 compliance requirements. Each sponsor receives 4 isolated GCP projects (dev, qa, uat, prod) with comprehensive audit logging, VPC isolation, and environment-specific configurations.

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Terraform State (GCS)                              │
│              gs://cure-hht-terraform-state/{sponsor}/{env}/                  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────┐          ┌───────────────┐          ┌───────────────┐
│   Bootstrap   │          │   Bootstrap   │          │   Bootstrap   │
│  (Sponsor A)  │          │  (Sponsor B)  │          │  (Sponsor N)  │
│               │          │               │          │               │
│ Creates 4 GCP │          │ Creates 4 GCP │          │ Creates 4 GCP │
│   projects    │          │   projects    │          │   projects    │
└───────┬───────┘          └───────┬───────┘          └───────┬───────┘
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                        Per-Environment Deployments                         │
├─────────────┬─────────────┬─────────────┬─────────────────────────────────┤
│     dev     │     qa      │     uat     │              prod               │
│             │             │             │                                 │
│ • Cloud Run │ • Cloud Run │ • Cloud Run │ • Cloud Run (scaled)           │
│ • Cloud SQL │ • Cloud SQL │ • Cloud SQL │ • Cloud SQL (HA, regional)     │
│ • VPC       │ • VPC       │ • VPC       │ • VPC                          │
│ • Audit     │ • Audit     │ • Audit     │ • Audit (LOCKED retention)     │
└─────────────┴─────────────┴─────────────┴─────────────────────────────────┘
```

## Directory Structure

```
infrastructure/terraform/
├── README.md                     # This file
├── .terraform-version            # Terraform version (1.7.0)
│
├── modules/                      # Reusable Terraform modules
│   ├── gcp-project/              # GCP project + API enablement
│   ├── billing-budget/           # Budget alerts
│   ├── audit-logs/               # FDA-compliant audit storage
│   ├── cicd-service-account/     # CI/CD SA + Workload Identity
│   ├── vpc-network/              # VPC, subnets, connectors
│   ├── cloud-sql/                # PostgreSQL 17 with pgaudit
│   ├── cloud-run/                # Cloud Run services
│   ├── storage-buckets/          # Backup storage
│   ├── monitoring-alerts/        # Uptime & metric alerts
│   ├── artifact-registry/        # Docker registry
│   ├── cloud-build/              # CI/CD triggers
│   └── workforce-identity/       # Sponsor SSO federation
│
├── bootstrap/                    # Creates 4 projects per sponsor
│   ├── main.tf                   # Module orchestration
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Output values
│   ├── providers.tf              # Provider configuration
│   ├── versions.tf               # Version constraints
│   └── sponsor-configs/          # Per-sponsor configurations
│       ├── callisto.tfvars
│       └── cure-hht.tfvars
│
├── sponsor-portal/               # Per-environment deployment
│   ├── main.tf                   # Module orchestration
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Output values
│   ├── providers.tf              # Provider configuration
│   ├── versions.tf               # Version constraints
│   └── sponsor-configs/          # Per-sponsor-env configurations
│       └── example-dev.tfvars
│
└── scripts/                      # Orchestration scripts
    ├── common.sh                 # Shared functions
    ├── bootstrap-sponsor.sh      # Bootstrap all 4 projects
    ├── deploy-environment.sh     # Deploy single environment
    └── verify-audit-compliance.sh # FDA compliance check
```

## One-Time Setup (Admin Project & State Bucket)

Before using Terraform, you must create a dedicated admin project and the state bucket. This is a **one-time manual setup** that cannot be managed by Terraform (chicken-and-egg problem).

### Why a Separate Admin Project?

- State bucket cannot be in a project that Terraform creates
- Isolates sensitive state files from sponsor workloads
- Single place for shared infrastructure
- Easier billing/cost tracking for platform overhead

### Step 1: Create Admin Project

```bash
# Set your organization ID
ORG_ID="666049061860"  # anspar.org

# Create the admin project
gcloud projects create cure-hht-admin \
  --organization=$ORG_ID \
  --name="Cure HHT Admin"

# Link to billing account
gcloud billing projects link cure-hht-admin \
  --billing-account=017213-A61D61-71522F
```

### Step 2: Enable Required APIs

```bash
gcloud services enable storage.googleapis.com \
  --project=cure-hht-admin
```

### Step 3: Create State Bucket

```bash
# Create bucket in europe-west9 (Paris) for GDPR compliance
gcloud storage buckets create gs://cure-hht-terraform-state \
  --project=cure-hht-admin \
  --location=europe-west9 \
  --uniform-bucket-level-access \
  --public-access-prevention

# Enable versioning for state recovery
gcloud storage buckets update gs://cure-hht-terraform-state \
  --versioning

# Verify bucket was created
gcloud storage buckets describe gs://cure-hht-terraform-state
```

### Step 4: Grant Access to Terraform Users

Users running Terraform need access to the state bucket:

```bash
# For a specific user
gcloud storage buckets add-iam-policy-binding gs://cure-hht-terraform-state \
  --member="user:YOUR_EMAIL@anspar.org" \
  --role="roles/storage.objectAdmin"

# Or for the org admins group
gcloud storage buckets add-iam-policy-binding gs://cure-hht-terraform-state \
  --member="group:gcp-organization-admins@anspar.org" \
  --role="roles/storage.objectAdmin"
```

### Verify Setup

```bash
# Should show the bucket with versioning enabled
gcloud storage buckets describe gs://cure-hht-terraform-state --format="table(name,versioning.enabled,location)"

# Should be able to list (will be empty initially)
gcloud storage ls gs://cure-hht-terraform-state/
```

---

## Prerequisites

### Required Tools

1. **Terraform 1.7.0+**
   ```bash
   # Using tfenv (recommended)
   tfenv install 1.7.0
   tfenv use 1.7.0

   # Or direct install
   brew install terraform
   ```

2. **Google Cloud SDK**
   ```bash
   brew install google-cloud-sdk
   gcloud auth login
   gcloud auth application-default login
   ```

3. **Doppler CLI** (secrets management)
   ```bash
   brew install dopplerhq/cli/doppler
   doppler login
   doppler setup  # Select appropriate project/config
   ```

4. **jq** (JSON processing)
   ```bash
   brew install jq
   ```

### Required Permissions

The user running Terraform needs these GCP roles at the organization level:

- `roles/resourcemanager.projectCreator` - Create projects
- `roles/billing.user` - Link billing accounts
- `roles/iam.workloadIdentityPoolAdmin` - Create WIF pools
- `roles/logging.admin` - Configure log sinks
- `roles/storage.admin` - Create audit buckets

For sponsor-portal deployments, you need project-level Owner or equivalent roles.

### Billing Accounts

Due to GCP project limits per billing account, we use multiple billing accounts:

| Sponsor  | Environment | Billing Account ID     |
|----------|-------------|------------------------|
| Cure HHT | prod        | `017213-A61D61-71522F` |
| Cure HHT | dev/qa/uat  | `01A48D-1B402E-18CB1A` |
| Callisto | prod        | `01754A-64465F-47FB84` |
| Callisto | dev/qa/uat  | `01EA1E-F12D75-125CEF` |

## State Management

Terraform state is stored in GCS with per-sponsor/environment isolation:

```
gs://cure-hht-terraform-state/
├── bootstrap/
│   ├── callisto/terraform.tfstate
│   └── cure-hht/terraform.tfstate
└── sponsor-portal/
    ├── callisto-dev/terraform.tfstate
    ├── callisto-qa/terraform.tfstate
    ├── callisto-uat/terraform.tfstate
    ├── callisto-prod/terraform.tfstate
    └── ...
```

**Benefits:**
- Sponsor isolation prevents cross-sponsor impacts
- Environment isolation protects production
- Enables concurrent operations across sponsors
- Clear FDA audit trail per deployment

## Quick Start

### 1. Bootstrap a New Sponsor

Creates 4 GCP projects with required APIs, billing, and audit infrastructure:

```bash
cd infrastructure/terraform/scripts

# Preview changes (dry run)
doppler run -- ./bootstrap-sponsor.sh callisto

# Apply changes
doppler run -- ./bootstrap-sponsor.sh callisto --apply
```

### 2. Deploy an Environment

Deploys Cloud Run, Cloud SQL, VPC, and monitoring for a single environment:

```bash
# Deploy dev environment
doppler run -- ./deploy-environment.sh callisto dev --apply

# Deploy production (requires confirmation)
doppler run -- ./deploy-environment.sh callisto prod --apply
```

### 3. Verify FDA Compliance

```bash
./verify-audit-compliance.sh callisto
```

## Onboarding a New Sponsor

### Step 1: Create Bootstrap Configuration

Create `bootstrap/sponsor-configs/{sponsor}.tfvars`:

```hcl
# Required
sponsor              = "new-sponsor"
sponsor_id           = 3  # Must be unique (1-254)
gcp_org_id           = "123456789012"
billing_account_prod = "XXXXXX-XXXXXX-XXXXXX"
billing_account_dev  = "YYYYYY-YYYYYY-YYYYYY"

# Optional
project_prefix       = "cure-hht"
region              = "europe-west9"
```

**Important:** `sponsor_id` must be unique across all sponsors. It's used for VPC CIDR allocation.

### Step 2: Run Bootstrap

```bash
doppler run -- ./bootstrap-sponsor.sh new-sponsor --apply
```

This creates:
- 4 GCP projects: `cure-hht-new-sponsor-{dev,qa,uat,prod}`
- Audit log buckets with 25-year retention
- CI/CD service account with Workload Identity Federation
- Budget alerts

### Step 3: Create Environment Configurations

Create `sponsor-portal/sponsor-configs/{sponsor}-{env}.tfvars` for each environment.

Start from the example:
```bash
cp sponsor-portal/sponsor-configs/example-dev.tfvars \
   sponsor-portal/sponsor-configs/new-sponsor-dev.tfvars
```

Edit to match sponsor needs:
```hcl
sponsor     = "new-sponsor"
sponsor_id  = 3  # Must match bootstrap
environment = "dev"
project_id  = "cure-hht-new-sponsor-dev"
gcp_org_id  = "123456789012"
# ... additional configuration
```

### Step 4: Deploy Each Environment

```bash
# Start with dev
doppler run -- ./deploy-environment.sh new-sponsor dev --apply

# Then qa, uat, and finally prod
doppler run -- ./deploy-environment.sh new-sponsor qa --apply
doppler run -- ./deploy-environment.sh new-sponsor uat --apply
doppler run -- ./deploy-environment.sh new-sponsor prod --apply
```

### Step 5: Verify Compliance

```bash
./verify-audit-compliance.sh new-sponsor
```

Expected output:
```
All environments are FDA 21 CFR Part 11 compliant!
  [x] All audit buckets exist
  [x] All buckets have 25-year retention
  [x] Production bucket retention is LOCKED
  [x] All log sinks are active
```

## Environment-Specific Configurations

| Setting                 | dev         | qa          | uat              | prod             |
|-------------------------|-------------|-------------|------------------|------------------|
| **Budget**              | $500        | $500        | $1,000           | $5,000           |
| **DB Tier**             | db-f1-micro | db-f1-micro | db-custom-1-3840 | db-custom-2-8192 |
| **DB Availability**     | ZONAL       | ZONAL       | ZONAL            | REGIONAL         |
| **DB Disk**             | 10 GB       | 10 GB       | 20 GB            | 100 GB           |
| **Backup Retention**    | 7 days      | 7 days      | 14 days          | 30 days          |
| **VPC Connector Min**   | 1           | 1           | 2                | 2                |
| **VPC Connector Max**   | 3           | 3           | 5                | 10               |
| **Deletion Protection** | No          | No          | No               | Yes              |
| **Audit Lock**          | No          | No          | No               | **Yes**          |

## VPC CIDR Allocation

VPC CIDRs are calculated from `sponsor_id` to guarantee no overlap:

```
Sponsor CIDR: 10.{sponsor_id}.0.0/16

Per-environment offsets:
  dev:  10.{sponsor_id}.0.0/18   (offset 0)
  qa:   10.{sponsor_id}.64.0/18  (offset 64)
  uat:  10.{sponsor_id}.128.0/18 (offset 128)
  prod: 10.{sponsor_id}.192.0/18 (offset 192)

Subnet allocation within environment:
  App:       /22 at offset+0
  DB:        /22 at offset+4
  Connector: /28 at offset+12
```

Example for `sponsor_id=1` (Callisto):
- dev VPC: `10.1.0.0/18`
- prod VPC: `10.1.192.0/18`

## FDA Compliance

### 21 CFR Part 11 Requirements

This infrastructure implements FDA 21 CFR Part 11 compliance:

1. **25-Year Audit Log Retention**
   - All Cloud Audit Logs routed to GCS buckets
   - Retention period: 25 years (788,400,000 seconds)
   - Storage lifecycle: Standard → Coldline (90d) → Archive (365d)

2. **Tamper Protection**
   - Production audit buckets have **locked retention policy**
   - Once locked, retention cannot be shortened or removed
   - Prevents deletion of audit records

3. **Comprehensive Logging**
   - Admin Activity logs (always enabled)
   - Data Access logs (configured)
   - BigQuery audit dataset for querying

### Audit Log Lock Strategy

| Environment | `lock_retention_policy` | Rationale                      |
|-------------|-------------------------|--------------------------------|
| dev         | `false`                 | Flexibility during development |
| qa          | `false`                 | Cleanup after testing          |
| uat         | `false`                 | Reset between UAT cycles       |
| **prod**    | **`true`**              | **FDA requirement**            |

**WARNING:** Once locked, retention policy cannot be unlocked. The 25-year retention becomes permanent.

## CI/CD Integration

### GitHub Actions Workload Identity

The bootstrap creates Workload Identity Federation for passwordless GitHub Actions authentication:

```yaml
# .github/workflows/deploy.yml
- id: auth
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$SPONSOR-github-pool/providers/github-provider
    service_account: $SPONSOR-cicd@$PROJECT_ID.iam.gserviceaccount.com

- name: Deploy to Cloud Run
  uses: google-github-actions/deploy-cloudrun@v2
  with:
    service: diary-server
    image: $REGION-docker.pkg.dev/$PROJECT_ID/$SPONSOR-$ENV-images/diary-server:$TAG
```

### Cloud Build Triggers

When `enable_cloud_build_triggers = true`, Cloud Build triggers are created for:

| Trigger       | Source Branch       | Builds                |
|---------------|---------------------|-----------------------|
| diary-server  | Matches environment | `diary-server` image  |
| portal-server | Matches environment | `portal-server` image |

Trigger branches:
- dev: `^dev$`
- qa: `^qa$`
- uat: `^uat$`
- prod: `^main$`

## Workforce Identity (SSO)

Enable sponsor employees to authenticate via their corporate IdP:

```hcl
# In sponsor-portal tfvars
workforce_identity_enabled        = true
workforce_identity_provider_type  = "oidc"  # or "saml"
workforce_identity_issuer_uri     = "https://login.microsoftonline.com/{tenant}/v2.0"
workforce_identity_client_id      = "your-app-client-id"
workforce_identity_client_secret  = "your-client-secret"  # Use Doppler!
workforce_identity_allowed_domain = "sponsor.com"
```

## Troubleshooting

### Common Issues

**"Error: Billing account not found"**
- Ensure you have `roles/billing.user` on the billing account
- Verify billing account ID format: `XXXXXX-XXXXXX-XXXXXX`

**"Error: Project already exists"**
- Project IDs are globally unique
- Use `terraform import` to adopt existing projects
- Or choose a different `project_prefix`

**"Error: Quota exceeded"**
- GCP has limits per billing account
- Use separate billing accounts for prod vs dev
- Request quota increase if needed

**"Lock state file"**
- Another process may be running
- Wait for other process to complete
- Use `terraform force-unlock` if truly stuck (dangerous)

### Verifying Deployment

```bash
# Check project exists
gcloud projects describe cure-hht-{sponsor}-{env}

# Check APIs enabled
gcloud services list --project=cure-hht-{sponsor}-{env}

# Check Cloud Run services
gcloud run services list --project=cure-hht-{sponsor}-{env}

# Check Cloud SQL
gcloud sql instances list --project=cure-hht-{sponsor}-{env}

# Check audit bucket
gcloud storage buckets describe gs://cure-hht-{sponsor}-{env}-audit-logs
```

### Destroying Infrastructure

**Non-production environments:**
```bash
doppler run -- ./deploy-environment.sh {sponsor} {env} --destroy
```

**Production:**
Production cannot be destroyed via scripts due to safety protections:
1. Deletion protection enabled on resources
2. Audit log retention is locked
3. Manual confirmation required

To destroy production (DANGEROUS):
1. Disable deletion protection via console
2. Run `terraform destroy` manually
3. Audit bucket will remain (retention locked)

## Script Reference

### scripts/common.sh

Shared functions and configuration used by all other scripts.

**Configuration:**
```bash
STATE_BUCKET="cure-hht-terraform-state"  # GCS bucket for Terraform state
DEFAULT_REGION="europe-west9"            # Paris (GDPR compliance)
```

**Functions:**

| Function | Description |
|----------|-------------|
| `log_info`, `log_warn`, `log_error` | Colored logging output |
| `log_step` | Log a major step with highlighting |
| `confirm_action` | Prompt for y/n confirmation |
| `require_command` | Check if a command exists, exit if not |
| `get_env_config` | Get environment-specific configuration (budget, DB tier, etc.) |
| `terraform_init` | Initialize Terraform with GCS backend |
| `terraform_plan` | Run `terraform plan` with tfvars file |
| `terraform_apply` | Run `terraform apply` with tfvars file |

**Environment Configurations:**
```bash
# Returned by get_env_config function
ENV_CONFIGS = {
  dev:  { budget: 500,  db_tier: "db-f1-micro",      ha: false }
  qa:   { budget: 500,  db_tier: "db-f1-micro",      ha: false }
  uat:  { budget: 1000, db_tier: "db-custom-1-3840", ha: false }
  prod: { budget: 5000, db_tier: "db-custom-2-8192", ha: true  }
}
```

---

### scripts/bootstrap-sponsor.sh

Creates all 4 GCP projects (dev, qa, uat, prod) for a new sponsor.

**Usage:**
```bash
doppler run -- ./bootstrap-sponsor.sh <sponsor> [--apply] [--destroy]
```

**Arguments:**
| Argument | Required | Description |
|----------|----------|-------------|
| `sponsor` | Yes | Sponsor name (must match tfvars filename) |
| `--apply` | No | Apply changes (default: plan only) |
| `--destroy` | No | Destroy all sponsor infrastructure (DANGEROUS) |

**Prerequisites:**
- Config file: `bootstrap/sponsor-configs/{sponsor}.tfvars`
- GCS state bucket: `gs://cure-hht-terraform-state/`
- Org-level IAM roles (see Prerequisites section)

**What It Creates:**
```
cure-hht-{sponsor}-dev    - Development project
cure-hht-{sponsor}-qa     - QA/testing project
cure-hht-{sponsor}-uat    - User acceptance testing project
cure-hht-{sponsor}-prod   - Production project

Per project:
  - 13 GCP APIs enabled
  - Budget alerts ($500/$500/$1000/$5000)
  - Audit log bucket (25-year retention)
  - Log sink (Cloud Audit Logs → GCS)
  - CI/CD service account
  - Workload Identity Federation pool (for GitHub Actions)
```

**Example:**
```bash
# Preview what will be created
doppler run -- ./bootstrap-sponsor.sh callisto

# Create all 4 projects
doppler run -- ./bootstrap-sponsor.sh callisto --apply

# Check state
gcloud storage cat gs://cure-hht-terraform-state/bootstrap/callisto/default.tfstate | jq '.resources | length'
```

**State Location:** `gs://cure-hht-terraform-state/bootstrap/{sponsor}/`

---

### scripts/deploy-environment.sh

Deploys portal infrastructure (Cloud Run, Cloud SQL, VPC, etc.) to a single environment.

**Usage:**
```bash
doppler run -- ./deploy-environment.sh <sponsor> <env> [--apply] [--destroy]
```

**Arguments:**
| Argument | Required | Description |
|----------|----------|-------------|
| `sponsor` | Yes | Sponsor name |
| `env` | Yes | Environment: `dev`, `qa`, `uat`, or `prod` |
| `--apply` | No | Apply changes (default: plan only) |
| `--destroy` | No | Destroy environment (blocked for prod) |

**Prerequisites:**
- Bootstrap must be completed for this sponsor
- Config file: `sponsor-portal/sponsor-configs/{sponsor}-{env}.tfvars`
- Database password in Doppler: `DB_PASSWORD_{SPONSOR}_{ENV}`

**What It Creates:**
```
VPC Network
  - App subnet (/22)
  - DB subnet (/22)
  - Serverless VPC connector

Cloud SQL (PostgreSQL 17)
  - Private IP (VPC-only access)
  - pgaudit enabled
  - Automated backups

Cloud Run Services
  - diary-server (API)
  - portal-server (Web UI)
  - VPC connector attached

Artifact Registry
  - Docker repository for container images

Monitoring
  - Uptime checks
  - Error rate alerts
  - DB CPU/storage alerts

Audit Logs
  - GCS bucket (25-year retention)
  - BigQuery dataset
  - Log sinks

Identity Platform (if enabled)
  - Email/password auth
  - MFA configuration
  - Session management
```

**Example:**
```bash
# Preview dev deployment
doppler run -- ./deploy-environment.sh callisto dev

# Deploy dev
doppler run -- ./deploy-environment.sh callisto dev --apply

# Deploy prod (extra confirmation required)
doppler run -- ./deploy-environment.sh callisto prod --apply

# Get outputs after deployment
cd sponsor-portal
terraform output -json
```

**State Location:** `gs://cure-hht-terraform-state/sponsor-portal/{sponsor}-{env}/`

---

### scripts/verify-audit-compliance.sh

Verifies FDA 21 CFR Part 11 compliance for all sponsor environments.

**Usage:**
```bash
./verify-audit-compliance.sh <sponsor>
```

**Arguments:**
| Argument | Required | Description |
|----------|----------|-------------|
| `sponsor` | Yes | Sponsor name to verify |

**Checks Performed:**

| Check | Requirement | Pass Criteria |
|-------|-------------|---------------|
| Bucket exists | All envs | All 4 audit buckets exist |
| Retention policy | All envs | 25-year (788,400,000 seconds) |
| Retention locked | Prod only | `isLocked: true` |
| Log sinks active | All envs | Sinks are not disabled |
| BigQuery dataset | All envs | Audit dataset exists |

**Example Output:**
```
Verifying FDA 21 CFR Part 11 compliance for: callisto
============================================================

Checking dev environment...
  ✅ Audit bucket exists: cure-hht-callisto-dev-audit-logs
  ✅ Retention policy: 25 years (788400000 seconds)
  ✅ Log sink active

Checking qa environment...
  ✅ Audit bucket exists: cure-hht-callisto-qa-audit-logs
  ✅ Retention policy: 25 years (788400000 seconds)
  ✅ Log sink active

Checking uat environment...
  ✅ Audit bucket exists: cure-hht-callisto-uat-audit-logs
  ✅ Retention policy: 25 years (788400000 seconds)
  ✅ Log sink active

Checking prod environment...
  ✅ Audit bucket exists: cure-hht-callisto-prod-audit-logs
  ✅ Retention policy: 25 years (788400000 seconds)
  ✅ Retention policy LOCKED (tamper-proof)
  ✅ Log sink active

============================================================
✅ All environments are FDA 21 CFR Part 11 compliant!
```

**Exit Codes:**
| Code | Meaning |
|------|---------|
| 0 | All checks passed |
| 1 | One or more checks failed |

---

## Module Reference

### gcp-project

Creates a GCP project with required APIs enabled.

| Input             | Type   | Description         |
|-------------------|--------|---------------------|
| `project_id`      | string | GCP project ID      |
| `project_prefix`  | string | Prefix for naming   |
| `sponsor`         | string | Sponsor name        |
| `environment`     | string | dev/qa/uat/prod     |
| `billing_account` | string | Billing account ID  |
| `gcp_org_id`      | string | GCP organization ID |

### cloud-sql

Creates PostgreSQL 17 instance with pgaudit enabled.

| Input            | Type   | Description                   |
|------------------|--------|-------------------------------|
| `project_id`     | string | GCP project ID                |
| `sponsor`        | string | Sponsor name                  |
| `environment`    | string | dev/qa/uat/prod               |
| `vpc_network_id` | string | VPC network ID                |
| `db_password`    | string | Database password (sensitive) |

### audit-logs

Creates FDA-compliant audit log storage.

| Input                   | Type   | Description                    |
|-------------------------|--------|--------------------------------|
| `project_id`            | string | GCP project ID                 |
| `sponsor`               | string | Sponsor name                   |
| `environment`           | string | dev/qa/uat/prod                |
| `retention_years`       | number | Retention period (default: 25) |
| `lock_retention_policy` | bool   | Lock retention (prod only)     |

### identity-platform

Creates HIPAA/GDPR-compliant authentication using Google Cloud Identity Platform (enterprise Firebase Auth with BAA).

| Input                        | Type         | Description                                    |
|------------------------------|--------------|------------------------------------------------|
| `project_id`                 | string       | GCP project ID                                 |
| `sponsor`                    | string       | Sponsor name                                   |
| `environment`                | string       | dev/qa/uat/prod                                |
| `enable_email_password`      | bool         | Enable email/password auth (default: true)     |
| `enable_email_link`          | bool         | Enable passwordless email links (default: false)|
| `enable_phone_auth`          | bool         | Enable phone number auth (default: false)      |
| `mfa_enforcement`            | string       | OFF, OPTIONAL, MANDATORY (prod forces MANDATORY)|
| `password_min_length`        | number       | Minimum password length (default: 12)          |
| `session_duration_minutes`   | number       | Session timeout (default: 60 for HIPAA)        |
| `authorized_domains`         | list(string) | Additional OAuth redirect domains              |
| `portal_url`                 | string       | Portal URL for email links                     |

**HIPAA Compliance Features:**
- MFA mandatory for production environments
- 12+ character password requirement
- 60-minute session timeout (configurable)
- Automatic audit logging to Cloud Audit Logs

### billing-budget

Creates budget alerts with optional auto-stop for non-production.

| Input                 | Type   | Description                              |
|-----------------------|--------|------------------------------------------|
| `project_id`          | string | GCP project ID                           |
| `sponsor`             | string | Sponsor name                             |
| `environment`         | string | dev/qa/uat/prod                          |
| `budget_amount`       | number | Monthly budget in USD                    |
| `enable_cost_control` | bool   | Enable Pub/Sub for auto-stop (non-prod)  |

**Cost Protection:**
- Budget alerts at 50%, 80%, 100% thresholds
- Forecasted overspend alerts
- Pub/Sub topic for automated response (non-prod only)
- See `tools/cost-control/` for auto-stop Cloud Function

### vpc-network

Creates VPC with private service connection for Cloud SQL.

| Input                       | Type   | Description                     |
|-----------------------------|--------|---------------------------------|
| `project_id`                | string | GCP project ID                  |
| `sponsor`                   | string | Sponsor name                    |
| `environment`               | string | dev/qa/uat/prod                 |
| `region`                    | string | GCP region                      |
| `app_subnet_cidr`           | string | CIDR for application subnet     |
| `db_subnet_cidr`            | string | CIDR for database subnet        |
| `connector_cidr`            | string | CIDR for serverless VPC connector|
| `connector_min_instances`   | number | Min VPC connector instances     |
| `connector_max_instances`   | number | Max VPC connector instances     |

### cloud-run

Deploys Cloud Run services with Dart-optimized health checks.

| Input                   | Type   | Description                          |
|-------------------------|--------|--------------------------------------|
| `project_id`            | string | GCP project ID                       |
| `sponsor`               | string | Sponsor name                         |
| `environment`           | string | dev/qa/uat/prod                      |
| `region`                | string | GCP region                           |
| `vpc_connector_id`      | string | VPC connector for private SQL access |
| `diary_server_image`    | string | Docker image for diary API           |
| `portal_server_image`   | string | Docker image for portal UI           |
| `min_instances`         | number | Minimum instances (default: 1)       |
| `max_instances`         | number | Maximum instances (default: 10)      |

**Dart Container Optimization:**
- Startup probe: 120s total tolerance (30s initial + 6×15s retries)
- Liveness probe: Conservative 30s intervals
- Prevents restart loops during JIT compilation

## Related Documentation

- [Spec: Multi-Sponsor Architecture](../../spec/dev-architecture-multi-sponsor.md)
- [Spec: Operations Security](../../spec/ops-security.md)
- [ADR: Infrastructure as Code](../../docs/adr/adr-infrastructure-as-code.md)
- [Pulumi (Legacy)](../pulumi/README.md)

## Support

For issues:
1. Check troubleshooting section above
2. Review Terraform output for specific errors
3. Check GCP Console for resource status
4. Create ticket in Linear with `infrastructure` label
