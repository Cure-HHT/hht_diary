# Infrastructure as Code Specification

**Audience**: Operations
**Status**: Draft
**Version**: 3.0.0
**Last Updated**: 2025-12-28

---

## Purpose

This document specifies the infrastructure as code (IaC) approach for the Clinical Diary project on Google Cloud Platform, ensuring reproducible, validated, and auditable infrastructure deployments that comply with FDA 21 CFR Part 11 requirements.

---

## Requirements

# REQ-o00041: Infrastructure as Code for Cloud Resources

**Level**: Ops | **Status**: Draft | **Implements**: p00010, p80060, o80030

## Rationale

Infrastructure as code provides reproducibility, validation capability, and audit trail required for FDA compliance. By codifying all cloud resources in Pulumi, the platform ensures that infrastructure changes are version-controlled, peer-reviewed, and auditable—meeting the traceability requirements of 21 CFR Part 11. This approach eliminates manual configuration drift and enables deterministic infrastructure provisioning across environments.

## Assertions

A. The system SHALL use Pulumi for all GCP infrastructure and cloud resources.
B. All GCP projects SHALL be defined in Pulumi code.
C. All Cloud SQL instances SHALL be defined in Pulumi code.
D. All Cloud Run services SHALL be defined in Pulumi code.
E. Pulumi state SHALL be stored in a version-controlled backend (GCS or Pulumi Cloud).
F. Infrastructure changes SHALL be validated with `pulumi preview` before applying updates.
G. The system SHALL maintain separate Pulumi stacks for dev, staging, and production environments.
H. Per-sponsor infrastructure SHALL be isolated in separate GCP projects.
I. Infrastructure provisioning SHALL complete in less than 1 hour during performance qualification testing.

*End* *Infrastructure as Code for Cloud Resources* | **Hash**: 0f754a8a
---

# REQ-o00042: Infrastructure Change Control

**Level**: Ops | **Status**: Draft | **Implements**: o00041, p80060

## Rationale

Infrastructure change control ensures FDA 21 CFR Part 11 compliance by establishing a formal review and approval process for all infrastructure modifications. This requirement prevents unauthorized changes, maintains system integrity, and provides audit trails for regulatory inspections. The pull request workflow creates documented evidence of reviews, approvals, and change justifications. Drift detection ensures the deployed infrastructure matches the declared configuration, preventing undocumented manual changes. Multiple levels of approval for production changes reflect the higher risk associated with changes to validated environments.

## Assertions

A. The system SHALL require all Pulumi infrastructure changes to be submitted via pull request.
B. The system SHALL require at least one reviewer approval for non-production pull requests containing infrastructure changes.
C. The system SHALL require at least two reviewer approvals for production pull requests containing infrastructure changes.
D. The system SHALL require all infrastructure changes to reference a ticket or requirement identifier.
E. The system SHALL prevent direct commits to infrastructure code without pull request review.
F. The system SHALL automatically run 'pulumi preview' on all pull requests containing infrastructure changes.
G. The system SHALL execute drift detection against deployed infrastructure daily.
H. Infrastructure change control processes SHALL be documented in Installation Qualification (IQ) protocols.
I. The pull request workflow SHALL be verified to prevent direct commits during Operational Qualification (OQ).
J. Performance Qualification (PQ) SHALL verify that 100% of infrastructure changes were processed through the pull request workflow.

*End* *Infrastructure Change Control* | **Hash**: ee749ae7
---

## Architecture

### Directory Structure

```
infrastructure/
├── pulumi/
│   ├── components/
│   │   ├── gcp-project/
│   │   │   ├── index.ts
│   │   │   └── README.md
│   │   ├── cloud-sql/
│   │   │   ├── index.ts
│   │   │   └── README.md
│   │   ├── cloud-run/
│   │   │   ├── index.ts
│   │   │   └── README.md
│   │   ├── identity-platform/
│   │   │   ├── index.ts
│   │   │   └── README.md
│   │   ├── vpc-networking/
│   │   │   ├── index.ts
│   │   │   └── README.md
│   │   ├── artifact-registry/
│   │   │   ├── index.ts
│   │   │   └── README.md
│   │   └── monitoring/
│   │       ├── index.ts
│   │       └── README.md
│   ├── stacks/
│   │   ├── dev/
│   │   │   ├── index.ts
│   │   │   ├── Pulumi.dev.yaml
│   │   │   └── README.md
│   │   ├── staging/
│   │   │   ├── index.ts
│   │   │   ├── Pulumi.staging.yaml
│   │   │   └── README.md
│   │   └── production/
│   │       ├── index.ts
│   │       ├── Pulumi.production.yaml
│   │       └── README.md
│   ├── sponsors/
│   │   ├── orion/
│   │   │   ├── staging/
│   │   │   │   ├── index.ts
│   │   │   │   └── Pulumi.yaml
│   │   │   └── production/
│   │   │       ├── index.ts
│   │   │       └── Pulumi.yaml
│   │   └── andromeda/
│   │       ├── staging/
│   │       │   ├── index.ts
│   │       │   └── Pulumi.yaml
│   │       └── production/
│   │           ├── index.ts
│   │           └── Pulumi.yaml
│   ├── package.json
│   ├── tsconfig.json
│   └── Pulumi.yaml
├── docs/
│   ├── pulumi-setup.md
│   ├── drift-detection.md
│   └── validation/
│       ├── IQ-pulumi.md
│       ├── OQ-pulumi.md
│       └── PQ-pulumi.md
└── README.md
```

### Technology Stack

**Core Tools**:
- **Pulumi** v3.x: Infrastructure as code (TypeScript)
- **Google Cloud Storage** or **Pulumi Cloud**: State backend
- **@pulumi/gcp**: Manage GCP resources

**Dependencies** (package.json):
```json
{
  "name": "clinical-diary-infrastructure",
  "main": "index.ts",
  "devDependencies": {
    "@types/node": "^20"
  },
  "dependencies": {
    "@pulumi/pulumi": "^3.0.0",
    "@pulumi/gcp": "^7.0.0",
    "@pulumi/docker": "^4.0.0"
  }
}
```

**TypeScript Configuration** (tsconfig.json):
```json
{
  "compilerOptions": {
    "strict": true,
    "outDir": "bin",
    "target": "es2020",
    "module": "commonjs",
    "moduleResolution": "node",
    "sourceMap": true,
    "experimentalDecorators": true,
    "declaration": true
  },
  "include": ["./**/*.ts"]
}
```

---

## Infrastructure Components

### 1. GCP Projects (Per Sponsor)

Each sponsor gets a dedicated GCP project:

```typescript
// components/gcp-project/index.ts
import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

export interface GcpProjectArgs {
  sponsor: string;
  environment: string;
  billingAccountId: string;
  orgId?: string;
}

export class GcpProject extends pulumi.ComponentResource {
  public readonly projectId: pulumi.Output<string>;
  public readonly project: gcp.organizations.Project;

  constructor(name: string, args: GcpProjectArgs, opts?: pulumi.ComponentResourceOptions) {
    super("clinical-diary:gcp-project", name, {}, opts);

    const projectId = `clinical-diary-${args.sponsor}-${args.environment}`;

    this.project = new gcp.organizations.Project(`${name}-project`, {
      projectId: projectId,
      name: `Clinical Diary ${args.sponsor} ${args.environment}`,
      billingAccount: args.billingAccountId,
      orgId: args.orgId,
      labels: {
        sponsor: args.sponsor,
        environment: args.environment,
        managed_by: "pulumi",
        compliance: "hipaa-fda",
      },
    }, { parent: this });

    // Enable required APIs
    const apis = [
      "sqladmin.googleapis.com",
      "run.googleapis.com",
      "secretmanager.googleapis.com",
      "identitytoolkit.googleapis.com",
      "compute.googleapis.com",
      "vpcaccess.googleapis.com",
      "artifactregistry.googleapis.com",
      "cloudscheduler.googleapis.com",
      "logging.googleapis.com",
      "monitoring.googleapis.com",
      "cloudtrace.googleapis.com",
    ];

    apis.forEach((api, index) => {
      new gcp.projects.Service(`${name}-api-${index}`, {
        project: this.project.projectId,
        service: api,
        disableOnDestroy: false,
      }, { parent: this, dependsOn: [this.project] });
    });

    this.projectId = this.project.projectId;
    this.registerOutputs({ projectId: this.projectId });
  }
}
```

### 2. Cloud SQL Instance

```typescript
// components/cloud-sql/index.ts
import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

export interface CloudSqlArgs {
  projectId: pulumi.Input<string>;
  region: string;
  sponsor: string;
  environment: string;
  privateNetwork: pulumi.Input<string>;
  databasePassword: pulumi.Input<string>;
}

export class CloudSql extends pulumi.ComponentResource {
  public readonly instance: gcp.sql.DatabaseInstance;
  public readonly database: gcp.sql.Database;
  public readonly connectionName: pulumi.Output<string>;

  constructor(name: string, args: CloudSqlArgs, opts?: pulumi.ComponentResourceOptions) {
    super("clinical-diary:cloud-sql", name, {}, opts);

    const isProduction = args.environment === "production";

    this.instance = new gcp.sql.DatabaseInstance(`${name}-instance`, {
      project: args.projectId,
      region: args.region,
      name: `${args.sponsor}-db`,
      databaseVersion: "POSTGRES_15",
      deletionProtection: isProduction,
      settings: {
        tier: isProduction ? "db-custom-2-8192" : "db-custom-1-3840",
        availabilityType: isProduction ? "REGIONAL" : "ZONAL",
        backupConfiguration: {
          enabled: true,
          startTime: "02:00",
          pointInTimeRecoveryEnabled: true,
          backupRetentionSettings: {
            retainedBackups: isProduction ? 30 : 7,
            retentionUnit: "COUNT",
          },
        },
        ipConfiguration: {
          ipv4Enabled: false,
          privateNetwork: args.privateNetwork,
          requireSsl: true,
        },
        databaseFlags: [
          { name: "cloudsql.enable_pgaudit", value: "on" },
          { name: "log_checkpoints", value: "on" },
          { name: "log_connections", value: "on" },
          { name: "log_disconnections", value: "on" },
        ],
        maintenanceWindow: {
          day: 7,  // Sunday
          hour: 3, // 3 AM
        },
        userLabels: {
          sponsor: args.sponsor,
          environment: args.environment,
          managed_by: "pulumi",
        },
      },
    }, { parent: this });

    this.database = new gcp.sql.Database(`${name}-database`, {
      project: args.projectId,
      instance: this.instance.name,
      name: "clinical_diary",
    }, { parent: this });

    // Database user (password from Doppler)
    new gcp.sql.User(`${name}-user`, {
      project: args.projectId,
      instance: this.instance.name,
      name: "app_user",
      password: args.databasePassword,
    }, { parent: this });

    this.connectionName = this.instance.connectionName;
    this.registerOutputs({ connectionName: this.connectionName });
  }
}
```

### 3. Cloud Run Service

```typescript
// components/cloud-run/index.ts
import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

export interface CloudRunArgs {
  projectId: pulumi.Input<string>;
  region: string;
  sponsor: string;
  environment: string;
  imageTag: string;
  serviceAccountEmail: pulumi.Input<string>;
  vpcConnectorId: pulumi.Input<string>;
  cloudSqlConnectionName: pulumi.Input<string>;
  databaseUrlSecretId: pulumi.Input<string>;
}

export class CloudRunService extends pulumi.ComponentResource {
  public readonly service: gcp.cloudrunv2.Service;
  public readonly serviceUrl: pulumi.Output<string>;

  constructor(name: string, args: CloudRunArgs, opts?: pulumi.ComponentResourceOptions) {
    super("clinical-diary:cloud-run", name, {}, opts);

    const isProduction = args.environment === "production";

    this.service = new gcp.cloudrunv2.Service(`${name}-service`, {
      project: args.projectId,
      location: args.region,
      name: "clinical-diary-api",
      template: {
        serviceAccount: args.serviceAccountEmail,
        vpcAccess: {
          connector: args.vpcConnectorId,
          egress: "PRIVATE_RANGES_ONLY",
        },
        scaling: {
          minInstanceCount: isProduction ? 1 : 0,
          maxInstanceCount: isProduction ? 10 : 3,
        },
        containers: [{
          image: pulumi.interpolate`${args.region}-docker.pkg.dev/${args.projectId}/clinical-diary/api:${args.imageTag}`,
          resources: {
            limits: {
              cpu: "1000m",
              memory: "512Mi",
            },
          },
          envs: [
            { name: "ENVIRONMENT", value: args.environment },
            { name: "SPONSOR_ID", value: args.sponsor },
            { name: "GCP_PROJECT_ID", valueSource: { secretKeyRef: undefined } },
          ],
          volumeMounts: [{
            name: "cloudsql",
            mountPath: "/cloudsql",
          }],
        }],
        volumes: [{
          name: "cloudsql",
          cloudSqlInstance: { instances: [args.cloudSqlConnectionName] },
        }],
      },
      labels: {
        sponsor: args.sponsor,
        environment: args.environment,
        managed_by: "pulumi",
      },
    }, { parent: this });

    // Allow unauthenticated access (API handles auth via Identity Platform)
    new gcp.cloudrunv2.ServiceIamMember(`${name}-invoker`, {
      project: args.projectId,
      location: args.region,
      name: this.service.name,
      role: "roles/run.invoker",
      member: "allUsers",
    }, { parent: this });

    this.serviceUrl = this.service.uri;
    this.registerOutputs({ serviceUrl: this.serviceUrl });
  }
}
```

### 4. VPC and Networking

```typescript
// components/vpc-networking/index.ts
import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

export interface VpcNetworkingArgs {
  projectId: pulumi.Input<string>;
  region: string;
  environment: string;
}

export class VpcNetworking extends pulumi.ComponentResource {
  public readonly network: gcp.compute.Network;
  public readonly serverlessConnector: gcp.vpcaccess.Connector;
  public readonly networkSelfLink: pulumi.Output<string>;

  constructor(name: string, args: VpcNetworkingArgs, opts?: pulumi.ComponentResourceOptions) {
    super("clinical-diary:vpc-networking", name, {}, opts);

    const isProduction = args.environment === "production";

    this.network = new gcp.compute.Network(`${name}-network`, {
      project: args.projectId,
      name: "clinical-diary-vpc",
      autoCreateSubnetworks: false,
    }, { parent: this });

    // Private Service Access for Cloud SQL
    const privateIpRange = new gcp.compute.GlobalAddress(`${name}-private-ip`, {
      project: args.projectId,
      name: "private-ip-range",
      purpose: "VPC_PEERING",
      addressType: "INTERNAL",
      prefixLength: 16,
      network: this.network.id,
    }, { parent: this });

    new gcp.servicenetworking.Connection(`${name}-private-connection`, {
      network: this.network.id,
      service: "servicenetworking.googleapis.com",
      reservedPeeringRanges: [privateIpRange.name],
    }, { parent: this });

    // Serverless VPC Connector for Cloud Run
    this.serverlessConnector = new gcp.vpcaccess.Connector(`${name}-connector`, {
      project: args.projectId,
      region: args.region,
      name: "cloud-run-connector",
      ipCidrRange: "10.8.0.0/28",
      network: this.network.name,
      minInstances: 2,
      maxInstances: isProduction ? 10 : 3,
    }, { parent: this });

    this.networkSelfLink = this.network.selfLink;
    this.registerOutputs({
      networkSelfLink: this.networkSelfLink,
      connectorId: this.serverlessConnector.id,
    });
  }
}
```

### 5. Identity Platform

```typescript
// components/identity-platform/index.ts
import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

export interface IdentityPlatformArgs {
  projectId: pulumi.Input<string>;
  sponsor: string;
  environment: string;
  enableAppleAuth?: boolean;
  customDomain?: string;
  googleOAuthClientId?: pulumi.Input<string>;
  googleOAuthClientSecret?: pulumi.Input<string>;
}

export class IdentityPlatform extends pulumi.ComponentResource {
  public readonly config: gcp.identityplatform.Config;

  constructor(name: string, args: IdentityPlatformArgs, opts?: pulumi.ComponentResourceOptions) {
    super("clinical-diary:identity-platform", name, {}, opts);

    const isProduction = args.environment === "production";

    this.config = new gcp.identityplatform.Config(`${name}-config`, {
      project: args.projectId,
      signIn: {
        allowDuplicateEmails: false,
        email: {
          enabled: true,
          passwordRequired: true,
        },
      },
      mfa: isProduction ? {
        enabledProviders: ["PHONE_SMS"],
        state: "ENABLED",
      } : undefined,
      authorizedDomains: [
        `clinical-diary-${args.sponsor}-${args.environment}.web.app`,
        ...(args.customDomain ? [args.customDomain] : []),
      ],
    }, { parent: this });

    // Google OAuth provider
    if (args.googleOAuthClientId && args.googleOAuthClientSecret) {
      new gcp.identityplatform.DefaultSupportedIdpConfig(`${name}-google`, {
        project: args.projectId,
        idpId: "google.com",
        enabled: true,
        clientId: args.googleOAuthClientId,
        clientSecret: args.googleOAuthClientSecret,
      }, { parent: this });
    }

    this.registerOutputs({});
  }
}
```

### 6. Artifact Registry

```typescript
// components/artifact-registry/index.ts
import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

export interface ArtifactRegistryArgs {
  projectId: pulumi.Input<string>;
  region: string;
  sponsor: string;
  environment: string;
}

export class ArtifactRegistry extends pulumi.ComponentResource {
  public readonly repository: gcp.artifactregistry.Repository;

  constructor(name: string, args: ArtifactRegistryArgs, opts?: pulumi.ComponentResourceOptions) {
    super("clinical-diary:artifact-registry", name, {}, opts);

    this.repository = new gcp.artifactregistry.Repository(`${name}-repo`, {
      project: args.projectId,
      location: args.region,
      repositoryId: "clinical-diary",
      description: `Container images for Clinical Diary ${args.sponsor}`,
      format: "DOCKER",
      cleanupPolicies: [
        {
          id: "keep-minimum-versions",
          action: "KEEP",
          mostRecentVersions: { keepCount: 10 },
        },
        {
          id: "delete-old-images",
          action: "DELETE",
          condition: { olderThan: "2592000s" }, // 30 days
        },
      ],
      labels: {
        sponsor: args.sponsor,
        environment: args.environment,
        managed_by: "pulumi",
      },
    }, { parent: this });

    this.registerOutputs({});
  }
}
```

### 7. Monitoring

```typescript
// components/monitoring/index.ts
import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

export interface MonitoringArgs {
  projectId: pulumi.Input<string>;
  serviceUrl: pulumi.Input<string>;
  notificationChannels: pulumi.Input<string>[];
}

export class Monitoring extends pulumi.ComponentResource {
  constructor(name: string, args: MonitoringArgs, opts?: pulumi.ComponentResourceOptions) {
    super("clinical-diary:monitoring", name, {}, opts);

    // Uptime check
    new gcp.monitoring.UptimeCheckConfig(`${name}-api-health`, {
      project: args.projectId,
      displayName: "API Health",
      timeout: "10s",
      period: "60s",
      httpCheck: {
        path: "/health",
        useSsl: true,
      },
      monitoredResource: {
        type: "uptime_url",
        labels: {
          project_id: args.projectId as string,
          host: args.serviceUrl as string,
        },
      },
      selectedRegions: ["USA_OREGON", "USA_VIRGINIA", "EUROPE"],
    }, { parent: this });

    // High Error Rate Alert
    new gcp.monitoring.AlertPolicy(`${name}-error-rate`, {
      project: args.projectId,
      displayName: "High Error Rate",
      combiner: "OR",
      conditions: [{
        displayName: "Error rate condition",
        conditionThreshold: {
          filter: 'resource.type="cloud_run_revision" AND metric.type="logging.googleapis.com/log_entry_count" AND metric.labels.severity="ERROR"',
          comparison: "COMPARISON_GT",
          thresholdValue: 10,
          duration: "300s",
          aggregations: [{
            alignmentPeriod: "60s",
            perSeriesAligner: "ALIGN_RATE",
          }],
        },
      }],
      notificationChannels: args.notificationChannels,
    }, { parent: this });

    // High API Latency Alert
    new gcp.monitoring.AlertPolicy(`${name}-latency`, {
      project: args.projectId,
      displayName: "High API Latency",
      combiner: "OR",
      conditions: [{
        displayName: "Latency condition",
        conditionThreshold: {
          filter: 'resource.type="cloud_run_revision" AND metric.type="run.googleapis.com/request_latencies"',
          comparison: "COMPARISON_GT",
          thresholdValue: 2000,
          duration: "300s",
          aggregations: [{
            alignmentPeriod: "60s",
            perSeriesAligner: "ALIGN_PERCENTILE_95",
          }],
        },
      }],
      notificationChannels: args.notificationChannels,
    }, { parent: this });

    // Database High CPU Alert
    new gcp.monitoring.AlertPolicy(`${name}-db-cpu`, {
      project: args.projectId,
      displayName: "Database High CPU",
      combiner: "OR",
      conditions: [{
        displayName: "CPU utilization condition",
        conditionThreshold: {
          filter: 'resource.type="cloudsql_database" AND metric.type="cloudsql.googleapis.com/database/cpu/utilization"',
          comparison: "COMPARISON_GT",
          thresholdValue: 0.8,
          duration: "300s",
          aggregations: [{
            alignmentPeriod: "60s",
            perSeriesAligner: "ALIGN_MEAN",
          }],
        },
      }],
      notificationChannels: args.notificationChannels,
    }, { parent: this });

    this.registerOutputs({});
  }
}
```

---

## State Management

### Backend Configuration

**Option 1: Pulumi Cloud** (Recommended):
```yaml
# Pulumi.yaml
name: clinical-diary-infrastructure
runtime: nodejs
backend:
  url: https://api.pulumi.com
```

**Option 2: GCS Backend** (Self-managed):
```yaml
# Pulumi.yaml
name: clinical-diary-infrastructure
runtime: nodejs
backend:
  url: gs://clinical-diary-pulumi-state
```

### State Bucket Setup (for GCS backend)

```bash
# Create state bucket (one-time setup)
gsutil mb -l us-central1 -b on gs://clinical-diary-pulumi-state

# Enable versioning for state recovery
gsutil versioning set on gs://clinical-diary-pulumi-state

# Set lifecycle for old versions
cat > lifecycle.json << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"numNewerVersions": 10}
      }
    ]
  }
}
EOF
gsutil lifecycle set lifecycle.json gs://clinical-diary-pulumi-state

# Login to backend
pulumi login gs://clinical-diary-pulumi-state
```

### State Security

**MUST**:
- Encrypt state at rest (GCS default / Pulumi Cloud encrypts by default)
- Use stack-level encryption with secrets provider
- Restrict access via IAM (bucket-level permissions) or Pulumi Cloud RBAC
- Never commit state files to Git
- Use Pulumi's built-in state locking

---

## Workflow

### Development Flow

1. **Make Infrastructure Changes**:
   ```bash
   cd infrastructure/pulumi/sponsors/${SPONSOR}/${ENV}
   # Edit index.ts or Pulumi.yaml configuration
   ```

2. **Preview Changes**:
   ```bash
   doppler run -- pulumi preview
   # Review output carefully
   ```

3. **Create Pull Request**:
   ```bash
   git checkout -b infra/add-monitoring
   git add .
   git commit -m "[INFRA] Add monitoring resources

   Implements: REQ-o00045"
   git push origin infra/add-monitoring
   gh pr create
   ```

4. **Automated CI Checks**:
   - `npm run lint` (ESLint/TypeScript checks)
   - `tsc --noEmit` (type checking)
   - `pulumi preview` (preview changes)
   - Security scanning

5. **Review & Approval**:
   - Reviewer examines `pulumi preview` output
   - Reviewer verifies ticket reference
   - Reviewer approves PR

6. **Apply Changes**:
   ```bash
   # After merge to main
   doppler run -- pulumi up --yes
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

**GitHub Actions Workflow**:
```yaml
# .github/workflows/pulumi-drift-detection.yml
name: Pulumi Drift Detection

on:
  schedule:
    - cron: '0 9 * * *'  # 9 AM daily
  workflow_dispatch:

jobs:
  detect-drift:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        sponsor: [orion, andromeda]
        environment: [staging, production]

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci
        working-directory: infrastructure/pulumi

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.WIF_PROVIDER }}
          service_account: ${{ vars.PULUMI_SA }}

      - name: Setup Pulumi
        uses: pulumi/actions@v5

      - name: Pulumi Preview (Drift Check)
        id: preview
        run: |
          pulumi stack select ${{ matrix.sponsor }}-${{ matrix.environment }}
          pulumi preview --expect-no-changes --json > preview.json 2>&1 || echo "DRIFT_DETECTED=true" >> $GITHUB_ENV
        working-directory: infrastructure/pulumi/sponsors/${{ matrix.sponsor }}/${{ matrix.environment }}
        env:
          PULUMI_ACCESS_TOKEN: ${{ secrets.PULUMI_ACCESS_TOKEN }}
        continue-on-error: true

      - name: Alert on Drift
        if: env.DRIFT_DETECTED == 'true'
        uses: slackapi/slack-github-action@v1
        with:
          channel-id: ${{ vars.SLACK_CHANNEL }}
          payload: |
            {
              "text": "Pulumi drift detected in ${{ matrix.sponsor }}-${{ matrix.environment }}!"
            }
```

### Manual Drift Check

```bash
# Check for drift
cd infrastructure/pulumi/sponsors/${SPONSOR}/${ENV}
doppler run -- pulumi preview --expect-no-changes

# --expect-no-changes flag:
# - Exits with 0 if no changes detected
# - Exits with non-zero if drift detected
```

---

## Validation

### Installation Qualification (IQ)

**Verify**:
- [ ] Pulumi v3.x installed
- [ ] Node.js v20+ installed
- [ ] @pulumi/gcp provider available
- [ ] Backend configured correctly (Pulumi Cloud or GCS)
- [ ] Components are accessible
- [ ] Documentation complete

**Test**:
```bash
pulumi version
node --version
npm install
pulumi preview
```

### Operational Qualification (OQ)

**Verify**:
- [ ] `pulumi preview` works for all stacks
- [ ] `pulumi up` provisions resources correctly
- [ ] State locking prevents concurrent modifications
- [ ] Drift detection identifies manual changes
- [ ] Rollback procedures work

**Test**:
```bash
# Create test resource
pulumi up

# Manually modify resource in GCP Console
# (e.g., change Cloud Run environment variable)

# Detect drift
pulumi preview --expect-no-changes
# Should show difference

# Revert to desired state
pulumi up
```

### Performance Qualification (PQ)

**Metrics**:
- [ ] Infrastructure provisioning time < 1 hour
- [ ] `pulumi preview` completes in < 5 minutes
- [ ] Drift detection runs daily without failures
- [ ] No unauthorized infrastructure changes in 30 days

---

## Security

### Secrets Management

**NEVER** store in Pulumi code:
- Database passwords
- API keys
- Service tokens

**USE** Pulumi secrets + Doppler or GCP Secret Manager:
```typescript
import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

// Get secret from Pulumi config (encrypted)
const config = new pulumi.Config();
const databasePassword = config.requireSecret("databasePassword");

// Reference Secret Manager secrets in Cloud Run
const dbPasswordSecret = new gcp.secretmanager.Secret("db-password", {
  project: projectId,
  secretId: "database-password",
  replication: {
    auto: {},
  },
});

new gcp.secretmanager.SecretVersion("db-password-version", {
  secret: dbPasswordSecret.id,
  secretData: databasePassword,
});
```

**Set secrets via Pulumi CLI**:
```bash
# Set secret (encrypted in state)
pulumi config set --secret databasePassword "my-secret-password"

# Or use Doppler
doppler run -- pulumi up
```

### Access Control

**IAM Roles for Pulumi**:
```typescript
// Service account for Pulumi
const pulumiServiceAccount = new gcp.serviceaccount.Account("pulumi-sa", {
  accountId: "pulumi",
  displayName: "Pulumi Service Account",
});

// Required roles
const pulumiRoles = [
  "roles/cloudsql.admin",
  "roles/run.admin",
  "roles/iam.serviceAccountAdmin",
  "roles/secretmanager.admin",
  "roles/compute.networkAdmin",
  "roles/artifactregistry.admin",
  "roles/monitoring.admin",
];

pulumiRoles.forEach((role, index) => {
  new gcp.projects.IAMMember(`pulumi-role-${index}`, {
    project: projectId,
    role: role,
    member: pulumi.interpolate`serviceAccount:${pulumiServiceAccount.email}`,
  });
});
```

**Workload Identity Federation** (for GitHub Actions):
```typescript
const githubPool = new gcp.iam.WorkloadIdentityPool("github-pool", {
  workloadIdentityPoolId: "github-pool",
  displayName: "GitHub Actions Pool",
});

const githubProvider = new gcp.iam.WorkloadIdentityPoolProvider("github-provider", {
  workloadIdentityPoolId: githubPool.workloadIdentityPoolId,
  workloadIdentityPoolProviderId: "github-provider",
  attributeMapping: {
    "google.subject": "assertion.sub",
    "attribute.actor": "assertion.actor",
    "attribute.repository": "assertion.repository",
  },
  oidc: {
    issuerUri: "https://token.actions.githubusercontent.com",
  },
});
```

---

## Rollback Procedures

### Rollback Infrastructure Changes

**Using Git**:
```bash
# Revert to previous commit
git revert <commit-hash>

# Apply reverted configuration
doppler run -- pulumi preview
doppler run -- pulumi up
```

**Using Pulumi Stack History**:
```bash
# List stack history
pulumi stack history

# Export a previous state version
pulumi stack export --version <version-number> > previous-state.json

# Review what would change to get back to that state
pulumi preview

# Import previous state (DANGEROUS - last resort)
pulumi stack import < previous-state.json
```

**Best Practice**: Use Git to revert infrastructure code, not state manipulation.

---

## Compliance & Audit

### Audit Trail

**Git History**:
- All infrastructure changes in Git
- Commit messages reference tickets
- Timestamps and authors tracked

**Pulumi Logs**:
- `pulumi preview` output saved in CI/CD
- `pulumi up` output saved
- Stack history tracks all state changes
- Pulumi Cloud provides audit logs (if using managed backend)

**Change Control**:
- Pull requests document changes
- Approvals documented in PR
- Merge commits provide audit trail

### Compliance Evidence

**For FDA Audit**:
1. Git history of infrastructure code
2. Pull request history (approvals)
3. Pulumi preview/up logs
4. Drift detection reports
5. Validation documentation (IQ/OQ/PQ)
6. Stack history and state version history

---

## Multi-Sponsor Management

### Adding a New Sponsor

1. **Create Sponsor Directory**:
   ```bash
   mkdir -p infrastructure/pulumi/sponsors/${NEW_SPONSOR}/{staging,production}
   ```

2. **Create Configuration**:
   ```typescript
   // infrastructure/pulumi/sponsors/${NEW_SPONSOR}/staging/index.ts
   import { ClinicalDiaryStack } from "../../../components/clinical-diary-stack";

   const stack = new ClinicalDiaryStack("clinical-diary", {
     sponsor: "new-sponsor",
     environment: "staging",
     region: "us-central1",
     billingAccountId: config.require("billingAccountId"),
     customDomain: "new-sponsor-staging.clinical-diary.com",
   });

   export const projectId = stack.projectId;
   export const apiUrl = stack.apiUrl;
   ```

3. **Initialize and Apply**:
   ```bash
   cd infrastructure/pulumi/sponsors/${NEW_SPONSOR}/staging
   npm install
   pulumi stack init new-sponsor-staging
   doppler run --config staging -- pulumi preview
   doppler run --config staging -- pulumi up
   ```

### Sponsor Isolation

Each sponsor's infrastructure is completely isolated:
- Separate GCP project
- Separate Cloud SQL instance
- Separate Identity Platform tenant
- Separate VPC
- Separate Pulumi stack

---

## Troubleshooting

### State Lock Issues

```bash
# Pulumi uses automatic locking. If you encounter lock issues:

# For Pulumi Cloud backend - locks are automatic and released on completion
# Check for stale locks in Pulumi Cloud console

# For GCS backend - check lock file
gsutil stat gs://clinical-diary-pulumi-state/.pulumi/locks/${STACK_NAME}

# Cancel a stuck update (releases lock)
pulumi cancel

# Better: Wait for lock to release or investigate
pulumi stack --show-ids
```

### Provider Authentication Failures

```bash
# Check gcloud authentication
gcloud auth application-default print-access-token

# Re-authenticate
gcloud auth application-default login

# For CI/CD, verify Workload Identity
gcloud iam workload-identity-pools providers describe github-provider \
  --workload-identity-pool=github-pool \
  --location=global
```

### Drift Detected

```bash
# Review drift
pulumi preview --expect-no-changes

# Options:
# 1. Accept drift (update code to match reality)
pulumi refresh

# 2. Revert drift (apply desired state)
pulumi up
```

---

## Maintenance

### Regular Tasks

**Daily**:
- Automated drift detection runs
- Review drift reports

**Weekly**:
- Review GCP billing
- Review stack state size

**Monthly**:
- Update Pulumi version (`npm update @pulumi/pulumi`)
- Update provider versions (`npm update @pulumi/gcp`)
- Review and archive old stacks

**Quarterly**:
- Review access permissions
- Audit infrastructure changes
- Update validation documentation

---

## References

**Internal**:
- `infrastructure/README.md` - Getting started
- `docs/pulumi-setup.md` - Detailed setup guide

**External**:
- [Pulumi Documentation](https://www.pulumi.com/docs/)
- [Pulumi GCP Provider](https://www.pulumi.com/registry/packages/gcp/)
- [GCP Cloud SQL Pulumi](https://www.pulumi.com/registry/packages/gcp/api-docs/sql/databaseinstance/)
- [GCP Cloud Run Pulumi](https://www.pulumi.com/registry/packages/gcp/api-docs/cloudrunv2/service/)

---

## Change History

| Date | Version | Author | Changes |
| --- | --- | --- | --- |
| 2025-10-27 | 1.0.0 | Dev Team | Initial specification (Supabase) |
| 2025-11-24 | 2.0.0 | Claude | Migration to GCP (Cloud SQL, Cloud Run, IAM) |
| 2025-12-28 | 3.0.0 | Claude | Migration from Terraform to Pulumi |

---

**Approval Required**: DevOps Lead, QA Lead
**Validation Required**: IQ/OQ/PQ before production use
**Review Frequency**: Quarterly or when major changes needed
