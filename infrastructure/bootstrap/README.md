# Bootstrap Infrastructure

**IMPLEMENTS REQUIREMENTS:**

- REQ-o00056: Pulumi IaC for portal deployment
- REQ-p00008: Multi-sponsor deployment model
- REQ-p00042: Infrastructure audit trail for FDA compliance

This Pulumi project creates the foundational GCP infrastructure for onboarding new sponsors to the Clinical Trial Platform.

## What It Creates

For each new sponsor, this bootstrap creates:

| Resource | Count | Description |
| -------- | ----- | ----------- |
| GCP Projects | 4 | `{sponsor}-dev`, `{sponsor}-qa`, `{sponsor}-uat`, `{sponsor}-prod` |
| APIs | ~13 per project | Cloud Run, SQL, IAM, Monitoring, etc. |
| Billing Budgets | 4 | Per-environment budgets with alerts |
| Service Account | 1 | CI/CD service account for deployments |
| IAM Bindings | ~28 | Roles for CI/CD across all projects |
| Workload Identity | 1 pool | GitHub Actions OIDC (optional) |

## Prerequisites

1. **GCP Organization Admin** access
2. **Billing Account Admin** access
3. **Pulumi CLI** installed:

   ```bash
   curl -fsSL https://get.pulumi.com | sh
   ```

4. **GCP CLI** authenticated:

   ```bash
   gcloud auth application-default login
   ```

5. **Pulumi Backend** configured:

   ```bash
   pulumi login gs://pulumi-state-cure-hht
   ```

## Usage

### Onboard a New Sponsor

**Option 1: Use the bootstrap script (recommended)**

```bash
cd infrastructure/bootstrap/tool

# Copy and edit the example config
cp sponsor-config.example.json orion.json
# Edit orion.json with your sponsor details

# Run the bootstrap script
./bootstrap-sponsor-gcp-projects.sh orion.json
```

**Option 2: Manual Pulumi commands**

```bash
cd infrastructure/bootstrap

# Install dependencies
npm install

# Create a new stack for the sponsor
pulumi stack init orion

# Configure the stack
pulumi config set sponsor orion
pulumi config set gcp:orgId 123456789012
pulumi config set billingAccountId 012345-6789AB-CDEF01

# Optional: Configure GitHub Actions Workload Identity
pulumi config set githubOrg Cure-HHT
pulumi config set githubRepo hht_diary

# Preview changes
pulumi preview

# Create infrastructure
pulumi up
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

| Config Key | Required | Description | Example |
| ---------- | -------- | ----------- | ------- |
| `sponsor` | Yes | Sponsor name (lowercase) | `orion` |
| `gcp:orgId` | Yes | GCP Organization ID | `123456789012` |
| `billingAccountId` | Yes | GCP Billing Account ID | `012345-6789AB-CDEF01` |
| `projectPrefix` | No | Prefix for project IDs | `cure-hht` (default) |
| `defaultRegion` | No | Default GCP region | `us-central1` (default) |
| `folderId` | No | GCP Folder to place projects | `folders/123456` |
| `githubOrg` | No | GitHub org for Workload Identity | `Cure-HHT` |
| `githubRepo` | No | GitHub repo for Workload Identity | `hht_diary` |

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
│   └── org-iam.ts                   # IAM and service accounts
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

| Environment | Monthly Budget | Alert Thresholds |
| ----------- | -------------- | ---------------- |
| dev | $500 | 50%, 75%, 90%, 100% |
| qa | $500 | 50%, 75%, 90%, 100% |
| uat | $1,000 | 50%, 75%, 90%, 100% |
| prod | $5,000 | 50%, 75%, 90%, 100% |

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

## Security Considerations

- CI/CD service account has admin roles - protect GitHub repo access
- Workload Identity restricts to specific GitHub org/repo
- Production deployments should require approval in CI/CD pipeline
- Billing budgets alert but don't auto-disable (to prevent outages)

## References

- [Pulumi GCP Provider](https://www.pulumi.com/registry/packages/gcp/)
- [GCP Resource Hierarchy](https://cloud.google.com/resource-manager/docs/cloud-platform-resource-hierarchy)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [GCP Billing Budgets](https://cloud.google.com/billing/docs/how-to/budgets)
