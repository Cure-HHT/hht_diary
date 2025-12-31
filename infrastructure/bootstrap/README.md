# Bootstrap Infrastructure

**IMPLEMENTS REQUIREMENTS:**

- REQ-o00056: Pulumi IaC for portal deployment
- REQ-p00008: Multi-sponsor deployment model
- REQ-p00042: Infrastructure audit trail for FDA compliance

This Pulumi project creates the foundational GCP infrastructure for onboarding new sponsors to the Clinical Trial Platform.

## What It Creates

For each new sponsor, this bootstrap creates:

| Resource          | Count           | Description                                                                                            |
|-------------------|-----------------|--------------------------------------------------------------------------------------------------------|
| GCP Projects      | 4               | `{prefix}-{sponsor}-dev`, `{prefix}-{sponsor}-qa`, `{prefix}-{sponsor}-uat`, `{prefix}-{sponsor}-prod` |
| APIs              | ~13 per project | Cloud Run, SQL, IAM, Monitoring, etc.                                                                  |
| Billing Budgets   | 4               | Per-environment budgets with alerts                                                                    |
| Service Account   | 1               | CI/CD service account for deployments                                                                  |
| IAM Bindings      | ~28             | Roles for CI/CD across all projects                                                                    |
| Workload Identity | 1 pool          | GitHub Actions OIDC (optional)                                                                         |
| Audit Log Buckets | 4               | 25-year retention for FDA compliance                                                                   |
| Audit Log Sinks   | 4               | Export Cloud Audit Logs to storage                                                                     |

## Prerequisites

1. **GCP Organization Admin** access
2. **Billing Account Admin** access
3. **Doppler CLI** installed and configured:

   ```bash
   # Install Doppler
   brew install dopplerhq/cli/doppler

   # Login to Doppler
   doppler login

   # Setup project (if not already configured)
   doppler setup
   ```

4. **Pulumi CLI** installed:

   ```bash
   curl -fsSL https://get.pulumi.com | sh
   ```

5. **GCP CLI** installed:

   ```bash
   brew install google-cloud-sdk
   ```

6. **Pulumi Backend** configured:

   ```bash
   pulumi login gs://pulumi-state-cure-hht
   ```

## Doppler Environment Variables

The bootstrap script requires certain environment variables from Doppler. Run the script with `doppler run --` to inject them.

### Required Variables

| Variable                             | Description                                 | Example             |
|--------------------------------------|---------------------------------------------|---------------------|
| GCP Authentication                   | One of the following methods                |                     |
| `GOOGLE_APPLICATION_CREDENTIALS`     | Path to service account key JSON            | `/path/to/key.json` |
| `CLOUDSDK_AUTH_ACCESS_TOKEN`         | GCP access token                            | `ya29.xxx...`       |
| (or) Application Default Credentials | Via `gcloud auth application-default login` |                     |

### Optional Variables

| Variable                   | Description                                                     | Example           |
|----------------------------|-----------------------------------------------------------------|-------------------|
| `PULUMI_CONFIG_PASSPHRASE` | Passphrase for Pulumi state encryption (secrets in GCS backend) | `your-passphrase` |
| `PULUMI_ACCESS_TOKEN`      | Pulumi Cloud token (if using Pulumi Cloud)                      | `pul-xxx...`      |
| `GCP_PROJECT`              | Default GCP project for gcloud                                  | `cure-hht-admin`  |

### Doppler Configuration

Add these to your Doppler project:

```bash
# In Doppler dashboard or CLI
doppler secrets set PULUMI_CONFIG_PASSPHRASE "your-secure-passphrase"
doppler secrets set GOOGLE_APPLICATION_CREDENTIALS "/path/to/service-account.json"
```

## Usage

### Onboard a New Sponsor

**Option 1: Use the bootstrap script (recommended)**

```bash
cd infrastructure/bootstrap/tool

# Copy and edit the example config
cp sponsor-config.example.json orion.json
# Edit orion.json with your sponsor details

# Run the bootstrap script with Doppler
doppler run -- ./bootstrap-sponsor-gcp-projects.sh orion.json
```

The script will:
1. Validate Doppler environment variables
2. Create 4 GCP projects (dev, qa, uat, prod)
3. Enable required APIs
4. Set up billing budgets
5. Create CI/CD service account
6. **Create audit log buckets with 25-year locked retention**
7. **Verify audit logs exist (rollback if not)**

**Option 2: Manual Pulumi commands**

```bash
cd infrastructure/bootstrap

# Install dependencies
npm install

# Run with Doppler
doppler run -- pulumi stack init orion

# Configure the stack
doppler run -- pulumi config set sponsor orion
doppler run -- pulumi config set gcp:orgId 123456789012
doppler run -- pulumi config set billingAccountId 012345-6789AB-CDEF01

# Optional: Configure GitHub Actions Workload Identity
doppler run -- pulumi config set githubOrg Cure-HHT
doppler run -- pulumi config set githubRepo hht_diary

# Preview changes
doppler run -- pulumi preview

# Create infrastructure
doppler run -- pulumi up

# Verify audit logs were created
for env in dev qa uat prod; do
  gcloud storage buckets describe gs://cure-hht-orion-${env}-audit-logs \
    --project=cure-hht-orion-${env} \
    --format="value(retentionPolicy.isLocked)"
done
```

### View Outputs

After deployment, view the created resources:

```bash
# All outputs
pulumi stack output --json

# Specific project IDs
pulumi stack output devProjectId
pulumi stack output prodProjectId

# CI/CD service account
pulumi stack output cicdServiceAccountEmail
```

## Configuration Options

| Config Key         | Required | Description                       | Example                 |
|--------------------|----------|-----------------------------------|-------------------------|
| `sponsor`          | Yes      | Sponsor name (lowercase)          | `orion`                 |
| `gcp:orgId`        | Yes      | GCP Organization ID               | `123456789012`          |
| `billingAccountId` | Yes      | GCP Billing Account ID            | `012345-6789AB-CDEF01`  |
| `projectPrefix`    | No       | Prefix for project IDs            | `cure-hht` (default)    |
| `defaultRegion`    | No       | Default GCP region                | `us-central1` (default) |
| `folderId`         | No       | GCP Folder to place projects      | `folders/123456`        |
| `githubOrg`        | No       | GitHub org for Workload Identity  | `Cure-HHT`              |
| `githubRepo`       | No       | GitHub repo for Workload Identity | `hht_diary`             |

## Project Structure

```
infrastructure/bootstrap/
├── README.md                        # This file
├── package.json                     # Node.js dependencies
├── tsconfig.json                    # TypeScript configuration
├── Pulumi.yaml                      # Pulumi project configuration
├── index.ts                         # Main entry point
├── src/
│   ├── config.ts                    # Configuration management
│   ├── projects.ts                  # GCP project creation
│   ├── billing.ts                   # Billing budgets and alerts
│   ├── org-iam.ts                   # IAM and service accounts
│   └── audit-logs.ts                # Audit log infrastructure (25-year retention)
└── tool/
    ├── bootstrap-sponsor-gcp-projects.sh  # Bootstrap script
    └── sponsor-config.example.json        # Example config file
```

## After Bootstrap

Once bootstrap is complete, configure the main infrastructure stacks:

```bash
cd ../sponsor-portal

# For each environment (dev, qa, uat, prod):
pulumi stack init orion-dev
pulumi config set gcp:project cure-hht-orion-dev
pulumi config set gcp:region us-central1
pulumi config set gcp:orgId 123456789012
pulumi config set sponsor orion
pulumi config set environment dev
pulumi config set domainName portal-orion-dev.cure-hht.org
pulumi config set --secret dbPassword <secure-password>

# Deploy
pulumi up
```

## Billing Budgets

Default budget amounts per environment:

| Environment | Monthly Budget | Alert Thresholds    |
|-------------|----------------|---------------------|
| dev         | $500           | 50%, 75%, 90%, 100% |
| qa          | $500           | 50%, 75%, 90%, 100% |
| uat         | $1,000         | 50%, 75%, 90%, 100% |
| prod        | $5,000         | 50%, 75%, 90%, 100% |

Alerts are sent to billing account admins by default.

## Workload Identity Federation

If `githubOrg` and `githubRepo` are configured, the bootstrap sets up Workload Identity Federation for GitHub Actions. This allows GitHub Actions to authenticate to GCP without storing service account keys.

GitHub Actions workflow configuration:

```yaml
jobs:
  deploy:
    permissions:
      contents: read
      id-token: write  # Required for Workload Identity

    steps:
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
```

## Troubleshooting

### Error: "Permission denied on organization"

Ensure you have Organization Admin role:

```bash
gcloud organizations get-iam-policy <org-id> \
  --filter="bindings.members:user:<your-email>"
```

### Error: "Billing account not found"

Verify billing account ID and permissions:

```bash
gcloud billing accounts list
```

### Error: "Project ID already exists"

Project IDs are globally unique. Either:

1. Delete the existing project
2. Use a different `projectPrefix`

### Error: "Audit log verification failed"

The bootstrap script verifies that audit log buckets were created with locked retention. If this fails:

1. **Check bucket exists**:
   ```bash
   gcloud storage buckets describe gs://{prefix}-{sponsor}-prod-audit-logs \
     --project={prefix}-{sponsor}-prod
   ```

2. **Check retention policy**:
   ```bash
   gcloud storage buckets describe gs://{prefix}-{sponsor}-prod-audit-logs \
     --format="json(retentionPolicy)"
   ```

3. **Check Pulumi logs**:
   ```bash
   pulumi stack select {sponsor}
   pulumi up --diff
   ```

4. **Common causes**:
   - Storage API not enabled (should be automatic)
   - Insufficient permissions for bucket creation
   - Region not available for storage

### Error: "Missing Doppler environment variables"

Ensure you're running with Doppler:

```bash
# Check Doppler is configured
doppler secrets

# Run with Doppler
doppler run -- ./bootstrap-sponsor-gcp-projects.sh config.json
```

If using ADC instead of service account:

```bash
gcloud auth application-default login
```

## Audit Log Infrastructure (FDA 21 CFR Part 11)

Bootstrap automatically creates tamper-evident audit log storage in each project for FDA compliance.

### What Gets Logged

Every GCP API call is captured with:

| Field            | Description                 | Example                                          |
|------------------|-----------------------------|--------------------------------------------------|
| Principal        | Who performed the action    | `user:admin@company.com`                         |
| Timestamp        | When the action occurred    | `2025-12-14T15:30:00Z`                           |
| Method           | What API was called         | `google.cloud.sql.v1.SqlInstancesService.Insert` |
| Source IP        | Where the request came from | `203.0.113.45`                                   |
| Resource         | What was affected           | `projects/cure-hht-orion-prod/instances/db`      |
| Request/Response | Full payloads               | (JSON)                                           |

### Audit Log Buckets

Each environment gets a dedicated audit bucket:

| Environment | Bucket Name                          | Retention         |
|-------------|--------------------------------------|-------------------|
| dev         | `{prefix}-{sponsor}-dev-audit-logs`  | 25 years (locked) |
| qa          | `{prefix}-{sponsor}-qa-audit-logs`   | 25 years (locked) |
| uat         | `{prefix}-{sponsor}-uat-audit-logs`  | 25 years (locked) |
| prod        | `{prefix}-{sponsor}-prod-audit-logs` | 25 years (locked) |

### Retention Policy

The retention policy is **locked**, meaning:

- Objects cannot be deleted until the 25-year retention period expires
- The retention policy cannot be shortened or removed
- The bucket cannot be deleted while it contains objects
- Even GCP Organization Admins cannot override this

### Cost Optimization

Logs automatically transition to cheaper storage:

| Age         | Storage Class | Cost              |
|-------------|---------------|-------------------|
| 0-90 days   | Standard      | ~$0.020/GB/month  |
| 90-365 days | Coldline      | ~$0.004/GB/month  |
| 1-25 years  | Archive       | ~$0.0012/GB/month |

### Verification

After deployment, verify audit infrastructure:

```bash
# Check bucket exists and has locked retention
gcloud storage buckets describe gs://{prefix}-{sponsor}-prod-audit-logs \
  --format="value(retentionPolicy)"

# Verify log sink is active
gcloud logging sinks list --project={prefix}-{sponsor}-prod

# Read recent audit logs
gcloud logging read 'logName:"cloudaudit.googleapis.com"' \
  --project={prefix}-{sponsor}-prod --limit=5
```

### Stack Outputs

Bootstrap exports audit-related outputs:

```bash
pulumi stack output auditLogRetentionYears    # 25
pulumi stack output auditLogRetentionLocked   # true
pulumi stack output devAuditLogBucket         # cure-hht-orion-dev-audit-logs
pulumi stack output prodAuditLogBucket        # cure-hht-orion-prod-audit-logs
```

## Anspar Admin Access

Anspar team members access sponsor projects using their `@anspar.org` Google accounts via a Google Group.

### Current Access Model

| Environment | Anspar Access  | Notes                              |
|-------------|----------------|------------------------------------|
| dev         | `roles/owner`  | Full access for development        |
| qa          | `roles/owner`  | Full access for testing            |
| uat         | `roles/viewer` | Read-only; break-glass for changes |
| prod        | `roles/viewer` | Read-only; break-glass for changes |

### Configuration

Set the `ansparAdminGroup` config to enable Anspar access:

```bash
pulumi config set ansparAdminGroup "devops@anspar.org"
```

### Break-Glass Access for UAT/Prod

For emergency access to UAT/Prod, two options are available:

#### Option 1: GCP Privileged Access Manager (PAM)

GCP's native just-in-time access solution with approval workflows.

| Feature                | Description                            |
|------------------------|----------------------------------------|
| Just-in-Time Access    | Temporary role grants that auto-expire |
| Approval Workflows     | Multi-level approvals (up to 2 levels) |
| Justification Required | Business reason required for access    |
| Audit Logging          | All grants logged to Cloud Audit Logs  |

**Cost**: Requires Security Command Center Premium (~$15,000/year minimum).

See: [Privileged Access Manager overview](https://cloud.google.com/iam/docs/pam-overview)

#### Option 2: Custom Break-Glass Group (Current)

A simpler, free approach using Google Groups:

1. Create a break-glass group (e.g., `breakglass-prod@anspar.org`)
2. Grant it elevated roles on prod/uat projects
3. Keep it empty normally
4. Add yourself temporarily when needed
5. Remove yourself after completing work

**Audit**: Cloud Audit Logs capture group membership changes (who was added, when, by whom).

**Cost**: Free (uses existing Google Workspace).

### Stack Outputs

After deployment, the following IAM-related outputs are available:

```bash
pulumi stack output ansparAdminGroup      # devops@anspar.org
pulumi stack output ansparAccessLevel     # owner (dev/qa), viewer (uat/prod)
```

## Security Considerations

- CI/CD service account has admin roles - protect GitHub repo access
- Workload Identity restricts to specific GitHub org/repo
- Production deployments should require approval in CI/CD pipeline
- Billing budgets alert but don't auto-disable (to prevent outages)
- **Audit logs have locked retention** - cannot be tampered with or deleted
- **Anspar prod/uat access is read-only** - use break-glass for emergencies

## References

- [Pulumi GCP Provider](https://www.pulumi.com/registry/packages/gcp/)
- [GCP Resource Hierarchy](https://cloud.google.com/resource-manager/docs/cloud-platform-resource-hierarchy)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [GCP Billing Budgets](https://cloud.google.com/billing/docs/how-to/budgets)
- [Cloud Audit Logs](https://cloud.google.com/logging/docs/audit)
- [Bucket Lock & Retention](https://cloud.google.com/storage/docs/bucket-lock)
- [FDA 21 CFR Part 11](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/part-11-electronic-records-electronic-signatures-scope-and-application)
