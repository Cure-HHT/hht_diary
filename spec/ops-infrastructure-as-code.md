# Infrastructure as Code Specification

**Audience**: Operations
**Status**: Active
**Version**: 1.0.0
**Last Updated**: 2025-10-27

---

## Purpose

This document specifies the infrastructure as code (IaC) approach for the Clinical Diary project, ensuring reproducible, validated, and auditable infrastructure deployments that comply with FDA 21 CFR Part 11 requirements.

---

## Requirements

# REQ-o00041: Infrastructure as Code for Cloud Resources

**Level**: Ops | **Implements**: p00010 | **Status**: Active

**SHALL** use Terraform for all Supabase infrastructure and cloud resources.

**Rationale**: Infrastructure as code provides reproducibility, validation capability, and audit trail required for FDA compliance.

**Acceptance Criteria**:
- All Supabase projects defined in Terraform
- All cloud storage defined in Terraform
- Terraform state stored in version-controlled backend
- Infrastructure changes validated with `terraform plan` before apply
- Separate configurations maintained for dev/staging/production environments

**Validation**:
- IQ: Verify Terraform installs correctly and modules are accessible
- OQ: Verify `terraform plan` and `terraform apply` work correctly
- PQ: Verify infrastructure provisions in < 1 hour

*End* *Infrastructure as Code for Cloud Resources* | **Hash**: fa6aaa33
---

# REQ-o00042: Infrastructure Change Control

**Level**: Ops | **Implements**: o00041, p00010 | **Status**: Active

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
│   │   ├── supabase-project/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   ├── storage/
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
- **Terraform Cloud** (free tier) or **S3**: State backend
- **Supabase Terraform Provider**: Manage Supabase resources

**Providers**:
```hcl
terraform {
  required_version = ">= 1.6"

  required_providers {
    supabase = {
      source  = "supabase/supabase"
      version = "~> 1.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

---

## Infrastructure Components

### 1. Supabase Projects

**Per Environment**:
- Development: `clinical-diary-dev`
- Staging: `clinical-diary-staging`
- Production: `clinical-diary-prod`

**Configuration**:
```hcl
module "supabase" {
  source = "../../modules/supabase-project"

  project_name     = "clinical-diary-${var.environment}"
  organization_id  = var.supabase_org_id
  database_password = var.database_password  # From Doppler
  region           = "us-west-1"

  # Tier
  tier = var.environment == "production" ? "pro" : "free"

  # Backups
  enable_backups        = true
  backup_retention_days = var.environment == "production" ? 30 : 7

  tags = {
    Environment = var.environment
    Project     = "clinical-diary"
    ManagedBy   = "terraform"
  }
}
```

### 2. Storage (S3)

**Artifact Storage**:
```hcl
module "artifact_storage" {
  source = "../../modules/storage"

  bucket_name = "clinical-diary-artifacts-${var.environment}"

  # 7-year retention for compliance
  lifecycle_rules = [
    {
      id      = "archive-old-artifacts"
      enabled = true

      transition = [
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]

      expiration = {
        days = 2555  # 7 years
      }
    }
  ]

  versioning_enabled = true
  encryption_enabled = true
}
```

### 3. Monitoring Resources

**Optional** (if using Prometheus/Grafana):
```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  environment = var.environment

  # Sentry DSN from Doppler
  sentry_dsn = var.sentry_dsn

  # Better Uptime checks
  uptime_checks = [
    {
      name = "api-health"
      url  = "https://api.clinical-diary-${var.environment}.com/health"
      interval = 60  # seconds
    }
  ]
}
```

---

## State Management

### Backend Configuration

**Terraform Cloud** (Recommended):
```hcl
terraform {
  cloud {
    organization = "clinical-diary"

    workspaces {
      tags = ["clinical-diary", "dev"]
    }
  }
}
```

**S3 Backend** (Alternative):
```hcl
terraform {
  backend "s3" {
    bucket         = "clinical-diary-terraform-state"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-west-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### State Security

**MUST**:
- Encrypt state at rest
- Use locking (DynamoDB for S3, built-in for Terraform Cloud)
- Restrict access to state (IAM policies or Terraform Cloud permissions)
- Never commit state files to Git
- Backup state regularly

---

## Workflow

### Development Flow

1. **Make Infrastructure Changes**:
   ```bash
   cd infrastructure/terraform/environments/dev
   # Edit main.tf or terraform.tfvars
   ```

2. **Plan Changes**:
   ```bash
   terraform plan -out=tfplan
   # Review output carefully
   ```

3. **Create Pull Request**:
   ```bash
   git checkout -b infra/add-monitoring
   git add .
   git commit -m "[INFRA] Add monitoring resources"
   git push origin infra/add-monitoring
   gh pr create
   ```

4. **Automated CI Checks**:
   - `terraform fmt -check` (formatting)
   - `terraform validate` (syntax)
   - `terraform plan` (preview changes)
   - `tflint` (linting)

5. **Review & Approval**:
   - Reviewer examines `terraform plan` output
   - Reviewer verifies ticket reference
   - Reviewer approves PR

6. **Apply Changes**:
   ```bash
   # After merge to main
   terraform apply tfplan
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

**Daily Cron**:
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
        environment: [dev, staging, production]

    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init
        working-directory: infrastructure/terraform/environments/${{ matrix.environment }}

      - name: Terraform Plan
        id: plan
        run: terraform plan -detailed-exitcode
        working-directory: infrastructure/terraform/environments/${{ matrix.environment }}
        continue-on-error: true

      - name: Alert on Drift
        if: steps.plan.outputs.exitcode == 2
        run: |
          echo "Drift detected in ${{ matrix.environment }}!"
          # Send alert (Slack, email, etc.)
```

### Manual Drift Check

```bash
# Check for drift
cd infrastructure/terraform/environments/production
terraform plan -detailed-exitcode

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
- [ ] Required providers available
- [ ] Backend configured correctly
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

# Manually modify resource in console
# (e.g., change Supabase project name)

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

**USE** Doppler or Terraform Cloud variables:
```hcl
variable "database_password" {
  description = "Database password from Doppler"
  type        = string
  sensitive   = true
}

variable "supabase_service_token" {
  description = "Supabase service role token"
  type        = string
  sensitive   = true
}
```

**Retrieve from Doppler**:
```bash
doppler run -- terraform apply
```

### Access Control

**Terraform Cloud**:
- Use team-based permissions
- Development team: Read/write on dev workspace
- DevOps team: Read/write on staging/production
- Management: Read-only on all

**S3 Backend**:
- Use IAM policies to restrict state access
- Separate IAM roles for dev/staging/production
- Enable CloudTrail for audit logging

---

## Rollback Procedures

### Rollback Infrastructure Changes

**Using Terraform**:
```bash
# Revert to previous commit
git revert <commit-hash>

# Or check out previous state
git checkout <previous-commit> -- infrastructure/

# Apply reverted configuration
terraform plan
terraform apply
```

**Using Terraform State**:
```bash
# List state versions (Terraform Cloud)
terraform state list

# Pull specific version
terraform state pull > previous-state.json

# Push previous state (DANGEROUS - last resort)
terraform state push previous-state.json
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
- State changes logged

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

---

## Troubleshooting

### State Lock Issues

```bash
# Force unlock (DANGEROUS - use with caution)
terraform force-unlock <lock-id>

# Better: Wait for lock to release or investigate
terraform show
```

### Provider Authentication Failures

```bash
# Check provider credentials
echo $SUPABASE_ACCESS_TOKEN
echo $AWS_ACCESS_KEY_ID

# Re-authenticate
doppler run -- terraform init
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
- Review Terraform Cloud/S3 costs
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
- `INFRASTRUCTURE_GAP_ANALYSIS.md` - Original analysis

**External**:
- Terraform Documentation: https://www.terraform.io/docs
- Supabase Terraform Provider: https://registry.terraform.io/providers/supabase/supabase
- HashiCorp Best Practices: https://www.terraform.io/docs/cloud/guides/recommended-practices

---

**Approval Required**: DevOps Lead, QA Lead
**Validation Required**: IQ/OQ/PQ before production use
**Review Frequency**: Quarterly or when major changes needed
