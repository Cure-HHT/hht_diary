# Portal Cloud Infrastructure

**IMPLEMENTS REQUIREMENTS:**
- REQ-o00056: Pulumi IaC for portal deployment
- REQ-p00042: Infrastructure audit trail for FDA compliance

This directory contains Pulumi Infrastructure as Code (IaC) for deploying the Clinical Trial Web Portal to Google Cloud Platform.

## Overview

The portal infrastructure uses Pulumi with TypeScript to declaratively manage:
- VPC networking (private Cloud SQL connectivity)
- Cloud Run services (containerized Flutter web app)
- Artifact Registry (Docker images)
- Cloud SQL instances (PostgreSQL with RLS, pgaudit)
- Cloud Storage (backup buckets)
- Audit logs (25-year retention for FDA 21 CFR Part 11)
- Workforce Identity Federation (sponsor SSO integration via SAML/OIDC)
- Custom domain mappings (SSL certificates)
- IAM service accounts (least-privilege)
- Monitoring and alerting (uptime, errors, Cloud SQL CPU/storage)

## Multi-Environment Support

Each sponsor has 4 isolated environments deployed as separate Pulumi stacks:
- **dev** - Development environment
- **qa** - Quality assurance environment
- **uat** - User acceptance testing environment
- **prod** - Production environment

**Stack Naming**: `{sponsor}-{environment}` (e.g., `orion-prod`, `callisto-uat`)

## Prerequisites

1. **Pulumi CLI** installed:
   ```bash
   curl -fsSL https://get.pulumi.com | sh
   ```

2. **Node.js** (v20+):
   ```bash
   node --version  # Should be v20 or higher
   ```

3. **GCP Authentication**:
   ```bash
   gcloud auth application-default login
   ```

4. **Pulumi Backend** (GCS):
   ```bash
   pulumi login gs://pulumi-state-cure-hht
   ```

## Quick Start

### Initialize New Environment

```bash
# Navigate to portal-cloud directory
cd apps/portal-cloud

# Install dependencies
npm install

# Create new stack for sponsor environment
pulumi stack init orion-prod

# Configure stack
pulumi config set gcp:project cure-hht-orion-prod
pulumi config set gcp:region us-central1
pulumi config set sponsor orion
pulumi config set environment production
pulumi config set domainName portal-orion.cure-hht.org
pulumi config set --secret dbPassword <secure-password>

# Preview infrastructure
pulumi preview

# Deploy infrastructure
pulumi up
```

### Deploy to Existing Environment

```bash
# Select existing stack
pulumi stack select orion-prod

# Preview changes
pulumi preview --diff

# Deploy changes
pulumi up
```

## Stack Configuration

Each stack requires the following configuration:

| Config Key | Type | Description | Example |
| ---------- | ---- | ----------- | ------- |
| `gcp:project` | string | GCP project ID | `cure-hht-orion-prod` |
| `gcp:region` | string | GCP region | `us-central1` |
| `gcp:orgId` | string | GCP organization ID | `123456789012` |
| `sponsor` | string | Sponsor name | `orion` |
| `environment` | string | Environment (dev/qa/uat/prod) | `production` |
| `domainName` | string | Custom domain | `portal-orion.cure-hht.org` |
| `dbPassword` | secret | Cloud SQL password | (secret) |
| `sponsorRepoPath` | string | Path to sponsor repo | `../sponsor-orion` |
| `allowNonGdprRegion` | boolean | Allow non-EU regions (default: false) | `false` |

### Workforce Identity Federation (Optional)

Enable sponsor SSO integration by configuring Workforce Identity Federation:

| Config Key | Type | Description | Example |
| ---------- | ---- | ----------- | ------- |
| `workforceIdentityEnabled` | boolean | Enable Workforce Identity | `true` |
| `workforceIdentityProviderType` | string | Provider type | `oidc` or `saml` |
| `workforceIdentityIssuerUri` | string | IdP issuer URI | See examples below |
| `workforceIdentityClientId` | string | OAuth client ID | `abc123...` |
| `workforceIdentityClientSecret` | secret | OAuth client secret | (secret) |

**Example: Microsoft Entra ID (Azure AD)**:
```bash
pulumi config set workforceIdentityEnabled true
pulumi config set workforceIdentityProviderType oidc
pulumi config set workforceIdentityIssuerUri "https://login.microsoftonline.com/{tenant-id}/v2.0"
pulumi config set workforceIdentityClientId "{client-id}"
pulumi config set --secret workforceIdentityClientSecret "{client-secret}"
```

**Example: Okta**:
```bash
pulumi config set workforceIdentityEnabled true
pulumi config set workforceIdentityProviderType oidc
pulumi config set workforceIdentityIssuerUri "https://{okta-domain}.okta.com"
pulumi config set workforceIdentityClientId "{client-id}"
pulumi config set --secret workforceIdentityClientSecret "{client-secret}"
```

**Set configuration**:
```bash
pulumi config set <key> <value>
pulumi config set --secret <key> <secret-value>
```

## Stack Outputs

After deployment, Pulumi exports these outputs:

| Output | Description |
| ------ | ----------- |
| `portalUrl` | Portal URL (Cloud Run) |
| `customDomainUrl` | Custom domain URL |
| `dnsRecordRequired` | DNS CNAME record to add |
| `domainStatus` | Domain mapping status |
| `vpcNetworkName` | VPC network name |
| `vpcConnectorName` | VPC Access Connector name |
| `dbConnectionName` | Cloud SQL connection name |
| `dbPrivateIpAddress` | Cloud SQL private IP |
| `backupBucketName` | Backup storage bucket |
| `auditLogBucket` | Audit log bucket name |
| `auditLogBucketUrl` | Audit log bucket URL |
| `auditLogRetentionYears` | Audit log retention (25) |
| `auditLogDataset` | BigQuery dataset for audit queries |
| `imageTag` | Docker image tag deployed |
| `workforceIdentityEnabled` | Whether Workforce Identity is enabled |
| `workforcePoolId` | Workforce Identity Pool ID (if enabled) |
| `workforceProviderId` | Workforce Identity Provider ID (if enabled) |

**View outputs**:
```bash
pulumi stack output portalUrl
pulumi stack output auditLogBucketUrl  # Audit log location
pulumi stack output --json  # All outputs as JSON
```

## Infrastructure Components

### VPC Network
- **File**: `src/vpc.ts`
- **Resources**: VPC network, subnet, private service connection, VPC Access Connector
- **Purpose**: Secure private connectivity between Cloud Run and Cloud SQL
- **Features**: No public IP on Cloud SQL, all traffic stays within GCP

### Cloud Run Service
- **File**: `src/cloud-run.ts`
- **Resources**: Cloud Run service with auto-scaling
- **Configuration**: CPU, memory, min/max instances, VPC connector

### Docker Image
- **File**: `src/docker-image.ts`
- **Build**: Flutter web build → Docker image → Artifact Registry
- **Base Image**: nginx:alpine

### Cloud SQL
- **File**: `src/cloud-sql.ts`
- **Resources**: PostgreSQL 15 instance, databases, users
- **Features**:
  - Private IP via VPC (no public IP)
  - Point-in-time recovery, automated backups
  - pgaudit for FDA 21 CFR Part 11 audit logging
  - Connection/disconnection logging
  - Query insights for performance monitoring

### Cloud Storage
- **File**: `src/storage.ts`
- **Resources**: Backup bucket with lifecycle rules
- **Features**: Versioning, soft delete, automatic archival

### Audit Logs
- **File**: `src/audit-logs.ts`
- **Resources**: Audit log bucket (25-year locked retention), log sink, BigQuery dataset
- **Purpose**: FDA 21 CFR Part 11 compliant audit trail
- **Captures**: Who, what, when, where for all GCP API calls
- **Features**: Locked retention (cannot be shortened), cost-optimized storage tiers

### Domain Mapping
- **File**: `src/domain-mapping.ts`
- **Resources**: Custom domain mapping, SSL certificates
- **SSL**: Automatically provisioned by Google

### Monitoring
- **File**: `src/monitoring.ts`
- **Resources**: Uptime checks, alert policies
- **Alerts**: Error rate (>5%), Cloud SQL CPU (>80%), Cloud SQL storage (>80%)

### IAM
- **File**: `src/iam.ts`
- **Resources**: Service accounts, IAM bindings, API enablement
- **Principle**: Least-privilege access

### Workforce Identity Federation
- **File**: `src/workforce-identity.ts`
- **Resources**: Workforce Identity Pool, Workforce Identity Provider
- **Purpose**: Enables sponsor users to authenticate via their corporate IdP
- **Supported IdPs**: Microsoft Entra ID, Okta, Google Workspace, any SAML 2.0/OIDC provider
- **Benefits**: GDPR compliant, no separate user accounts needed, enterprise SSO integration

## GDPR Region Compliance

By default, deployments **require GDPR-compliant EU regions**. The following regions are allowed:

| Region | Location |
| ------ | -------- |
| `europe-west1` | Belgium |
| `europe-west3` | Frankfurt, Germany |
| `europe-west4` | Netherlands |
| `europe-west6` | Zurich, Switzerland |
| `europe-west8` | Milan, Italy |
| `europe-west9` | Paris, France |
| `europe-north1` | Finland |
| `europe-central2` | Warsaw, Poland |

To use a non-EU region (not recommended for EU user data):

```bash
pulumi config set allowNonGdprRegion true
```

## Audit Log Infrastructure (FDA 21 CFR Part 11)

Every deployment automatically creates tamper-evident audit log storage.

### What Gets Logged

| Field | Description | Example |
| ----- | ----------- | ------- |
| Principal | Who performed the action | `user:admin@company.com` |
| Timestamp | When it occurred | `2025-12-14T15:30:00Z` |
| Method | What API was called | `run.googleapis.com/Service.ReplaceService` |
| Source IP | Where the request came from | `203.0.113.45` |
| Resource | What was affected | `projects/cure-hht-orion-prod/services/portal` |
| Request/Response | Full payloads | (JSON) |

### Retention Policy

- **Duration**: 25 years (788,400,000 seconds)
- **Locked**: Yes - cannot be shortened or removed
- **Storage tiers**: Standard → Coldline (90d) → Archive (1y)

### Verification

```bash
# Check bucket retention is locked
gcloud storage buckets describe gs://{project}-audit-logs \
  --format="value(retentionPolicy)"

# Verify log sink is active
gcloud logging sinks list --project={project}

# Query audit logs in BigQuery
bq query --use_legacy_sql=false \
  'SELECT timestamp, protoPayload.authenticationInfo.principalEmail,
          protoPayload.methodName, protoPayload.resourceName
   FROM `{project}.audit_logs_{sponsor}_{env}.cloudaudit_googleapis_com_activity`
   ORDER BY timestamp DESC LIMIT 10'
```

## Rollback Procedures

### Full Infrastructure Rollback

```bash
# View deployment history
pulumi stack history

# Export previous state (e.g., version 4)
pulumi stack export --version 4 > previous-state.json

# Import previous state
pulumi stack import --file previous-state.json

# Apply rollback
pulumi up --yes
```

### Quick Container Rollback

```bash
# List Cloud Run revisions
gcloud run revisions list --service=portal --region=us-central1

# Route traffic to previous revision
gcloud run services update-traffic portal \
  --to-revisions=portal-00004-xyz=100 \
  --region=us-central1
```

## Drift Detection

Detect infrastructure changes made outside Pulumi:

```bash
# Preview to detect drift
pulumi preview --diff

# Refresh state to import manual changes
pulumi refresh

# Revert drift by applying Pulumi state
pulumi up
```

## CI/CD Integration

See `.github/workflows/deploy-portal.yml` for GitHub Actions integration.

**Key Steps**:
1. Checkout code
2. Install Pulumi CLI
3. Authenticate to GCP
4. Install dependencies (`npm install`)
5. Preview changes (`pulumi preview`)
6. Deploy (`pulumi up --yes`)

## Troubleshooting

### Error: "Stack not found"
```bash
# List all stacks
pulumi stack ls

# Create stack if missing
pulumi stack init <sponsor>-<env>
```

### Error: "Invalid credentials"
```bash
# Re-authenticate to GCP
gcloud auth application-default login

# Verify credentials
gcloud auth list
```

### Error: "State file locked"
```bash
# Cancel stuck update
pulumi cancel

# Force unlock (use with caution)
pulumi state unlock
```

### Error: "Resource already exists"
```bash
# Import existing resource
pulumi import gcp:cloudrun/service:Service portal projects/<project>/locations/<region>/services/portal
```

## File Structure

```
infrastructure/sponsor-portal/
├── README.md                 # This file
├── package.json              # Node.js dependencies
├── tsconfig.json             # TypeScript configuration
├── Pulumi.yaml               # Pulumi project configuration
├── index.ts                  # Main Pulumi program entry point
├── Dockerfile                # Container configuration
├── nginx.conf                # Nginx web server config
└── src/
    ├── config.ts             # Stack configuration (GDPR validation)
    ├── vpc.ts                # VPC network and connectivity
    ├── cloud-run.ts          # Cloud Run service
    ├── docker-image.ts       # Docker image build
    ├── cloud-sql.ts          # Cloud SQL (pgaudit, private IP)
    ├── storage.ts            # Backup buckets
    ├── audit-logs.ts         # Audit logs (25-year retention)
    ├── domain-mapping.ts     # Custom domain mapping
    ├── monitoring.ts         # Monitoring and alerting
    ├── iam.ts                # IAM and API enablement
    └── workforce-identity.ts # Workforce Identity Federation
```

## References

- **Pulumi Documentation**: https://www.pulumi.com/docs/
- **Pulumi GCP Provider**: https://www.pulumi.com/registry/packages/gcp/
- **Pulumi Docker Provider**: https://www.pulumi.com/registry/packages/docker/
- **Cloud Run Documentation**: https://cloud.google.com/run/docs
- **Cloud SQL Documentation**: https://cloud.google.com/sql/docs/postgres
- **Cloud Audit Logs**: https://cloud.google.com/logging/docs/audit
- **Bucket Lock & Retention**: https://cloud.google.com/storage/docs/bucket-lock
- **Workforce Identity Federation**: https://cloud.google.com/iam/docs/workforce-identity-federation
- **Configure with Microsoft Entra ID**: https://cloud.google.com/iam/docs/workforce-sign-in-microsoft-entra-id
- **GDPR and GCP**: https://cloud.google.com/privacy/gdpr
- **Deployment Guide**: `spec/ops-portal.md`

---

**Document Status**: Active implementation
**Owner**: DevOps Team / Platform Engineering
**Compliance**: FDA 21 CFR Part 11 compliant infrastructure audit trail
