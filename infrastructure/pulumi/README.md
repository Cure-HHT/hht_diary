# Portal Cloud Infrastructure

**IMPLEMENTS REQUIREMENTS:**
- REQ-o00056: Pulumi IaC for portal deployment
- REQ-p00042: Infrastructure audit trail for FDA compliance

This directory contains Pulumi Infrastructure as Code (IaC) for deploying the Clinical Trial Web Portal to Google Cloud Platform.

## Overview

The portal infrastructure uses Pulumi with TypeScript to declaratively manage:
- Cloud Run services (containerized Flutter web app)
- Artifact Registry (Docker images)
- Cloud SQL instances (PostgreSQL with RLS)
- Identity Platform (Firebase Auth)
- Custom domain mappings (SSL certificates)
- IAM service accounts (least-privilege)
- Monitoring and alerting

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
|------------|------|-------------|---------|
| `gcp:project` | string | GCP project ID | `cure-hht-orion-prod` |
| `gcp:region` | string | GCP region | `us-central1` |
| `sponsor` | string | Sponsor name | `orion` |
| `environment` | string | Environment (dev/qa/uat/prod) | `production` |
| `domainName` | string | Custom domain | `portal-orion.cure-hht.org` |
| `dbPassword` | secret | Cloud SQL password | (secret) |
| `sponsorRepoPath` | string | Path to sponsor repo | `../sponsor-orion` |

**Set configuration**:
```bash
pulumi config set <key> <value>
pulumi config set --secret <key> <secret-value>
```

## Stack Outputs

After deployment, Pulumi exports these outputs:

| Output | Description |
|--------|-------------|
| `portalUrl` | Portal URL (Cloud Run) |
| `customDomainUrl` | Custom domain URL |
| `dnsRecordRequired` | DNS CNAME record to add |
| `domainStatus` | Domain mapping status |
| `dbConnectionName` | Cloud SQL connection name |
| `imageTag` | Docker image tag deployed |

**View outputs**:
```bash
pulumi stack output portalUrl
pulumi stack output --json  # All outputs as JSON
```

## Infrastructure Components

### Cloud Run Service
- **File**: `src/cloud-run.ts`
- **Resources**: Cloud Run service with auto-scaling
- **Configuration**: CPU, memory, min/max instances

### Docker Image
- **File**: `src/docker-image.ts`
- **Build**: Flutter web build → Docker image → Artifact Registry
- **Base Image**: nginx:alpine

### Cloud SQL
- **File**: `src/cloud-sql.ts`
- **Resources**: PostgreSQL instance, databases, users
- **Features**: Point-in-time recovery, automated backups

### Domain Mapping
- **File**: `src/domain-mapping.ts`
- **Resources**: Custom domain mapping, SSL certificates
- **SSL**: Automatically provisioned by Google

### Monitoring
- **File**: `src/monitoring.ts`
- **Resources**: Uptime checks, alert policies
- **Alerts**: Error rate, latency, downtime

### IAM
- **File**: `src/iam.ts`
- **Resources**: Service accounts, IAM bindings
- **Principle**: Least-privilege access

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
apps/portal-cloud/
├── README.md                 # This file
├── package.json              # Node.js dependencies
├── tsconfig.json             # TypeScript configuration
├── Pulumi.yaml               # Pulumi project configuration
├── index.ts                  # Main Pulumi program entry point
├── Dockerfile                # Container configuration
├── nginx.conf                # Nginx web server config
└── src/
    ├── config.ts             # Stack configuration management
    ├── cloud-run.ts          # Cloud Run service
    ├── docker-image.ts       # Docker image build
    ├── cloud-sql.ts          # Cloud SQL instance
    ├── domain-mapping.ts     # Custom domain mapping
    ├── monitoring.ts         # Monitoring and alerting
    └── iam.ts                # IAM service accounts
```

## References

- **Pulumi Documentation**: https://www.pulumi.com/docs/
- **Pulumi GCP Provider**: https://www.pulumi.com/registry/packages/gcp/
- **Pulumi Docker Provider**: https://www.pulumi.com/registry/packages/docker/
- **Cloud Run Documentation**: https://cloud.google.com/run/docs
- **Deployment Guide**: `spec/ops-portal.md`

---

**Document Status**: Active implementation
**Owner**: DevOps Team / Platform Engineering
**Compliance**: FDA 21 CFR Part 11 compliant infrastructure audit trail
