# Phase 1 Infrastructure Activation Guide

**Purpose**: Step-by-step instructions for activating Phase 1 infrastructure
**Audience**: Operations team, DevOps engineers
**Status**: Ready to use

---

## IMPLEMENTS REQUIREMENTS

- REQ-o00041: Infrastructure as Code for Cloud Resources
- REQ-o00042: Infrastructure Change Control
- REQ-o00001: Separate Supabase Projects Per Sponsor

---

## Overview

This guide explains how to activate each component of Phase 1 infrastructure. All components are fully implemented but remain dormant until explicitly activated.

**Why dormant?** This allows you to:
- Review and validate configurations before going live
- Activate components incrementally as needed
- Test integrations without affecting production
- Control costs (some services have usage-based pricing)

**Phase 1 Components**:
1. ✅ Infrastructure as Code (Terraform)
2. ✅ Deployment Automation (GitHub Actions)
3. ✅ Monitoring and Observability (Sentry, Better Uptime)
4. ✅ Artifact Management (S3 archival)

---

## Prerequisites

Before activating any infrastructure:

- [ ] Access to GitHub repository with admin rights
- [ ] Access to Doppler for secrets management
- [ ] AWS account with admin access (for S3 archival)
- [ ] Supabase account with organization admin rights
- [ ] Terraform Cloud account (or AWS for S3 backend)

---

## Component 1: Infrastructure as Code (Terraform)

### Status
- ✅ Terraform modules created
- ✅ Environment configurations ready (dev/staging/production)
- ⏸️ State backend commented out (local state until activated)
- ⏸️ Supabase projects not provisioned

### When to Activate
Activate when ready to provision Supabase projects for all environments.

### Activation Steps

#### Step 1: Choose State Backend

**Option A: Terraform Cloud (Recommended)**

1. Create Terraform Cloud account at https://app.terraform.io

2. Create organization: `clinical-diary`

3. Create workspaces:
   ```bash
   # Via Terraform Cloud UI:
   # - clinical-diary-dev
   # - clinical-diary-staging
   # - clinical-diary-production
   ```

4. Generate API token:
   - User Settings > Tokens > Create API token
   - Save token securely

5. Configure Terraform CLI:
   ```bash
   terraform login
   # Follow prompts to authenticate
   ```

**Option B: S3 Backend**

1. Create S3 bucket and DynamoDB table:
   ```bash
   # Run commands from infrastructure/terraform/backend.tf.example
   ```

#### Step 2: Activate State Backend

For each environment (dev, staging, production):

1. Edit `infrastructure/terraform/environments/{env}/main.tf`

2. Uncomment the backend configuration:
   ```hcl
   # For Terraform Cloud:
   terraform {
     cloud {
       organization = "clinical-diary"
       workspaces {
         name = "clinical-diary-{environment}"
       }
     }
   }

   # OR for S3:
   terraform {
     backend "s3" {
       bucket         = "clinical-diary-terraform-state"
       key            = "environments/{environment}/terraform.tfstate"
       region         = "us-west-1"
       encrypt        = true
       dynamodb_table = "terraform-state-lock"
     }
   }
   ```

#### Step 3: Configure Secrets

1. Get Supabase access token:
   - Go to https://app.supabase.com/account/tokens
   - Generate new token
   - Copy token

2. Get Supabase organization ID:
   - Go to https://app.supabase.com/account/organization
   - Copy organization ID

3. Store in Doppler:
   ```bash
   # Supabase credentials
   doppler secrets set SUPABASE_ACCESS_TOKEN="sbp_..." --project clinical-diary --config dev
   doppler secrets set SUPABASE_ORGANIZATION_ID="..." --project clinical-diary --config dev

   # Strong database password (16+ chars for production)
   doppler secrets set DATABASE_PASSWORD="..." --project clinical-diary --config dev

   # Repeat for staging and prod configs
   ```

#### Step 4: Initialize and Plan

For development environment:

```bash
cd infrastructure/terraform/environments/dev

# Copy example config
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with actual values
nano terraform.tfvars

# Initialize Terraform (will migrate state if needed)
doppler run -- terraform init

# Review planned changes
doppler run -- terraform plan

# Verify plan looks correct
```

#### Step 5: Apply

```bash
# Apply configuration
doppler run -- terraform apply

# Review output - save project URL and keys!

# Store keys in Doppler immediately
doppler secrets set SUPABASE_URL="$(terraform output -raw project_url)" --project clinical-diary --config dev
doppler secrets set SUPABASE_ANON_KEY="$(terraform output -raw anon_key)" --project clinical-diary --config dev
doppler secrets set SUPABASE_SERVICE_KEY="$(terraform output -raw service_role_key)" --project clinical-diary --config dev
```

#### Step 6: Repeat for Staging and Production

```bash
# Staging
cd infrastructure/terraform/environments/staging
# Repeat steps 4-5

# Production (requires more care)
cd infrastructure/terraform/environments/production
# Repeat steps 4-5
# Store production keys in separate Doppler config (prd)
```

### Validation

After activation:

- [ ] Verify all three Supabase projects created
- [ ] Verify state stored in Terraform Cloud or S3
- [ ] Verify keys stored in Doppler
- [ ] Test connection to each Supabase project
- [ ] Document project IDs in runbook

### Estimated Time
- Initial setup: 1 hour
- Per environment: 15 minutes

### Cost Impact
- Terraform Cloud: Free (up to 5 users)
- OR S3 state: ~$1/month
- Supabase:
  - Dev: $0 (free tier)
  - Staging: $25/month (Pro tier)
  - Production: $25/month (Pro tier)

**Total: ~$50-51/month**

---

## Component 2: Deployment Automation

### Status
- ✅ Workflows created (dev, staging, production, rollback)
- ⏸️ GitHub Environments not configured (workflows won't trigger)
- ⏸️ Approval gates not set up

### When to Activate
Activate after Terraform provisioning is complete and you're ready for automated deployments.

### Activation Steps

#### Step 1: Configure GitHub Environments

1. Go to repository **Settings** > **Environments**

2. Create **development** environment:
   - Name: `development`
   - Deployment branches: `main` branch only
   - No approval required
   - No wait timer

3. Create **staging** environment:
   - Name: `staging`
   - Deployment branches: `main` branch only
   - Required reviewers: Add QA Lead
   - Wait timer: 0 minutes

4. Create **production** environment:
   - Name: `production`
   - Deployment branches: `main` branch only
   - Required reviewers: Add Tech Lead + QA Lead (2 reviewers)
   - Wait timer: 0 minutes
   - Deployment protection rules:
     - Only allow deployments from `main` branch
     - Require approval before deployment

#### Step 2: Configure GitHub Secrets

Add secrets to repository:

```bash
# Doppler tokens for each environment
gh secret set DOPPLER_TOKEN_DEV --body "dp.st.dev.xxxx"
gh secret set DOPPLER_TOKEN_STAGING --body "dp.st.staging.xxxx"
gh secret set DOPPLER_TOKEN_PROD --body "dp.st.prod.xxxx"

# Supabase project IDs
gh secret set SUPABASE_PROJECT_ID_DEV --body "xxxx"
gh secret set SUPABASE_PROJECT_ID_STAGING --body "xxxx"
gh secret set SUPABASE_PROJECT_ID_PROD --body "xxxx"

# Supabase access token (for CLI)
gh secret set SUPABASE_ACCESS_TOKEN --body "sbp_xxxx"

# AWS credentials (for artifact archival)
gh secret set AWS_ACCESS_KEY_ID --body "AKIA..."
gh secret set AWS_SECRET_ACCESS_KEY --body "..."
```

#### Step 3: Test Development Deployment

1. Make a small change on a feature branch:
   ```bash
   git checkout -b test-deployment
   echo "# Test" >> README.md
   git add README.md
   git commit -m "Test deployment pipeline"
   git push -u origin test-deployment
   ```

2. Create pull request and merge to `main`

3. Watch workflow run:
   ```bash
   gh run watch
   ```

4. Verify deployment succeeded:
   - Check workflow logs
   - Test dev environment manually
   - Verify no errors in Sentry (if activated)

#### Step 4: Test Staging Deployment (Manual Trigger)

1. Trigger staging deployment:
   ```bash
   gh workflow run deploy-staging.yml \
     -f reason="Testing staging deployment pipeline"
   ```

2. Verify approval gate:
   - QA Lead receives notification
   - QA Lead approves deployment

3. Verify deployment succeeded

#### Step 5: Test Production Deployment (Manual Trigger + Approval)

**Do NOT test in actual production - use staging with production workflow**

1. Review production deployment workflow thoroughly

2. When ready for first production deployment:
   ```bash
   gh workflow run deploy-production.yml \
     -f version="v1.0.0" \
     -f reason="Initial production deployment"
   ```

3. Verify approval gates:
   - Tech Lead and QA Lead both approve
   - Deployment window check passes (Mon-Thu, 9 AM-3 PM EST)

4. Monitor deployment closely

### Validation

After activation:

- [ ] Development deploys automatically on merge to `main`
- [ ] Staging requires QA Lead approval
- [ ] Production requires 2 approvals
- [ ] Rollback workflow is available
- [ ] Smoke tests run after each deployment

### Estimated Time
- Environment setup: 30 minutes
- Testing: 1 hour

### Cost Impact
None (GitHub Actions included in plan)

---

## Component 3: Monitoring and Observability

### Status
- ✅ Sentry integration code ready
- ✅ Better Uptime setup guide ready
- ⏸️ Sentry projects not created
- ⏸️ Better Uptime monitors not configured

### When to Activate
Activate before production deployment. Can activate dev/staging earlier for testing.

### Activation Steps

#### Step 1: Set Up Sentry

Follow `ops-monitoring-sentry.md` in detail. Summary:

1. Create Sentry account and organization: `clinical-diary`

2. Create projects:
   - `clinical-diary-dev`
   - `clinical-diary-staging`
   - `clinical-diary-prod`

3. Get DSN keys and store in Doppler:
   ```bash
   doppler secrets set SENTRY_DSN="https://xxx@sentry.io/..." --project clinical-diary --config dev
   # Repeat for staging and prod
   ```

4. Add Sentry SDK to application (already in code, just needs DSN)

5. Test error capture:
   - Trigger test error in dev
   - Verify appears in Sentry dashboard

6. Configure alerts:
   - Email to ops-team@clinical-diary.com
   - Slack to #engineering-alerts
   - PagerDuty for production (optional)

#### Step 2: Set Up Better Uptime

Follow `ops-monitoring-better-uptime.md` in detail. Summary:

1. Create Better Uptime account (free tier)

2. Create monitors for each environment:
   - Dev API Health (every 5 minutes)
   - Staging API Health (every 2 minutes)
   - Production API Health (every 30 seconds)

3. Configure alerts:
   - Email to ops-team@clinical-diary.com
   - Slack to #production-alerts
   - SMS to on-call engineer (production only)

4. Create public status page:
   - Subdomain: clinical-diary.betteruptime.com
   - OR custom domain: status.clinical-diary.com (requires DNS)

5. Test monitoring:
   - Temporarily break health endpoint in dev
   - Verify alert received
   - Restore health endpoint
   - Verify recovery notification

#### Step 3: Set Up On-Call Schedule

1. In Better Uptime, create on-call schedule

2. Add team members with phone numbers

3. Configure escalation:
   - Primary on-call: Immediate alert
   - Secondary on-call: Alert after 10 minutes
   - Tech Lead: Alert after 20 minutes

### Validation

After activation:

- [ ] Errors captured in Sentry
- [ ] Health checks running in Better Uptime
- [ ] Alerts delivered to correct channels
- [ ] Status page accessible and showing correct status
- [ ] On-call rotation configured

### Estimated Time
- Sentry setup: 1 hour
- Better Uptime setup: 30 minutes
- Testing: 30 minutes

### Cost Impact
- Sentry: $26/month (Team plan)
- Better Uptime: $0 (free tier)

**Total: +$26/month**

---

## Component 4: Artifact Management

### Status
- ✅ S3 lifecycle policies defined
- ✅ Archival workflows created
- ⏸️ S3 buckets not created
- ⏸️ Workflows won't run (missing S3 buckets)

### When to Activate
Activate before first production deployment to ensure audit trail compliance from day one.

### Activation Steps

#### Step 1: Create AWS S3 Buckets

```bash
# Set AWS region
export AWS_REGION=us-west-1

# Create hot storage bucket
aws s3 mb s3://clinical-diary-artifacts --region $AWS_REGION

# Create cold storage bucket
aws s3 mb s3://clinical-diary-archive-cold --region $AWS_REGION

# Enable versioning (hot storage)
aws s3api put-bucket-versioning \
  --bucket clinical-diary-artifacts \
  --versioning-configuration Status=Enabled

# Enable encryption (both buckets)
aws s3api put-bucket-encryption \
  --bucket clinical-diary-artifacts \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

aws s3api put-bucket-encryption \
  --bucket clinical-diary-archive-cold \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

#### Step 2: Configure Lifecycle Policies

```bash
# Create lifecycle policy files (see spec/ops-artifact-management.md)

# Apply to hot storage
aws s3api put-bucket-lifecycle-configuration \
  --bucket clinical-diary-artifacts \
  --lifecycle-configuration file://lifecycle-hot.json

# Apply to cold storage
aws s3api put-bucket-lifecycle-configuration \
  --bucket clinical-diary-archive-cold \
  --lifecycle-configuration file://lifecycle-cold.json
```

#### Step 3: Configure IAM User for GitHub Actions

```bash
# Create IAM user
aws iam create-user --user-name github-actions-clinical-diary

# Attach S3 access policy
aws iam attach-user-policy \
  --user-name github-actions-clinical-diary \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# Create access key
aws iam create-access-key --user-name github-actions-clinical-diary
# Save access key ID and secret access key!
```

#### Step 4: Add AWS Credentials to GitHub Secrets

```bash
gh secret set AWS_ACCESS_KEY_ID --body "AKIA..."
gh secret set AWS_SECRET_ACCESS_KEY --body "..."
```

#### Step 5: Test Archival Workflows

```bash
# Test build artifact archival (manual trigger)
gh workflow run archive-artifacts.yml

# Test deployment log archival (manual trigger with workflow ID)
gh workflow run archive-deployment-logs.yml \
  -f workflow_run_id="123456789"

# Test audit trail archival (manual trigger)
gh workflow run archive-audit-trail.yml

# Verify uploads
aws s3 ls s3://clinical-diary-artifacts/ --recursive
```

#### Step 6: Verify Lifecycle Transitions (Wait 90 Days)

After 90 days, verify artifacts transition to cold storage:

```bash
# Check storage class of old artifacts
aws s3api head-object \
  --bucket clinical-diary-artifacts \
  --key builds/artifacts-prod-20250127-120000.tar.gz \
  --query 'StorageClass'

# Should show "DEEP_ARCHIVE" after 90 days
```

### Validation

After activation:

- [ ] S3 buckets created with encryption
- [ ] Lifecycle policies active
- [ ] Archival workflows run successfully
- [ ] Artifacts uploaded to S3
- [ ] Checksums verified
- [ ] Monthly integrity check scheduled

### Estimated Time
- S3 setup: 30 minutes
- IAM configuration: 15 minutes
- Testing: 30 minutes

### Cost Impact
- S3 hot storage: ~$5/month
- S3 cold storage: ~$1/month (grows over time)
- Total: ~$6-9/month (scales with artifact size)

---

## Activation Checklist

Use this checklist to track activation progress:

### Infrastructure as Code
- [ ] Terraform Cloud or S3 backend configured
- [ ] Doppler secrets configured (all environments)
- [ ] Dev environment provisioned
- [ ] Staging environment provisioned
- [ ] Production environment provisioned
- [ ] Connection to all environments verified

### Deployment Automation
- [ ] GitHub Environments created (dev/staging/production)
- [ ] Approval gates configured
- [ ] GitHub Secrets added
- [ ] Development deployment tested
- [ ] Staging deployment tested
- [ ] Production deployment workflow reviewed (not tested in prod)

### Monitoring and Observability
- [ ] Sentry account created
- [ ] Sentry projects created (dev/staging/prod)
- [ ] Sentry DSNs stored in Doppler
- [ ] Sentry SDK integrated and tested
- [ ] Better Uptime account created
- [ ] Monitors configured (all environments)
- [ ] Status page published
- [ ] Alerts configured and tested
- [ ] On-call schedule created

### Artifact Management
- [ ] AWS account access verified
- [ ] S3 buckets created
- [ ] Lifecycle policies configured
- [ ] IAM user created for GitHub Actions
- [ ] AWS credentials added to GitHub Secrets
- [ ] Archival workflows tested
- [ ] Monthly integrity check verified

---

## Rollback Procedures

If you need to deactivate a component:

### Terraform
- Run `terraform destroy` in each environment
- Remove state backend configuration
- Delete Terraform Cloud workspaces or S3 bucket

### Deployment Automation
- Delete GitHub Environments
- Disable workflows (rename .yml to .yml.disabled)
- Remove GitHub Secrets

### Monitoring
- Delete Sentry projects (exports data first)
- Delete Better Uptime monitors
- Remove status page

### Artifact Management
- Download all artifacts from S3 (if needed)
- Delete S3 buckets
- Delete IAM user
- Disable archival workflows

---

## Cost Summary

| Component | Monthly Cost | Notes |
| --- | --- | --- |
| **Terraform State** | $0-1 | Free (Terraform Cloud) or $1 (S3) |
| **Supabase** | $50 | $0 dev + $25 staging + $25 prod |
| **GitHub Actions** | $0 | Included in plan |
| **Sentry** | $26 | Team plan (50K errors/month) |
| **Better Uptime** | $0 | Free tier (sufficient) |
| **S3 Archival** | $9 | ~$6 hot + ~$3 cold (grows slowly) |
| **Total** | **~$85-86/month** | Scales slightly with usage |

---

## Support and Troubleshooting

### Common Issues

**Terraform apply fails with "Organization not found"**
- Verify Terraform Cloud organization name matches
- Ensure you're logged in: `terraform login`

**Deployment workflow fails with "Environment not found"**
- Create GitHub Environment first
- Check environment name matches workflow exactly

**Sentry not capturing errors**
- Verify DSN is correct in Doppler
- Check Sentry SDK initialized before app code
- Test connectivity: `curl https://sentry.io/api/`

**S3 upload fails with "Access Denied"**
- Verify IAM user has S3 access policy
- Check AWS credentials in GitHub Secrets
- Verify bucket name is correct

### Getting Help

- **Documentation**: All specs in `spec/ops-*.md`
- **Integration Guides**: `ops-monitoring-sentry.md`, `ops-monitoring-better-uptime.md`
- **Runbook**: `ops-incident-response-runbook.md`
- **Issues**: Create GitHub issue with `[infrastructure]` tag

---

## Next Steps

After Phase 1 activation:

1. **Validate Everything**:
   - Run through validation procedures in each spec document
   - Document validation results
   - Address any issues found

2. **Monitor for 1 Week**:
   - Watch for errors in Sentry
   - Monitor uptime in Better Uptime
   - Review deployment logs
   - Verify archival working correctly

3. **Document Lessons Learned**:
   - What went well?
   - What could be improved?
   - Update this guide with findings

4. **Plan Phase 2** (Future):
   - Advanced monitoring (Prometheus/Grafana)
   - Automated scaling
   - Multi-region deployment
   - Disaster recovery automation

---

## Change History

| Date | Version | Author | Changes |
| --- | --- | --- | --- |
| 2025-01-27 | 1.0 | Claude | Initial activation guide for Phase 1 |
