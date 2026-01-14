# Pulumi to Terraform Conversion Plan

**Ticket**: CUR-648
**Status**: Ready for Implementation
**Implements**: REQ-o00056 (IaC for portal deployment), REQ-p00008 (Multi-sponsor deployment model)

## Executive Summary

Convert two Pulumi TypeScript projects to Terraform while maintaining FDA 21 CFR Part 11 compliance, fixing identified issues, and following GCP best practices.

---

## Current State Analysis

### Pulumi Projects to Convert

| Project        | Location                                | Purpose                            | Resources                  |
|----------------|-----------------------------------------|------------------------------------|----------------------------|
| Bootstrap      | `infrastructure/pulumi/bootstrap/`      | Creates 4 GCP projects per sponsor | ~110-120 resources/sponsor |
| Sponsor-Portal | `infrastructure/pulumi/sponsor-portal/` | Per-environment deployment         | ~43 resources/environment  |

### Issues to Fix During Conversion

1. **Billing Account**: Updated to use per-sponsor, per-environment billing accounts (see Billing Strategy below)
2. **Audit Log Lock**: Currently locks all environments; should ONLY lock **prod**
3. **VPC Connector**: Min instances hardcoded to 2 for all envs (wasteful for dev/qa)
4. **DB Password**: Exposed in env vars; recommend Cloud SQL Auth Proxy

---

## Billing Account Strategy

Due to GCP project-per-billing-account limits, we use **separate billing accounts per sponsor and environment tier**.

### Billing Accounts

| Billing Account    | Account ID               | Sponsors | Environments    |
|--------------------|--------------------------|----------|-----------------|
| Cure HHT           | `017213-A61D61-71522F`   | cure-hht | prod            |
| Cure HHT - Dev     | `01A48D-1B402E-18CB1A`   | cure-hht | dev, qa, uat    |
| Callisto           | `01754A-64465F-47FB84`   | callisto | prod            |
| Callisto - Dev     | `01EA1E-F12D75-125CEF`   | callisto | dev, qa, uat    |

### Billing Account Selection Logic

```hcl
# In bootstrap/main.tf
locals {
  billing_account = (
    var.environment == "prod"
    ? var.billing_account_prod
    : var.billing_account_dev
  )
}
```

### Adding New Sponsors

When onboarding a new sponsor:
1. Create two new GCP billing accounts: `{Sponsor}` and `{Sponsor} - Dev`
2. Add billing account IDs to sponsor tfvars file
3. Run bootstrap script

### Example Sponsor tfvars

```hcl
# bootstrap/sponsor-configs/callisto.tfvars
sponsor                = "callisto"
sponsor_id             = 1                        # Unique ID for VPC CIDR (10.1.0.0/16)
project_prefix         = "cure-hht"
default_region         = "us-central1"
github_org             = "Cure-HHT"
github_repo            = "hht_diary"
```

```hcl
# bootstrap/sponsor-configs/cure-hht.tfvars
sponsor                = "cure-hht"
sponsor_id             = 2                        # Unique ID for VPC CIDR (10.2.0.0/16)
project_prefix         = "cure-hht"
default_region         = "us-central1"
github_org             = "Cure-HHT"
github_repo            = "hht_diary"
```

---

## Proposed Directory Structure

```
infrastructure/terraform/
├── README.md                           # Overview and usage documentation
├── .terraform-version                  # tfenv version: 1.7.0
│
├── modules/                            # Reusable Terraform modules
│   ├── gcp-project/                    # GCP project + APIs
│   ├── billing-budget/                 # Budget with alerts
│   ├── audit-logs/                     # FDA-compliant audit storage
│   ├── cicd-service-account/           # CI/CD SA + Workload Identity
│   ├── vpc-network/                    # VPC, subnet, connectors
│   ├── cloud-sql/                      # PostgreSQL 17 with pgaudit
│   ├── cloud-run/                      # Cloud Run service
│   ├── storage-buckets/                # Backup storage
│   ├── monitoring-alerts/              # Uptime, error, CPU alerts
│   ├── workforce-identity/             # Optional SSO federation
│   ├── artifact-registry/              # Docker registry
│   └── cloud-build/                    # Cloud Build triggers for image builds
│
├── bootstrap/                          # Creates 4 projects per sponsor
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── sponsor-configs/                # Per-sponsor tfvars
│       ├── example.tfvars
│       └── {sponsor}.tfvars
│
├── sponsor-portal/                     # Per-environment deployment
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── sponsor-configs/                # Per-sponsor-env tfvars
│       ├── example-dev.tfvars
│       └── {sponsor}-{env}.tfvars
│
└── scripts/                            # Orchestration scripts
    ├── bootstrap-sponsor.sh            # Bootstrap all 4 projects
    ├── deploy-environment.sh           # Deploy single environment
    ├── verify-audit-compliance.sh      # FDA audit verification
    └── common.sh                       # Shared functions
```

---

## State Management Strategy

### GCS Backend with Per-Sponsor/Environment Isolation

```
gs://cure-hht-terraform-state/
├── bootstrap/
│   └── {sponsor}/terraform.tfstate
└── sponsor-portal/
    └── {sponsor}-{env}/terraform.tfstate
```

**Rationale**:
- Sponsor isolation prevents cross-sponsor impacts
- Environment isolation protects production
- Enables concurrent operations across sponsors
- Clear FDA audit trail per deployment

---

## Module Details

### Bootstrap Modules (Run Once Per Sponsor)

| Module                 | Resources Created                                                    |
|------------------------|----------------------------------------------------------------------|
| `gcp-project`          | 4x `google_project`, 52x `google_project_service` (13 APIs x 4 envs) |
| `billing-budget`       | 4x `google_billing_budget` ($500 dev/qa, $1000 uat, $5000 prod)      |
| `audit-logs`           | 4x audit buckets, 4x log sinks, IAM bindings                         |
| `cicd-service-account` | 1x SA, 28x IAM bindings, WIF pool + provider                         |

### Sponsor-Portal Modules (Run Per Environment)

| Module               | Resources Created                                            |
|----------------------|--------------------------------------------------------------|
| `vpc-network`        | VPC, subnet, private IP range, service connection, connector |
| `cloud-sql`          | PostgreSQL 17 instance, database, user (with pgaudit)        |
| `cloud-run`          | 2 services (diary-server, portal-server), IAM for access     |
| `storage-buckets`    | Backup bucket with lifecycle                                 |
| `audit-logs`         | Environment audit bucket, log sinks                          |
| `monitoring-alerts`  | Uptime check, error rate, DB CPU, DB storage alerts          |
| `artifact-registry`  | Docker repository                                            |
| `cloud-build`        | Build triggers for diary-server and portal-server images     |
| `workforce-identity` | (Optional) Workforce pool + OIDC/SAML provider               |

### Cloud Run Services

Two Cloud Run services are deployed per environment:

| Service          | Source                              | Purpose                                    |
|------------------|-------------------------------------|--------------------------------------------|
| `diary-server`   | `apps/containers/diary-server`      | Dart backend API server                    |
| `portal-server`  | `apps/containers/portal-server`     | Flutter web portal (to be created)         |

Both are built via **Cloud Build** and pushed to **Artifact Registry**, then deployed by Terraform.

---

## Critical: Audit Log Retention Lock Strategy

**FDA 21 CFR Part 11 requires 25-year retention with tamper protection.**

| Environment | `lock_retention_policy` | Rationale                                |
|-------------|-------------------------|------------------------------------------|
| dev         | `false`                 | Flexibility during development           |
| qa          | `false`                 | Cleanup after testing                    |
| uat         | `false`                 | Reset between UAT cycles                 |
| **prod**    | **`true`**              | **FDA requirement - CANNOT be unlocked** |

**WARNING**: Once a GCS retention policy is locked, it cannot be removed or shortened. The scripts will only set `lock_retention_policy=true` for prod.

---

## Environment-Specific Configurations

| Setting                 | dev              | qa               | uat              | prod             |
|-------------------------|------------------|------------------|------------------|------------------|
| **Billing Account**     | {sponsor}-Dev    | {sponsor}-Dev    | {sponsor}-Dev    | {sponsor}        |
| **Budget**              | $500             | $500             | $1,000           | $5,000           |
| **DB Tier**             | db-f1-micro      | db-f1-micro      | db-custom-1-3840 | db-custom-2-8192 |
| **DB HA**               | ZONAL            | ZONAL            | ZONAL            | REGIONAL         |
| **Disk Size**           | 10 GB            | 10 GB            | 20 GB            | 100 GB           |
| **Backup Retention**    | 7 days           | 7 days           | 14 days          | 30 days          |
| **VPC Connector Min**   | 1                | 1                | 2                | 2                |
| **VPC Connector Max**   | 3                | 3                | 5                | 10               |
| **Deletion Protection** | No               | No               | No               | Yes              |
| **Audit Lock**          | No               | No               | No               | **Yes**          |

---

## Naming Conventions (GCP Best Practices)

| Resource        | Pattern                         | Example                          |
|-----------------|---------------------------------|----------------------------------|
| Project ID      | `{prefix}-{sponsor}-{env}`      | `cure-hht-orion-prod`            |
| VPC             | `{sponsor}-{env}-vpc`           | `orion-prod-vpc`                 |
| Subnet          | `{sponsor}-{env}-subnet`        | `orion-prod-subnet`              |
| Cloud SQL       | `{sponsor}-{env}-db`            | `orion-prod-db`                  |
| Cloud Run       | `diary-server`, `portal-server` | `orion-prod-diary-server`        |
| Audit Bucket    | `{sponsor}-{env}-audit-logs`    | `cure-hht-orion-prod-audit-logs` |
| Service Account | `{sponsor}-cicd`                | `orion-cicd`                     |

---

## VPC Network Design

### Sponsor ID Mapping Strategy

Each sponsor is assigned a unique ID (1-254) that determines their entire network space.

**Rationale**:
- Guarantees no CIDR overlap (essential for EDC VPC peering)
- Scalable to 254 sponsors without conflict
- Predictable: given sponsor ID, entire network space is known
- Terraform-friendly: single variable drives all subnet calculations

### CIDR Allocation

```
10.{sponsor_id}.0.0/16 per sponsor

Environment allocation (/18 each):
  Dev:  10.{id}.0.0/18    (10.{id}.0.0   - 10.{id}.63.255)
  QA:   10.{id}.64.0/18   (10.{id}.64.0  - 10.{id}.127.255)
  UAT:  10.{id}.128.0/18  (10.{id}.128.0 - 10.{id}.191.255)
  Prod: 10.{id}.192.0/18  (10.{id}.192.0 - 10.{id}.255.255)

Subnet allocation within each /18:
  App/Cloud Run:     .0.0/22   (1024 IPs)
  Database:          .4.0/22   (1024 IPs)
  EDC Peering:       .8.0/22   (1024 IPs)
  VPC Connector:     .12.0/28  (16 IPs - required /28 for serverless)
  Reserved:          .12.16+   (future use)
```

### Example: Sponsor ID=1 (Callisto), Prod Environment

| Subnet       | CIDR             | Purpose                          |
|--------------|------------------|----------------------------------|
| VPC          | `10.1.192.0/18`  | Environment network space        |
| App          | `10.1.192.0/22`  | Cloud Run services               |
| Database     | `10.1.196.0/22`  | Cloud SQL private IP range       |
| EDC Peering  | `10.1.200.0/22`  | Reserved for sponsor EDC VPC     |
| VPC Connector| `10.1.204.0/28`  | Serverless VPC Access Connector  |

### Sponsor ID Registry

| Sponsor ID | Sponsor Name | VPC Range         |
|------------|--------------|-------------------|
| 1          | callisto     | `10.1.0.0/16`     |
| 2          | cure-hht     | `10.2.0.0/16`     |
| 3          | (reserved)   | `10.3.0.0/16`     |
| ...        | ...          | ...               |

**Note**: Sponsor IDs are configured in each sponsor's tfvars file and must be unique across all sponsors.

---

## Bash Scripts

### `bootstrap-sponsor.sh`

```bash
# Usage: doppler run -- ./bootstrap-sponsor.sh <sponsor> [--apply]
#
# Creates all 4 GCP projects for a sponsor:
# 1. Validates sponsor name and config file
# 2. Initializes Terraform with GCS backend
# 3. Plans/applies bootstrap resources
# 4. Verifies FDA audit log compliance
```

### `deploy-environment.sh`

```bash
# Usage: doppler run -- ./deploy-environment.sh <sponsor> <env> [--apply]
#
# Deploys single environment (dev/qa/uat/prod):
# 1. Initializes Terraform with environment-specific state
# 2. Plans/applies portal infrastructure
# 3. Outputs Cloud Run URL and connection details
```

### `verify-audit-compliance.sh`

```bash
# Usage: ./verify-audit-compliance.sh <sponsor>
#
# Verifies FDA 21 CFR Part 11 compliance:
# 1. Checks all 4 audit buckets exist
# 2. Validates 25-year retention policy
# 3. Confirms prod bucket is LOCKED
# 4. Reports any compliance gaps
```

---

## Deliverables

1. **Plan Document** (this file) - For human review
2. **Terraform Modules** - 11 reusable modules in `modules/`
3. **Bootstrap Configuration** - Root module + example tfvars
4. **Sponsor-Portal Configuration** - Root module + example tfvars
5. **Bash Scripts** - 4 orchestration scripts
6. **README.md** - Comprehensive documentation covering:
   - Deployment architecture overview
   - Terraform file purposes
   - How to use the IaC system
   - State management across sponsors/environments
   - New sponsor onboarding procedure
   - CI/CD integration guidance

---

## Implementation Order

### Phase 1: Foundation
1. Create directory structure
2. Set up GCS state bucket
3. Create `.terraform-version` file
4. Implement `common.sh` script functions

### Phase 2: Bootstrap Modules
1. `modules/gcp-project/` - GCP project creation
2. `modules/billing-budget/` - Budget alerts
3. `modules/audit-logs/` - FDA-compliant audit storage
4. `modules/cicd-service-account/` - CI/CD identity + WIF

### Phase 3: Bootstrap Root
1. `bootstrap/main.tf` - Orchestrate bootstrap modules
2. `bootstrap/variables.tf` - Input variables
3. `bootstrap/outputs.tf` - Expose project IDs, SA emails
4. `bootstrap/sponsor-configs/example.tfvars`
5. `scripts/bootstrap-sponsor.sh`

### Phase 4: Sponsor-Portal Modules
1. `modules/vpc-network/` - VPC with private SQL connectivity
2. `modules/cloud-sql/` - PostgreSQL with pgaudit
3. `modules/cloud-run/` - Cloud Run service
4. `modules/storage-buckets/` - Backup storage
5. `modules/monitoring-alerts/` - Observability
6. `modules/artifact-registry/` - Docker registry
7. `modules/workforce-identity/` - Optional SSO

### Phase 5: Sponsor-Portal Root
1. `sponsor-portal/main.tf` - Orchestrate portal modules
2. `sponsor-portal/variables.tf` - Input variables
3. `sponsor-portal/outputs.tf` - URLs, connection strings
4. `sponsor-portal/sponsor-configs/example-dev.tfvars`
5. `scripts/deploy-environment.sh`

### Phase 6: Compliance & Documentation
1. `scripts/verify-audit-compliance.sh`
2. `infrastructure/terraform/README.md`

---

## Verification Plan

### After Bootstrap
```bash
# Verify all 4 projects created
gcloud projects list --filter="labels.sponsor={sponsor}"

# Verify APIs enabled
gcloud services list --project=cure-hht-{sponsor}-prod

# Verify audit buckets
gcloud storage buckets describe gs://cure-hht-{sponsor}-prod-audit-logs

# Verify Workload Identity Federation
gcloud iam workload-identity-pools list --location=global --project=cure-hht-{sponsor}-dev
```

### After Sponsor-Portal Deploy
```bash
# Verify Cloud Run deployed
gcloud run services describe portal --region=us-central1 --project=cure-hht-{sponsor}-{env}

# Verify Cloud SQL
gcloud sql instances describe {sponsor}-{env}-db --project=cure-hht-{sponsor}-{env}

# Test portal health
curl https://{domain}/health
```

### FDA Audit Compliance
```bash
# Run verification script
./scripts/verify-audit-compliance.sh {sponsor}

# Should output:
# - All 4 buckets exist
# - All have 25-year retention
# - prod bucket is LOCKED
# - Log sinks are active
```

---

## Resolved Decisions

- **Docker image builds**: Use **Cloud Build** (not Terraform). Cloud Build is faster, easier, and more secure than building locally. Terraform will reference images from Artifact Registry but not build them.

- **Existing sponsors**: No existing Pulumi-deployed sponsors. No state migration required - this is a greenfield Terraform implementation.

- **VPC CIDR allocation**: Use **sponsor ID mapping** (`10.{sponsor_id}.0.0/16`). See VPC Network Design section above.

- **Identity Federation Strategy**: Two distinct federation types with different placement:

  | Federation Type                 | Location                 | Purpose                                                                                             |
  |---------------------------------|--------------------------|-----------------------------------------------------------------------------------------------------|
  | **Workload Identity** (CI/CD)   | Bootstrap (shared)       | GitHub Actions deploys to all envs via one pool; permissions controlled by per-env service accounts |
  | **Workforce Identity** (humans) | Sponsor-Portal (per-env) | Sponsor employees access portal via corporate SSO; different user sets per environment              |

  This allows:
  - Simple CI/CD setup (one WIF pool per sponsor)
  - Environment-isolated human access (dev users ≠ prod users)
  - Different IdP configurations per environment if needed

---

## Files to Create

```
infrastructure/terraform/
├── README.md
├── .terraform-version
├── modules/
│   ├── gcp-project/{main,variables,outputs}.tf
│   ├── billing-budget/{main,variables,outputs}.tf
│   ├── audit-logs/{main,variables,outputs}.tf
│   ├── cicd-service-account/{main,variables,outputs}.tf
│   ├── vpc-network/{main,variables,outputs}.tf
│   ├── cloud-sql/{main,variables,outputs}.tf
│   ├── cloud-run/{main,variables,outputs}.tf
│   ├── storage-buckets/{main,variables,outputs}.tf
│   ├── monitoring-alerts/{main,variables,outputs}.tf
│   ├── artifact-registry/{main,variables,outputs}.tf
│   ├── cloud-build/{main,variables,outputs}.tf
│   └── workforce-identity/{main,variables,outputs}.tf
├── bootstrap/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── versions.tf
│   └── sponsor-configs/example.tfvars
├── sponsor-portal/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── versions.tf
│   └── sponsor-configs/example-dev.tfvars
└── scripts/
    ├── bootstrap-sponsor.sh
    ├── deploy-environment.sh
    ├── verify-audit-compliance.sh
    └── common.sh
```

**Total files**: ~48 Terraform/script files (12 modules x 3 files + 2 roots x 5 files + 4 scripts)

---

## Next Steps

After plan approval:
1. Create the directory structure
2. Implement modules in dependency order
3. Create bootstrap configuration and test with a new sponsor
4. Create sponsor-portal configuration and test deployment
5. Write comprehensive README documentation
6. Archive Pulumi code (move to `infrastructure/pulumi-archived/`)
