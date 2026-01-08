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
region              = "us-central1"
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
