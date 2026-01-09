# Portal Deployment and Operations Guide

**Version**: 2.0
**Audience**: Operations (DevOps, Release Managers, Platform Engineers)
**Last Updated**: 2025-11-24
**Status**: Draft

> **See**: prd-portal.md for portal product requirements
> **See**: dev-portal.md for implementation details
> **See**: ops-deployment.md for overall deployment architecture
> **See**: ops-operations.md for daily monitoring and incident response
> **See**: ops-database-setup.md for Cloud SQL database configuration

---

## Executive Summary

This guide covers deployment, configuration, monitoring, and operational procedures for the Clinical Trial Web Portal. The portal is a Flutter Web application deployed on Cloud Run, with each sponsor receiving their own isolated deployment in a sponsor-specific GCP project connected to Cloud SQL and Workforce Identity Federation.
Each sponsor shall have 4 environments:
- dev
- qa
- uat
- prod

**Deployment Model**: One portal instance per sponsor GCP project, per environment

**Hosting**: Cloud Run (containerized Flutter web app + Dart backend)

**Database**: Cloud SQL PostgreSQL (with RLS)

**Authentication**: [Google Workforce Identity Federation](https://cloud.google.com/workforce-identity-federation)

**Domains**: Custom subdomain per sponsor (e.g., `portal-sponsor.example.com`)

---

## Prerequisites

Before deploying a portal instance to an environment, ensure you have:

1. **GCP Project** created for sponsor with billing enabled
2. **Cloud SQL Instance** provisioned with schema applied
3. **Identity Platform** configured with auth providers
4. **Artifact Registry** repository for container images
5. **Domain Name** registered and DNS access
6. **SSL Certificate** (managed via Cloud Run or Cloud Load Balancer)
7. **gcloud CLI** authenticated with appropriate permissions
8. **Flutter SDK** installed (v3.38+ stable)
9. **Git Repository** access (core repo + sponsor repo)

---

# REQ-o00055: Role-Based Visual Indicator Verification

**Level**: Ops | **Status**: Draft | **Implements**: p00030

## Rationale

This requirement ensures that role-based visual indicators (color banners) are properly deployed and functioning across all portal deployments. These visual indicators are critical for user awareness and security, helping users immediately identify which role context they are operating in. This operational verification requirement defines the post-deployment testing process that must occur to confirm correct implementation of the role-based visual system defined in the product requirements (p00030). The verification scope encompasses visual presentation, data accuracy (role name display), color specification compliance, platform-wide deployment consistency, and the validation methodology to be used.

## Assertions

A. Portal deployments SHALL include verification that role-based color banners display correctly for all user roles.
B. The visual smoke test SHALL confirm that the banner appears on the portal homepage.
C. The banner SHALL display the correct role name after authentication.
D. The banner colors SHALL match the specification for each role type.
E. The role-based banner feature SHALL be included in all sponsor portal deployments.
F. The validation method SHALL require logging in as each role type to verify banner color and text.

*End* *Role-Based Visual Indicator Verification* | **Hash**: 00e842fa
---

## Infrastructure as Code with Pulumi

Portal deployment uses **Pulumi** for declarative infrastructure management, providing:
- **State Management**: Track infrastructure changes and detect drift
- **Multi-Environment Support**: dev, qa, uat, prod per sponsor
- **Audit Trail**: FDA 21 CFR Part 11 compliant infrastructure change tracking
- **Multi-Sponsor Pattern**: Consistent deployments across sponsors

### Prerequisites

Install Pulumi CLI and dependencies:

```bash
# Install Pulumi CLI
curl -fsSL https://get.pulumi.com | sh

# Install Node.js dependencies (TypeScript runtime)
cd apps/portal-cloud
npm install

# Configure Pulumi backend (use GCS for state storage)
pulumi login gs://pulumi-state-${ORGANIZATION}
```

**Pulumi Project Structure**: See `apps/portal-cloud/` for complete implementation

---

## Deploy Portal Infrastructure

### Environment-Specific Deployment

Each sponsor has 4 isolated environments (dev, qa, uat, prod). Deploy using Pulumi stacks:

```bash
# Navigate to Pulumi project
cd apps/portal-cloud

# Initialize stack for sponsor environment
pulumi stack init orion-prod

# Configure stack parameters
pulumi config set gcp:project cure-hht-orion-prod
pulumi config set gcp:region us-central1
pulumi config set sponsor orion
pulumi config set environment production
pulumi config set --secret dbPassword <secure-password>

# Preview infrastructure changes
pulumi preview

# Deploy infrastructure
pulumi up
```

**Stack Naming Convention**: `{sponsor}-{env}` (e.g., `orion-prod`, `orion-dev`, `callisto-uat`)

**What Gets Deployed**:
1. **Cloud Run Service** (containerized Flutter web app)
2. **Artifact Registry Repository** (Docker images)
3. **Cloud SQL Instance** (PostgreSQL with RLS)
4. **Identity Platform Configuration** (Identity Platform)
5. **Custom Domain Mapping** (SSL certificates)
6. **IAM Service Accounts** (least-privilege permissions)
7. **Monitoring & Alerting** (uptime checks, error alerts)

**Expected Output**:
```
Updating (orion-prod)

     Type                              Name                Status
 +   pulumi:pulumi:Stack               portal-orion-prod   created
 +   ├─ gcp:artifactregistry:Repository  portal-images    created
 +   ├─ gcp:sql:DatabaseInstance       portal-db           created
 +   ├─ gcp:cloudrun:Service           portal              created
 +   ├─ gcp:cloudrun:DomainMapping     portal-domain       created
 +   └─ gcp:monitoring:UptimeCheckConfig  portal-uptime   created

Outputs:
    portalUrl: "https://portal-orion.example.com"

Resources:
    + 15 created

Duration: 8m32s
```

---

### Build and Deploy Workflow

Pulumi orchestrates the entire build-to-deploy pipeline:

**Step 1: Build Flutter Web App**

The Pulumi program executes the Flutter build automatically:

```typescript
// apps/portal-cloud/src/build-flutter.ts
const buildResult = await runCommand("dart", [
  "run",
  "tools/build_system/build_portal.dart",
  "--sponsor-repo", sponsorRepoPath,
  "--environment", environment
]);
```

**Step 2: Build and Push Container**

```typescript
// apps/portal-cloud/src/docker-image.ts
const image = new docker.Image("portal-image", {
  imageName: `${region}-docker.pkg.dev/${project}/clinical-diary/portal:${imageTag}`,
  build: {
    context: "./build",
    dockerfile: "./Dockerfile"
  }
});
```

**Step 3: Deploy to Cloud Run**

```typescript
// apps/portal-cloud/src/cloud-run.ts
const service = new gcp.cloudrun.Service("portal", {
  location: region,
  template: {
    spec: {
      containers: [{
        image: image.imageName,
        ports: [{ containerPort: 8080 }]
      }]
    }
  }
});
```

**Complete Deployment**:

```bash
# Single command deploys everything
pulumi up
```

Pulumi handles:
- ✅ Flutter web build
- ✅ Docker image build and push
- ✅ Cloud Run deployment
- ✅ Domain mapping and SSL
- ✅ Database configuration
- ✅ Monitoring setup

---

## Container Configuration

The portal runs in a containerized nginx environment. **Container build and push are automated by Pulumi** (see `apps/portal-cloud/src/docker-image.ts`), but the Dockerfile and nginx configuration are maintained in the project.

### Dockerfile for Portal

Located at `apps/portal-cloud/Dockerfile`:

```dockerfile
# Dockerfile
FROM nginx:alpine AS runtime

# Copy Flutter web build
COPY build/web /usr/share/nginx/html

# Custom nginx config for SPA routing
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
```

### nginx.conf for SPA Routing

Located at `apps/portal-cloud/nginx.conf`:

```nginx
server {
    listen 8080;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # SPA routing - redirect all routes to index.html
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Health check endpoint
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    # Security headers
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
}
```

**Note**: Container build/push handled automatically by `pulumi up` via the `@pulumi/docker` provider.

---

## Pulumi State Management

### Infrastructure State

Pulumi stores infrastructure state in Google Cloud Storage for:
- **State Persistence**: Track all deployed resources
- **Drift Detection**: Identify manual changes outside of Pulumi
- **Audit Trail**: History of all infrastructure changes (FDA compliance)
- **Team Collaboration**: Shared state across deployments

**State Backend Configuration**:

```bash
# Login to GCS backend
pulumi login gs://pulumi-state-cure-hht

# Pulumi automatically creates state files per stack
# State file location: gs://pulumi-state-cure-hht/{project}/{stack}.json
```

**Stack State Files**:
- `orion-prod.json` - Orion production infrastructure state
- `orion-uat.json` - Orion UAT infrastructure state
- `callisto-prod.json` - Callisto production infrastructure state
- etc.

### Drift Detection

Detect infrastructure changes made outside Pulumi:

```bash
# Preview changes without applying
pulumi preview --diff

# Expected output if no drift:
# "Previewing update (orion-prod):
#
#      Type                 Name             Plan
#      pulumi:pulumi:Stack  portal-orion-prod
#
# Resources:
#     15 unchanged"
```

If drift detected, Pulumi shows:
- `~` Modified resources
- `+` Resources created outside Pulumi
- `-` Resources deleted outside Pulumi

**Resolve Drift**:
- Option 1: `pulumi up` to revert manual changes
- Option 2: `pulumi refresh` to import manual changes into state

---

## Automated Deployment (CI/CD)

### GitHub Actions Workflow

Add to core repository `.github/workflows/deploy-portal.yml`:

```yaml
name: Deploy Portal via Pulumi

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      stack:
        description: 'Pulumi stack to deploy (e.g., orion-prod)'
        required: true
      environment:
        description: 'Environment (dev/qa/uat/prod)'
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - uses: actions/checkout@v4
        with:
          path: core

      - uses: actions/checkout@v4
        with:
          repository: ${{ github.repository_owner }}/clinical-diary-${{ github.event.inputs.stack }}
          path: sponsor
          token: ${{ secrets.SPONSOR_REPO_TOKEN }}

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.38.3'
          channel: 'stable'

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install Pulumi CLI
        uses: pulumi/actions@v5

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Install Dependencies
        run: |
          cd core/apps/portal-cloud
          npm install

      - name: Pulumi Preview
        run: |
          cd core/apps/portal-cloud
          pulumi stack select ${{ github.event.inputs.stack }}
          pulumi preview
        env:
          PULUMI_ACCESS_TOKEN: ${{ secrets.PULUMI_ACCESS_TOKEN }}

      - name: Pulumi Deploy
        run: |
          cd core/apps/portal-cloud
          pulumi up --yes
        env:
          PULUMI_ACCESS_TOKEN: ${{ secrets.PULUMI_ACCESS_TOKEN }}

      - name: Export Portal URL
        run: |
          cd core/apps/portal-cloud
          pulumi stack output portalUrl
```

**Deployment Triggers**:
- **Manual**: `workflow_dispatch` with stack selection
- **Automatic**: Push to `main` branch (can be configured per environment)

**Deployment Time**: ~8-12 minutes (includes build, container push, Cloud Run deployment)

---

### Custom Domain Configuration

Custom domains are configured in Pulumi stack configuration and deployed automatically.

**Step 1: Configure Domain in Pulumi**

```bash
# Set custom domain for stack
pulumi config set domainName portal-orion.cure-hht.org
```

**Step 2: Deploy Domain Mapping**

Pulumi creates the domain mapping automatically:

```typescript
// apps/portal-cloud/src/domain-mapping.ts
const domainMapping = new gcp.cloudrun.DomainMapping("portal-domain", {
  location: region,
  name: config.require("domainName"),
  spec: {
    routeName: service.name,
  }
});
```

Deploy with `pulumi up` to create the domain mapping.

**Step 3: Configure DNS**

Add DNS records in your domain registrar (shown in Pulumi output):

```bash
# Get DNS record from Pulumi output
pulumi stack output dnsRecordRequired

# Expected output:
# CNAME portal-orion.cure-hht.org -> ghs.googlehosted.com
```

Add this CNAME record to your DNS provider.

**Step 4: Verify SSL Certificate**

Cloud Run automatically provisions SSL certificates. Verify via Pulumi:

```bash
# Check domain mapping status
pulumi stack output domainStatus

# Expected: ACTIVE (SSL certificate provisioned)
```

**Expected Result**:
- `https://portal-orion.cure-hht.org` resolves to portal
- SSL certificate valid and auto-renewing
- HTTP requests redirect to HTTPS

**Troubleshooting**: DNS propagation can take 24-48 hours. Check status:
```bash
dig portal-orion.cure-hht.org CNAME
```

---

## Cloud SQL Configuration

### Database Setup

**See**: ops-database-setup.md for complete Cloud SQL database configuration

**Portal-Specific Requirements**:

1. **Create `portal_users` table** (see `database/schema.sql`)
2. **Create `user_site_access` table** for site assignment
3. **Configure RLS policies** for role-based access (see `database/rls_policies.sql`)
4. **Enable Row-Level Security** on all tables

**Quick Validation**:

```bash
# Connect via Cloud SQL Proxy
cloud-sql-proxy ${PROJECT_ID}:${REGION}:${INSTANCE_NAME} --port=5432 &

# Verify RLS enabled on portal_users table
psql -h 127.0.0.1 -U app_user -d clinical_diary -c "
  SELECT tablename, rowsecurity
  FROM pg_tables
  WHERE schemaname = 'public'
  AND tablename IN ('portal_users', 'patients', 'sites', 'questionnaires')
"
```

**Expected Output**: All tables should have `rowsecurity = t` (true).

---

### Authentication Setup

**Step 1: Enable Auth Providers in Identity Platform**

Navigate to: GCP Console → Identity Platform → Providers

**Email/Password**:
- ✅ Enable Email/Password provider
- ✅ Email enumeration protection: Enabled
- ✅ Email verification required: Yes

**Google OAuth** (optional):
```bash
gcloud identity-platform config update \
  --project=${PROJECT_ID} \
  --enable-google \
  --google-client-id="123456789.apps.googleusercontent.com" \
  --google-client-secret-file=google-secret.txt
```

**Microsoft OAuth** (optional):
```bash
gcloud identity-platform config update \
  --project=${PROJECT_ID} \
  --enable-microsoft \
  --microsoft-client-id="abc123-def456" \
  --microsoft-client-secret-file=microsoft-secret.txt
```

**Step 2: Configure Authorized Domains**

```bash
# Add portal domain to authorized list
gcloud identity-platform config update \
  --project=${PROJECT_ID} \
  --authorized-domains="portal-sponsor.example.com,localhost"
```

**Step 3: Disable Public Sign-Ups**

Portals should not allow self-registration (Admins create accounts via Cloud Functions):

```bash
# Identity Platform doesn't have direct signup disable
# Implement via Cloud Function that validates invites
# See ops-security-authentication.md for details
```

---

## Monitoring and Health Checks

### Cloud Monitoring

**Built-in Metrics** (GCP Console → Cloud Run → Service → Metrics):
- Request count
- Request latency (p50, p95, p99)
- Container instance count
- Memory utilization
- CPU utilization
- Error rate (4xx/5xx)

**Create Uptime Check**:

```bash
# Create uptime check
gcloud monitoring uptime-checks create http \
  --project=${PROJECT_ID} \
  --display-name="Portal Health Check" \
  --uri="https://portal-sponsor.example.com/health" \
  --check-interval=60s \
  --timeout=10s
```

**Create Alert Policy**:

```bash
# Alert on high error rate
gcloud alpha monitoring policies create \
  --project=${PROJECT_ID} \
  --display-name="Portal Error Rate Alert" \
  --condition-display-name="Error rate > 5%" \
  --condition-filter='resource.type="cloud_run_revision" AND metric.type="run.googleapis.com/request_count" AND metric.labels.response_code_class="5xx"' \
  --condition-threshold-value=0.05 \
  --condition-threshold-comparison=COMPARISON_GT \
  --notification-channels="projects/${PROJECT_ID}/notificationChannels/CHANNEL_ID"
```

---

### Cloud SQL Monitoring

**Database Metrics** (GCP Console → Cloud SQL → Instance → Monitoring):
- Database size
- Active connections
- Query latency
- CPU and memory utilization
- Disk I/O

**Query Insights**:

```bash
# Enable Query Insights
gcloud sql instances patch ${INSTANCE_NAME} \
  --project=${PROJECT_ID} \
  --insights-config-query-insights-enabled \
  --insights-config-record-application-tags \
  --insights-config-record-client-address
```

---

### Application Logs

**Cloud Run Logs**:

```bash
# Tail logs
gcloud run services logs tail ${SERVICE_NAME} \
  --project=${PROJECT_ID} \
  --region=${REGION}

# Filter by severity
gcloud logging read "resource.type=cloud_run_revision AND severity>=ERROR" \
  --project=${PROJECT_ID} \
  --limit=50
```

**Cloud SQL Logs**:

```bash
# View database logs
gcloud logging read "resource.type=cloudsql_database" \
  --project=${PROJECT_ID} \
  --limit=50
```

**Recommended Log Retention**: 90 days minimum for compliance (FDA 21 CFR Part 11)

Configure log retention:
```bash
gcloud logging sinks create portal-audit-sink \
  storage.googleapis.com/portal-audit-logs-${PROJECT_ID} \
  --log-filter='resource.type="cloud_run_revision" OR resource.type="cloudsql_database"' \
  --project=${PROJECT_ID}
```

---

## Rollback Procedures

### Infrastructure Rollback via Pulumi

Pulumi maintains complete infrastructure history. Rollback entire stack to previous state:

**View Deployment History**:

```bash
# List all stack updates
pulumi stack history

# Expected output:
# Version  Time                  ResourceChanges  Description
# 5        2025-12-14 10:30:00   15 updated       Deploy v1.5.2
# 4        2025-12-13 14:22:00   15 unchanged     Deploy v1.5.1
# 3        2025-12-12 09:15:00   15 updated       Deploy v1.5.0
```

**Rollback to Previous Version**:

```bash
# Export previous stack state
pulumi stack export --version 4 > previous-state.json

# Import previous state (rolls back all resources)
pulumi stack import --file previous-state.json

# Apply the rollback
pulumi up --yes
```

**Rollback Time**: ~3-5 minutes (re-deploys previous container image and configuration)

### Cloud Run Revision Rollback (Quick Rollback)

For faster rollback without full Pulumi revert, route traffic to previous Cloud Run revision:

**Via Console**:
1. Navigate to Cloud Run → Service → Revisions
2. Find previous successful revision
3. Click "Manage Traffic" → Route 100% to previous revision

**Via CLI**:

```bash
# List revisions
gcloud run revisions list \
  --project=${PROJECT_ID} \
  --region=${REGION} \
  --service=portal

# Route traffic to previous revision
gcloud run services update-traffic portal \
  --project=${PROJECT_ID} \
  --region=${REGION} \
  --to-revisions=portal-00004-xyz=100
```

**Rollback Time**: ~10 seconds (container swap)

**Note**: This method only rolls back the container, not infrastructure changes (domain mappings, IAM, monitoring). For complete rollback, use Pulumi.

---

### Database Rollback

**See**: ops-database-migration.md for migration rollback procedures

**Emergency Rollback** (if migration causes portal failure):

```bash
# Point-in-time recovery to before migration
gcloud sql instances clone ${INSTANCE_NAME} ${INSTANCE_NAME}-recovered \
  --project=${PROJECT_ID} \
  --point-in-time="2025-01-24T09:55:00Z"

# Update Cloud Run to use recovered instance
# (requires service redeployment with new instance connection)
```

**Important**: Database rollbacks may cause data loss if users have created records using new schema. Test rollback in staging first.

---

## Incident Response

### Portal Unavailable (HTTP 5xx Errors)

**Step 1: Check Cloud Run Status**

```bash
# Check service status
gcloud run services describe ${SERVICE_NAME} \
  --project=${PROJECT_ID} \
  --region=${REGION}

# Check recent revisions
gcloud run revisions list \
  --project=${PROJECT_ID} \
  --region=${REGION} \
  --service=${SERVICE_NAME}
```

**Step 2: Verify Cloud SQL Connectivity**

```bash
# Check Cloud SQL instance status
gcloud sql instances describe ${INSTANCE_NAME} \
  --project=${PROJECT_ID}

# Expected: state: RUNNABLE
```

**Step 3: Rollback if Recent Deploy**

If issue started after recent deploy:

```bash
# Route traffic to previous revision
gcloud run services update-traffic ${SERVICE_NAME} \
  --project=${PROJECT_ID} \
  --region=${REGION} \
  --to-revisions=PREVIOUS_REVISION=100
```

**Step 4: Notify Stakeholders**

- Update status page
- Notify sponsor contacts
- Escalate to on-call engineer if >30 minutes downtime

---

### Authentication Failures

**Symptoms**: Users cannot log in, OAuth redirects fail

**Step 1: Check Identity Platform Status**

```bash
# Verify Identity Platform configuration
gcloud identity-platform config get \
  --project=${PROJECT_ID}
```

**Step 2: Verify OAuth Configuration**

- Check Client IDs in GCP Console → Identity Platform → Providers
- Verify authorized domains include portal domain
- Test OAuth flow manually

**Step 3: Check RLS Policies**

```sql
-- Verify portal_users table RLS policies
SELECT tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'portal_users';
```

**Expected**: Policies for `admins_auditors_see_all_users`, `investigators_own_sites_users`, etc.

---

### Slow Page Loads

**Symptoms**: Portal takes >5 seconds to load

**Step 1: Check Cloud Run Latency**

```bash
# View latency metrics
gcloud run services describe ${SERVICE_NAME} \
  --project=${PROJECT_ID} \
  --region=${REGION} \
  --format='value(status.latestReadyRevisionName)'

# Check if cold starts are the issue
gcloud logging read 'resource.type="cloud_run_revision" AND textPayload:"Cold start"' \
  --project=${PROJECT_ID} \
  --limit=20
```

**Solution for cold starts**: Increase `--min-instances` to keep instances warm.

**Step 2: Check Database Query Performance**

```sql
-- Identify slow queries (requires pg_stat_statements extension)
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
WHERE mean_exec_time > 1000  -- >1 second
ORDER BY mean_exec_time DESC
LIMIT 10;
```

**Step 3: Optimize**

- Add database indexes if queries slow
- Reduce RLS policy complexity
- Implement pagination for large datasets
- Increase Cloud Run CPU/memory if needed

---

## Security Hardening

### Content Security Policy (CSP)

Add to nginx.conf in container:

```nginx
add_header Content-Security-Policy "
    default-src 'self';
    script-src 'self' 'unsafe-inline' 'unsafe-eval' https://apis.google.com;
    style-src 'self' 'unsafe-inline';
    img-src 'self' data: https:;
    font-src 'self' data:;
    connect-src 'self' https://identitytoolkit.googleapis.com https://securetoken.googleapis.com https://*.firebaseio.com;
    frame-ancestors 'none';
" always;
```

**Rationale**: CSP prevents XSS attacks by restricting resource sources. Flutter Web requires `'unsafe-eval'` for Dart runtime.

---

### IAM Security

```bash
# Ensure Cloud Run service uses dedicated service account
gcloud run services update ${SERVICE_NAME} \
  --project=${PROJECT_ID} \
  --region=${REGION} \
  --service-account=portal-sa@${PROJECT_ID}.iam.gserviceaccount.com

# Service account should have minimal permissions
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:portal-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"
```

---

### VPC Security (Optional)

For highly sensitive sponsors, deploy Cloud Run within VPC:

```bash
# Create VPC connector
gcloud compute networks vpc-access connectors create portal-connector \
  --project=${PROJECT_ID} \
  --region=${REGION} \
  --network=default \
  --range=10.8.0.0/28

# Update Cloud Run to use VPC connector
gcloud run services update ${SERVICE_NAME} \
  --project=${PROJECT_ID} \
  --region=${REGION} \
  --vpc-connector=portal-connector \
  --vpc-egress=private-ranges-only
```

---

## Compliance and Audit

### Deployment Audit Trail

**Required for FDA 21 CFR Part 11**:
- All deployments logged with timestamp, deployer, and commit SHA
- Deployment approvals tracked (if required)
- Rollback events logged

**Implementation**:

Cloud Run automatically logs all deployments in Cloud Audit Logs:

```bash
# View deployment audit logs
gcloud logging read 'protoPayload.serviceName="run.googleapis.com" AND protoPayload.methodName="google.cloud.run.v1.Services.ReplaceService"' \
  --project=${PROJECT_ID} \
  --limit=20
```

---

### Environment Validation

Before production deployment, validate:

```bash
# Check Cloud Run service configuration
gcloud run services describe ${SERVICE_NAME} \
  --project=${PROJECT_ID} \
  --region=${REGION}

# Verify SSL certificate
curl -I https://portal-sponsor.example.com

# Test authentication flow
curl -X GET "https://portal-sponsor.example.com/health"
```

**Checklist**:
- ✅ Cloud Run service deployed successfully
- ✅ Custom domain mapped and SSL active
- ✅ Cloud SQL connection configured
- ✅ Identity Platform configured
- ✅ OAuth providers configured (if enabled)
- ✅ Authorized domains include portal domain
- ✅ RLS policies enabled on all tables
- ✅ Service account has minimal permissions
- ✅ HTTPS enforced
- ✅ Security headers configured
- ✅ Monitoring alerts configured

---

## Troubleshooting Reference

### Common Issues

**Issue**: Portal shows blank white screen
**Cause**: JavaScript error during Flutter initialization
**Solution**: Check browser console for errors, verify `main.dart.js` loaded correctly, check Cloud Run logs

**Issue**: "Authentication failed" error on login
**Cause**: Identity Platform misconfiguration or domain not authorized
**Solution**: Verify authorized domains in Identity Platform settings

**Issue**: Users can log in but see "No data"
**Cause**: RLS policies blocking access
**Solution**: Verify user role in `portal_users` table, check RLS policies, verify session variables set correctly

**Issue**: OAuth redirect fails
**Cause**: Redirect URL not in authorized domains
**Solution**: Add portal domain to Identity Platform authorized domains

**Issue**: Slow initial load (>10 seconds)
**Cause**: Cold start or Flutter app bundle not optimized
**Solution**: Increase `--min-instances=1`, rebuild with `--web-renderer html` for smaller bundle

**Issue**: Connection to database fails
**Cause**: Cloud SQL Proxy not configured or IAM permissions missing
**Solution**: Verify Cloud Run service account has `roles/cloudsql.client`, check VPC connector if using private IP

---

## References

- **Product Requirements**: prd-portal.md
- **Implementation**: dev-portal.md
- **Overall Deployment**: ops-deployment.md
- **Database Operations**: ops-database-setup.md, ops-database-migration.md
- **Daily Operations**: ops-operations.md
- **Security**: ops-security.md
- **Cloud Run Documentation**: https://cloud.google.com/run/docs
- **Identity Platform Documentation**: https://cloud.google.com/identity-platform/docs
- **Cloud SQL Documentation**: https://cloud.google.com/sql/docs

---

## Change Log

| Date | Version | Changes | Author |
| --- | --- | --- | --- |
| 2025-10-27 | 1.0 | Initial portal operations guide | DevOps Team |
| 2025-11-24 | 2.0 | Migration to Cloud Run and GCP | Development Team |

---

**Document Status**: Active portal operations guide
**Review Cycle**: Quarterly or after major incidents
**Owner**: DevOps Team / Platform Engineering
**Compliance Review**: Required for new sponsor deployments per 21 CFR Part 11
