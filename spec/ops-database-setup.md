# Cloud SQL Database Setup Guide

**Version**: 3.0
**Audience**: Operations (Database Administrators, DevOps Engineers)
**Last Updated**: 2025-12-28
**Status**: Draft

> **See**: prd-architecture-multi-sponsor.md for multi-sponsor deployment architecture
> **See**: dev-database.md for database implementation details
> **See**: ops-database-migration.md for schema migration procedures
> **See**: ops-deployment.md for full deployment workflows
> **See**: ops-infrastructure-as-code.md for Pulumi component details

---

## Executive Summary

Complete guide for deploying the Clinical Trial Diary Database to Google Cloud SQL in a multi-sponsor architecture using **Pulumi** for infrastructure as code. Each sponsor operates an independent GCP project with isolated Cloud SQL instances for complete data isolation.

**Key Principles**:
- **One GCP project per sponsor** - Complete infrastructure isolation
- **Infrastructure as Code** - All resources defined in Pulumi TypeScript
- **Identical core schema** - All sponsors use same base schema from core repository
- **Sponsor-specific extensions** - Each sponsor can add custom tables/functions
- **Independent operations** - Each sponsor has separate credentials, backups, monitoring

**Multi-Sponsor Deployment**:
```
Sponsor A                    Sponsor B                    Sponsor C
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│ GCP Project A       │     │ GCP Project B       │     │ GCP Project C       │
│ - Cloud SQL         │     │ - Cloud SQL         │     │ - Cloud SQL         │
│ - Identity Platform │     │ - Identity Platform │     │ - Identity Platform │
│ - Cloud Run         │     │ - Cloud Run         │     │ - Cloud Run         │
│ - Isolated Backups  │     │ - Isolated Backups  │     │ - Isolated Backups  │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
        │                           │                           │
        └───────────────────────────┴───────────────────────────┘
                      Managed via Pulumi stacks
```

**This Guide Covers**: Setup procedures for a single sponsor's Cloud SQL instance using Pulumi. Repeat these steps for each sponsor with their own GCP project and Pulumi stack.

---

## Prerequisites

1. **GCP Account**
   - Organization or standalone GCP account
   - Billing enabled
   - Appropriate IAM permissions (Cloud SQL Admin, IAM Admin)

2. **Local Tools**
   - **Pulumi** v3.x installed (`brew install pulumi` or npm)
   - **Node.js** v20+ installed
   - `gcloud` CLI installed and configured (for authentication and ad-hoc operations)
   - `cloud_sql_proxy` for local development
   - `psql` PostgreSQL client
   - **Doppler** CLI for secrets management

3. **Pulumi Setup**
   ```bash
   # Install Pulumi
   curl -fsSL https://get.pulumi.com | sh

   # Login to Pulumi backend (choose one)
   pulumi login                              # Pulumi Cloud (recommended)
   pulumi login gs://your-state-bucket       # GCS backend

   # Install project dependencies
   cd infrastructure/pulumi
   npm install
   ```

---

## Multi-Sponsor Setup Context

# REQ-o00003: GCP Project Provisioning Per Sponsor

**Level**: Ops | **Status**: Draft | **Implements**: p00003, o00001

## Rationale

This requirement ensures complete infrastructure isolation for each clinical trial sponsor by provisioning dedicated Google Cloud Platform projects. This implements the database isolation mandate from REQ-p00003 at the infrastructure layer, preventing any cross-sponsor data access or resource sharing. Each GCP project contains its own Cloud SQL database instance, Identity Platform authentication system, and Cloud Run services, ensuring that sponsor data remains completely segregated throughout the technology stack. This approach satisfies both regulatory requirements for data isolation and operational best practices for multi-tenant SaaS deployments in regulated industries.

## Assertions

A. The system SHALL provision a dedicated GCP project for each sponsor for each environment (staging, production).
B. GCP project names SHALL follow the convention: clinical-diary-{sponsor}-{env}.
C. The geographic region for each project SHALL be selected based on the sponsor's user base and data residency requirements.
D. The Cloud SQL tier for each project SHALL be selected based on workload requirements.
E. Project credentials SHALL be stored securely in Doppler.
F. Each sponsor SHALL have a dedicated GCP project that provides isolated Cloud SQL database, Identity Platform authentication, and Cloud Run services.
G. GCP projects SHALL NOT share databases across sponsors.
H. GCP projects SHALL NOT share authentication systems across sponsors.
I. Project credentials SHALL be unique per project.
J. Project credentials SHALL NOT be reused across projects.
K. Staging and production environments SHALL use separate GCP projects.
L. Project provisioning procedures SHALL be documented in a runbook.

*End* *GCP Project Provisioning Per Sponsor* | **Hash**: 7110fea1
---

### Per-Sponsor GCP Projects

**Each sponsor requires**:
1. Dedicated GCP project (within organization or standalone)
2. Unique project ID: `clinical-diary-{sponsor-name}-{env}`
3. Region selection based on sponsor's primary user base and data residency
4. Appropriate Cloud SQL tier based on expected workload

### Project Naming Convention

**Format**: `clinical-diary-{sponsor}-{environment}`

**Examples**:
- `clinical-diary-orion-prod` - Orion production
- `clinical-diary-orion-staging` - Orion staging/UAT
- `clinical-diary-andromeda-prod` - Andromeda production

### Schema Consistency

**All sponsors deploy**:
- Same core schema from `clinical-diary/packages/database/`
- Version-pinned to ensure consistency
- Core schema published as GitHub package

**Sponsor-specific extensions** (optional):
- Additional tables in sponsor repo `database/extensions.sql`
- Custom stored procedures
- Extra indexes for sponsor-specific queries

**See**: dev-database.md for details on core vs sponsor schema

### Credential Management

**Each sponsor has separate**:
- GCP project ID
- Cloud SQL instance connection name
- Database user credentials
- Service account keys (for Cloud Run)

**Security**: Credentials must NEVER be shared between sponsors

**Storage**: Use Doppler per sponsor project/environment

---

# REQ-o00011: Multi-Site Data Configuration Per Sponsor

**Level**: Ops | **Status**: Draft | **Implements**: p70001

## Rationale

This requirement ensures that each sponsor's database is properly configured to support multi-site clinical trials with appropriate data isolation and access controls. Site configuration is a prerequisite operational step that must be completed before trial enrollment begins, establishing the foundation for proper data segregation, role-based access control, and audit trail integrity across geographically distributed trial sites. This implements the multi-sponsor architecture and role-based access control requirements at the operational deployment level.

## Assertions

A. The system SHALL configure each sponsor's database with site data structures to support multi-site clinical trials.
B. The system SHALL populate site records with site metadata including site_id, site_name, site_number, location, and contact information.
C. The system SHALL configure investigator-to-site assignments per trial setup.
D. The system SHALL configure analyst-to-site assignments per sponsor requirements.
E. The system SHALL establish patient-to-site enrollment mappings during enrollment.
F. The system SHALL verify RLS policy configurations for site-based data isolation.
G. Site records SHALL be created for all participating trial sites.
H. Site assignments SHALL be configured for all investigators and analysts.
I. RLS policies SHALL correctly filter data by site.
J. The system SHALL correctly capture site context in audit trail entries.
K. Documentation SHALL exist for adding sites post-deployment.
L. Documentation SHALL exist for removing sites post-deployment.

*End* *Multi-Site Data Configuration Per Sponsor* | **Hash**: 87a63123
---

## Step 1: GCP Project Setup

### Create Project via Pulumi

```typescript
// infrastructure/pulumi/components/sponsor-project/index.ts
import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

const config = new pulumi.Config();
const sponsor = config.require("sponsor");       // e.g., "orion"
const environment = config.require("environment"); // e.g., "prod"
const region = config.get("region") || "us-central1";
const billingAccountId = config.require("billingAccountId");
const orgId = config.get("orgId"); // Optional for org-managed projects

const projectId = `clinical-diary-${sponsor}-${environment}`;

// Create GCP Project
const project = new gcp.organizations.Project("sponsor-project", {
  projectId: projectId,
  name: `Clinical Diary ${sponsor} ${environment}`,
  billingAccount: billingAccountId,
  orgId: orgId,
  labels: {
    sponsor: sponsor,
    environment: environment,
    managed_by: "pulumi",
    compliance: "hipaa-fda",
  },
});

// Enable required APIs
const requiredApis = [
  "sqladmin.googleapis.com",
  "compute.googleapis.com",
  "secretmanager.googleapis.com",
  "run.googleapis.com",
  "identitytoolkit.googleapis.com",
  "servicenetworking.googleapis.com",
  "vpcaccess.googleapis.com",
];

const enabledApis = requiredApis.map((api, index) =>
  new gcp.projects.Service(`api-${index}`, {
    project: project.projectId,
    service: api,
    disableOnDestroy: false,
  }, { dependsOn: [project] })
);

export const gcpProjectId = project.projectId;
export const gcpRegion = region;
```

### Configuration (Pulumi.yaml)

```yaml
# infrastructure/pulumi/sponsors/orion/prod/Pulumi.yaml
name: clinical-diary-orion-prod
runtime: nodejs
config:
  gcp:region: us-central1
  sponsor: orion
  environment: prod
  billingAccountId: BILLING_ACCOUNT_ID
```

### Deploy Project

```bash
cd infrastructure/pulumi/sponsors/orion/prod
npm install
pulumi stack init orion-prod
doppler run -- pulumi up
```

---

## Step 2: Cloud SQL Instance Creation

# REQ-o00004: Database Schema Deployment

**Level**: Ops | **Status**: Draft | **Implements**: p00003, p00004, p00013

## Rationale

This requirement ensures consistent database infrastructure across all sponsor deployments while maintaining the core event sourcing and audit trail capabilities mandated by FDA 21 CFR Part 11. The centralized core schema approach guarantees that all sponsors benefit from security improvements, bug fixes, and performance optimizations while preserving the ability to extend functionality for sponsor-specific needs. Database isolation (p00003) prevents cross-sponsor data contamination, event sourcing (p00004) enables complete audit trails, and change history (p00013) supports regulatory compliance. Automated deployment with validation and rollback capabilities reduces human error and ensures deployment reliability.

## Assertions

A. The system SHALL deploy each sponsor's database with the core schema from the central repository.
B. The deployed schema SHALL include event sourcing tables (record_audit, record_state).
C. The deployed schema SHALL include row-level security policies.
D. The deployed schema SHALL include database triggers for audit trail enforcement.
E. The deployed schema SHALL include indexes for query performance.
F. The system SHALL support optional sponsor-specific schema extensions.
G. Schema deployment SHALL be executed via an automated migration process.
H. The system SHALL track the core schema version for each deployment.
I. Sponsor-specific extensions SHALL be isolated from the core schema.
J. The system SHALL execute schema validation checks before deployment.
K. Schema validation checks SHALL pass before deployment completes.
L. The system SHALL provide rollback capability for failed deployments.

*End* *Database Schema Deployment* | **Hash**: 7ae2ea75
---

### Create Cloud SQL Instance via Pulumi

```typescript
// infrastructure/pulumi/components/cloud-sql/index.ts
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

export class CloudSqlDatabase extends pulumi.ComponentResource {
  public readonly instance: gcp.sql.DatabaseInstance;
  public readonly database: gcp.sql.Database;
  public readonly user: gcp.sql.User;
  public readonly connectionName: pulumi.Output<string>;

  constructor(name: string, args: CloudSqlArgs, opts?: pulumi.ComponentResourceOptions) {
    super("clinical-diary:cloud-sql", name, {}, opts);

    const isProduction = args.environment === "production" || args.environment === "prod";
    const isStaging = args.environment === "staging";

    // Determine tier based on environment
    const tier = isProduction ? "db-custom-2-8192" :
                 isStaging ? "db-custom-1-3840" : "db-f1-micro";

    // Create Cloud SQL instance
    this.instance = new gcp.sql.DatabaseInstance(`${name}-instance`, {
      project: args.projectId,
      region: args.region,
      name: `${args.sponsor}-db`,
      databaseVersion: "POSTGRES_15",
      deletionProtection: isProduction,
      settings: {
        tier: tier,
        availabilityType: isProduction ? "REGIONAL" : "ZONAL",
        diskType: "PD_SSD",
        diskSize: isProduction ? 100 : (isStaging ? 50 : 10),
        diskAutoresize: true,
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
          ipv4Enabled: !isProduction, // Disable public IP in production
          privateNetwork: isProduction ? args.privateNetwork : undefined,
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

    // Create database
    this.database = new gcp.sql.Database(`${name}-database`, {
      project: args.projectId,
      instance: this.instance.name,
      name: "clinical_diary",
      charset: "UTF8",
      collation: "en_US.UTF8",
    }, { parent: this });

    // Create application user (password from Doppler via Pulumi config)
    this.user = new gcp.sql.User(`${name}-user`, {
      project: args.projectId,
      instance: this.instance.name,
      name: "app_user",
      password: args.databasePassword,
    }, { parent: this });

    this.connectionName = this.instance.connectionName;
    this.registerOutputs({
      connectionName: this.connectionName,
      instanceName: this.instance.name,
    });
  }
}
```

### Instance Sizing Guide

| Environment | Tier | vCPUs | Memory | Storage | HA |
| --- | --- | --- | --- | --- | --- |
| Development | db-f1-micro | Shared | 0.6 GB | 10 GB | No |
| Staging | db-custom-1-3840 | 1 | 3.75 GB | 50 GB | No |
| Production | db-custom-2-8192 | 2 | 8 GB | 100 GB | Yes (Regional) |
| Production (Large) | db-custom-4-16384 | 4 | 16 GB | 500 GB | Yes |

### Configure Private IP (VPC Networking) via Pulumi

```typescript
// infrastructure/pulumi/components/vpc-networking/index.ts
import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

export interface VpcNetworkingArgs {
  projectId: pulumi.Input<string>;
  region: string;
}

export class VpcNetworking extends pulumi.ComponentResource {
  public readonly network: gcp.compute.Network;
  public readonly privateIpRange: gcp.compute.GlobalAddress;
  public readonly vpcConnection: gcp.servicenetworking.Connection;
  public readonly networkSelfLink: pulumi.Output<string>;

  constructor(name: string, args: VpcNetworkingArgs, opts?: pulumi.ComponentResourceOptions) {
    super("clinical-diary:vpc-networking", name, {}, opts);

    // Create VPC network
    this.network = new gcp.compute.Network(`${name}-network`, {
      project: args.projectId,
      name: "clinical-diary-vpc",
      autoCreateSubnetworks: false,
    }, { parent: this });

    // Reserve IP range for VPC peering (Cloud SQL private IP)
    this.privateIpRange = new gcp.compute.GlobalAddress(`${name}-private-ip`, {
      project: args.projectId,
      name: "google-managed-services-range",
      purpose: "VPC_PEERING",
      addressType: "INTERNAL",
      prefixLength: 16,
      network: this.network.id,
    }, { parent: this });

    // Create VPC peering connection for Cloud SQL
    this.vpcConnection = new gcp.servicenetworking.Connection(`${name}-vpc-peering`, {
      network: this.network.id,
      service: "servicenetworking.googleapis.com",
      reservedPeeringRanges: [this.privateIpRange.name],
    }, { parent: this });

    this.networkSelfLink = this.network.selfLink;
    this.registerOutputs({
      networkSelfLink: this.networkSelfLink,
    });
  }
}
```

### Set Database Password via Pulumi Config

```bash
# Set the database password as a secret (encrypted in state)
pulumi config set --secret databasePassword "$(openssl rand -base64 32)"

# Or use Doppler for secrets management
# The password will be read from DOPPLER environment at runtime
```

---

## Step 3: Schema Deployment

### Option A: Direct SQL Deployment

```bash
# Connect via Cloud SQL Proxy (for initial setup)
cloud_sql_proxy -instances=$PROJECT_ID:$REGION:${SPONSOR}-db=tcp:5432 &

# Wait for proxy to start
sleep 5

# Set connection string
export PGPASSWORD="$DB_PASSWORD"
export PGHOST="127.0.0.1"
export PGPORT="5432"
export PGUSER="app_user"
export PGDATABASE="clinical_diary"

# Deploy core schema in order
psql -f packages/database/schema.sql
psql -f packages/database/triggers.sql
psql -f packages/database/roles.sql
psql -f packages/database/rls_policies.sql
psql -f packages/database/indexes.sql

# Deploy sponsor-specific extensions (if any)
psql -f sponsor/${SPONSOR}/database/extensions.sql
```

### Option B: Using Migrations (Recommended)

```bash
# Using dbmate or similar migration tool
export DATABASE_URL="postgresql://app_user:${DB_PASSWORD}@127.0.0.1:5432/clinical_diary?sslmode=disable"

# Run migrations
dbmate up

# Verify migrations
dbmate status
```

### Verification

```bash
# Verify core tables deployed
psql -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;"

# Expected tables:
# - admin_action_log
# - investigator_annotations
# - record_audit
# - record_state
# - role_change_log
# - sites
# - sync_conflicts
# - user_profiles
# - user_sessions
```

---

## Step 4: Authentication Setup (Identity Platform)

### Configure Identity Platform via Pulumi

```typescript
// infrastructure/pulumi/components/identity-platform/index.ts
import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

export interface IdentityPlatformArgs {
  projectId: pulumi.Input<string>;
  sponsor: string;
  environment: string;
  googleOAuthClientId?: pulumi.Input<string>;
  googleOAuthClientSecret?: pulumi.Input<string>;
  customDomain?: string;
}

export class IdentityPlatform extends pulumi.ComponentResource {
  public readonly config: gcp.identityplatform.Config;

  constructor(name: string, args: IdentityPlatformArgs, opts?: pulumi.ComponentResourceOptions) {
    super("clinical-diary:identity-platform", name, {}, opts);

    const isProduction = args.environment === "production" || args.environment === "prod";

    // Configure Identity Platform
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

    // Google OAuth provider (if credentials provided)
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

### Configure OAuth Providers

OAuth providers can be configured via Pulumi or the GCP Console:

1. **Email/Password**: Enabled by default in Pulumi config above
2. **Google OAuth**: Pass `googleOAuthClientId` and `googleOAuthClientSecret` to Pulumi
3. **Apple Sign-In**: Requires Apple Developer account, configure via console
4. **Microsoft OAuth**: Register app in Azure AD, configure via console

### Custom Claims for RBAC

Custom claims are managed via Dart server endpoints on Cloud Run:

```dart
// lib/services/custom_claims_service.dart
import 'package:firebase_admin/firebase_admin.dart';

class CustomClaimsService {
  final FirebaseApp _firebaseApp;
  final String _sponsorId;

  CustomClaimsService(this._firebaseApp, this._sponsorId);

  /// Initialize claims for new user (called during registration)
  Future<void> initializeUserClaims(String uid) async {
    const defaultRole = 'USER';

    await _firebaseApp.auth().setCustomUserClaims(uid, {
      'role': defaultRole,
      'sponsorId': _sponsorId,
    });

    print('Custom claims set for user $uid: role=$defaultRole');
  }

  /// Update user role (admin only)
  Future<Map<String, dynamic>> updateUserRole({
    required String adminRole,
    required String userId,
    required String newRole,
  }) async {
    if (adminRole != 'ADMIN') {
      throw Exception('Permission denied: Must be admin');
    }

    const validRoles = ['USER', 'INVESTIGATOR', 'ANALYST', 'ADMIN'];
    if (!validRoles.contains(newRole)) {
      throw Exception('Invalid role: $newRole');
    }

    final userRecord = await _firebaseApp.auth().getUser(userId);
    final currentClaims = userRecord.customClaims ?? {};

    await _firebaseApp.auth().setCustomUserClaims(userId, {
      ...currentClaims,
      'role': newRole,
    });

    return {'success': true, 'newRole': newRole};
  }
}
```

### Deploy Cloud Run API Server via Pulumi

```typescript
// infrastructure/pulumi/components/cloud-run/index.ts
import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

export interface CloudRunArgs {
  projectId: pulumi.Input<string>;
  region: string;
  sponsor: string;
  environment: string;
  imageTag: string;
  serviceAccountEmail: pulumi.Input<string>;
  vpcConnectorId?: pulumi.Input<string>;
  cloudSqlConnectionName: pulumi.Input<string>;
}

export class CloudRunService extends pulumi.ComponentResource {
  public readonly service: gcp.cloudrunv2.Service;
  public readonly serviceUrl: pulumi.Output<string>;

  constructor(name: string, args: CloudRunArgs, opts?: pulumi.ComponentResourceOptions) {
    super("clinical-diary:cloud-run", name, {}, opts);

    const isProduction = args.environment === "production" || args.environment === "prod";

    this.service = new gcp.cloudrunv2.Service(`${name}-service`, {
      project: args.projectId,
      location: args.region,
      name: "api-server",
      template: {
        serviceAccount: args.serviceAccountEmail,
        vpcAccess: args.vpcConnectorId ? {
          connector: args.vpcConnectorId,
          egress: "PRIVATE_RANGES_ONLY",
        } : undefined,
        scaling: {
          minInstanceCount: isProduction ? 1 : 0,
          maxInstanceCount: isProduction ? 10 : 3,
        },
        containers: [{
          image: pulumi.interpolate`gcr.io/${args.projectId}/api-server:${args.imageTag}`,
          resources: {
            limits: {
              cpu: "1000m",
              memory: "512Mi",
            },
          },
          envs: [
            { name: "SPONSOR_ID", value: args.sponsor },
            { name: "ENVIRONMENT", value: args.environment },
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

### Build and Push Docker Image

```bash
# Build and push the API server image (CI/CD typically handles this)
docker build -t gcr.io/${PROJECT_ID}/api-server:${IMAGE_TAG} .
docker push gcr.io/${PROJECT_ID}/api-server:${IMAGE_TAG}

# Then deploy via Pulumi
doppler run -- pulumi up
```

---

## Step 5: RLS Configuration

### Set Up Session Variables for RLS

RLS policies use session variables set by the application. Configure the application connection to set these:

```dart
// In Dart server (Cloud Run)
Future<Connection> getConnection() async {
  final conn = await Connection.open(
    Endpoint(
      host: '/cloudsql/$instanceConnectionName',
      database: 'clinical_diary',
      username: 'app_user',
      password: databasePassword,
    ),
    settings: ConnectionSettings(
      sslMode: SslMode.disable, // Unix socket doesn't use SSL
    ),
  );

  // Set session variables for RLS
  await conn.execute('''
    SET app.current_user_id = '${currentUserId}';
    SET app.current_user_role = '${currentUserRole}';
    SET app.current_site_id = '${currentSiteId}';
  ''');

  return conn;
}
```

### Verify RLS Policies

```sql
-- Verify RLS is enabled on all tables
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename NOT LIKE 'pg_%';

-- Test RLS as different users
SET app.current_user_id = 'user_123';
SET app.current_user_role = 'USER';
SELECT COUNT(*) FROM record_state; -- Should only see own data

SET app.current_user_role = 'ADMIN';
SELECT COUNT(*) FROM record_state; -- Should see all data
```

---

## Step 6: Service Account Setup

### Create Service Account for Cloud Run via Pulumi

```typescript
// infrastructure/pulumi/components/service-accounts/index.ts
import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

export interface ServiceAccountsArgs {
  projectId: pulumi.Input<string>;
}

export class ServiceAccounts extends pulumi.ComponentResource {
  public readonly cloudRunServiceAccount: gcp.serviceaccount.Account;
  public readonly cloudRunServiceAccountEmail: pulumi.Output<string>;

  constructor(name: string, args: ServiceAccountsArgs, opts?: pulumi.ComponentResourceOptions) {
    super("clinical-diary:service-accounts", name, {}, opts);

    // Create service account for Cloud Run
    this.cloudRunServiceAccount = new gcp.serviceaccount.Account(`${name}-cloud-run-sa`, {
      project: args.projectId,
      accountId: "clinical-diary-server",
      displayName: "Clinical Diary Server",
    }, { parent: this });

    // Grant Cloud SQL Client role
    new gcp.projects.IAMMember(`${name}-cloudsql-client`, {
      project: args.projectId,
      role: "roles/cloudsql.client",
      member: pulumi.interpolate`serviceAccount:${this.cloudRunServiceAccount.email}`,
    }, { parent: this });

    // Grant Secret Manager access
    new gcp.projects.IAMMember(`${name}-secretmanager-accessor`, {
      project: args.projectId,
      role: "roles/secretmanager.secretAccessor",
      member: pulumi.interpolate`serviceAccount:${this.cloudRunServiceAccount.email}`,
    }, { parent: this });

    // Grant Identity Platform Admin (for custom claims)
    new gcp.projects.IAMMember(`${name}-firebase-admin`, {
      project: args.projectId,
      role: "roles/firebaseauth.admin",
      member: pulumi.interpolate`serviceAccount:${this.cloudRunServiceAccount.email}`,
    }, { parent: this });

    this.cloudRunServiceAccountEmail = this.cloudRunServiceAccount.email;
    this.registerOutputs({
      serviceAccountEmail: this.cloudRunServiceAccountEmail,
    });
  }
}
```

---

## Step 7: Backup Configuration

### Automated Backups via Pulumi

Backup configuration is included in the Cloud SQL instance definition (see Step 2). Key settings:

```typescript
// Backup configuration in CloudSqlDatabase component
backupConfiguration: {
  enabled: true,
  startTime: "02:00",
  pointInTimeRecoveryEnabled: true,
  backupRetentionSettings: {
    retainedBackups: isProduction ? 30 : 7,
    retentionUnit: "COUNT",
  },
},
```

### Long-term Backup Storage via Pulumi

```typescript
// infrastructure/pulumi/components/backup-storage/index.ts
import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

export interface BackupStorageArgs {
  projectId: pulumi.Input<string>;
  region: string;
  sponsor: string;
}

export class BackupStorage extends pulumi.ComponentResource {
  public readonly bucket: gcp.storage.Bucket;
  public readonly bucketName: pulumi.Output<string>;

  constructor(name: string, args: BackupStorageArgs, opts?: pulumi.ComponentResourceOptions) {
    super("clinical-diary:backup-storage", name, {}, opts);

    // Create storage bucket for long-term backups
    this.bucket = new gcp.storage.Bucket(`${name}-backup-bucket`, {
      project: args.projectId,
      name: pulumi.interpolate`${args.projectId}-backups`,
      location: args.region,
      storageClass: "NEARLINE", // Cost-effective for backups
      uniformBucketLevelAccess: true,
      versioning: { enabled: true },
      lifecycleRules: [
        {
          action: { type: "Delete" },
          condition: { age: 365 }, // Delete after 1 year
        },
        {
          action: { type: "SetStorageClass", storageClass: "COLDLINE" },
          condition: { age: 90 }, // Move to coldline after 90 days
        },
      ],
      labels: {
        sponsor: args.sponsor,
        purpose: "database-backups",
        managed_by: "pulumi",
      },
    }, { parent: this });

    this.bucketName = this.bucket.name;
    this.registerOutputs({ bucketName: this.bucketName });
  }
}
```

### Manual Backup Operations

For ad-hoc backups and exports, use `gcloud` CLI (these are operational tasks, not infrastructure):

```bash
# Create on-demand backup
gcloud sql backups create \
  --instance="${SPONSOR}-db" \
  --description="Manual backup before migration"

# List backups
gcloud sql backups list --instance="${SPONSOR}-db"

# Export database to Cloud Storage
gcloud sql export sql "${SPONSOR}-db" \
  gs://${PROJECT_ID}-backups/backup-$(date +%Y%m%d).sql \
  --database=clinical_diary
```

### Point-in-Time Recovery

PITR is enabled automatically in the Pulumi configuration. To restore to a specific point:

```bash
# Restore to specific timestamp
gcloud sql instances clone "${SPONSOR}-db" "${SPONSOR}-db-restored" \
  --point-in-time="2025-01-15T10:30:00.000Z"
```

---

## Step 8: Monitoring Setup

### Cloud SQL Insights via Pulumi

Query insights are configured as part of the Cloud SQL instance:

```typescript
// Add to CloudSqlDatabase component settings
settings: {
  // ... other settings
  insightsConfig: {
    queryInsightsEnabled: true,
    queryStringLength: 4096,
    recordApplicationTags: true,
    recordClientAddress: true,
  },
}
```

### Create Monitoring Alerts via Pulumi

```typescript
// infrastructure/pulumi/components/monitoring/index.ts
import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

export interface MonitoringArgs {
  projectId: pulumi.Input<string>;
  sponsor: string;
  notificationChannels: pulumi.Input<string>[];
}

export class DatabaseMonitoring extends pulumi.ComponentResource {
  constructor(name: string, args: MonitoringArgs, opts?: pulumi.ComponentResourceOptions) {
    super("clinical-diary:monitoring", name, {}, opts);

    // Alert on high CPU utilization
    new gcp.monitoring.AlertPolicy(`${name}-cpu-alert`, {
      project: args.projectId,
      displayName: `Cloud SQL High CPU - ${args.sponsor}`,
      combiner: "OR",
      conditions: [{
        displayName: "CPU utilization > 80%",
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
      alertStrategy: {
        autoClose: "604800s", // Auto-close after 7 days
      },
    }, { parent: this });

    // Alert on high storage utilization
    new gcp.monitoring.AlertPolicy(`${name}-storage-alert`, {
      project: args.projectId,
      displayName: `Cloud SQL Storage Alert - ${args.sponsor}`,
      combiner: "OR",
      conditions: [{
        displayName: "Disk utilization > 80%",
        conditionThreshold: {
          filter: 'resource.type="cloudsql_database" AND metric.type="cloudsql.googleapis.com/database/disk/utilization"',
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

    // Alert on high memory utilization
    new gcp.monitoring.AlertPolicy(`${name}-memory-alert`, {
      project: args.projectId,
      displayName: `Cloud SQL Memory Alert - ${args.sponsor}`,
      combiner: "OR",
      conditions: [{
        displayName: "Memory utilization > 90%",
        conditionThreshold: {
          filter: 'resource.type="cloudsql_database" AND metric.type="cloudsql.googleapis.com/database/memory/utilization"',
          comparison: "COMPARISON_GT",
          thresholdValue: 0.9,
          duration: "300s",
          aggregations: [{
            alignmentPeriod: "60s",
            perSeriesAligner: "ALIGN_MEAN",
          }],
        },
      }],
      notificationChannels: args.notificationChannels,
    }, { parent: this });

    // Alert on connection count
    new gcp.monitoring.AlertPolicy(`${name}-connections-alert`, {
      project: args.projectId,
      displayName: `Cloud SQL Connection Alert - ${args.sponsor}`,
      combiner: "OR",
      conditions: [{
        displayName: "Connection count > 80% of max",
        conditionThreshold: {
          filter: 'resource.type="cloudsql_database" AND metric.type="cloudsql.googleapis.com/database/network/connections"',
          comparison: "COMPARISON_GT",
          thresholdValue: 80, // Adjust based on instance tier
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

### Create Notification Channel via Pulumi

```typescript
// Create email notification channel
const emailChannel = new gcp.monitoring.NotificationChannel("email-alerts", {
  project: projectId,
  displayName: "Database Alerts Email",
  type: "email",
  labels: {
    email_address: config.require("alertEmail"),
  },
});

// Use in monitoring component
const monitoring = new DatabaseMonitoring("db-monitoring", {
  projectId: project.projectId,
  sponsor: sponsor,
  notificationChannels: [emailChannel.name],
});
```

---

## Step 9: Performance Optimization

### Connection Pooling

For Cloud Run, use the Cloud SQL connector with connection pooling:

```dart
// Use postgres connection pool
import 'package:postgres_pool/postgres_pool.dart';

final pool = PgPool(
  PgEndpoint(
    host: '/cloudsql/$instanceConnectionName',
    database: 'clinical_diary',
    username: 'app_user',
    password: databasePassword,
  ),
  settings: PgPoolSettings(
    maxConnectionCount: 10,
    maxConnectionAge: Duration(minutes: 30),
  ),
);
```

### Index Monitoring

```sql
-- Check index usage
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan as scans,
  idx_tup_read as tuples_read
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan ASC;

-- Unused indexes (consider removing)
SELECT
  schemaname,
  tablename,
  indexname
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname = 'public';
```

---

## Step 10: Testing

### Connection Test

```bash
# Test connection via Cloud SQL Proxy
cloud_sql_proxy -instances=$PROJECT_ID:$REGION:${SPONSOR}-db=tcp:5432 &
sleep 5

psql -h 127.0.0.1 -U app_user -d clinical_diary -c "SELECT version();"
```

### RLS Test

```sql
-- Test as USER role
SET app.current_user_id = 'test_user_123';
SET app.current_user_role = 'USER';

-- Should only see own data
SELECT COUNT(*) FROM record_state;

-- Test as ADMIN role
SET app.current_user_role = 'ADMIN';

-- Should see all data
SELECT COUNT(*) FROM record_state;
```

### Audit Trail Test

```sql
-- Create test entry
INSERT INTO record_audit (
  event_uuid, patient_id, site_id, operation, data,
  created_by, role, client_timestamp, change_reason
) VALUES (
  gen_random_uuid(), 'test_patient', 'site_001', 'USER_CREATE',
  '{"event_type": "test", "date": "2025-01-15"}'::jsonb,
  'test_user', 'USER', now(), 'Test entry'
);

-- Verify state table updated
SELECT * FROM record_state WHERE patient_id = 'test_patient';

-- Verify audit hash generated
SELECT event_uuid, record_hash FROM record_audit
WHERE patient_id = 'test_patient';
```

---

## Production Checklist

Before going live:

**Infrastructure (via Pulumi)**:
- [ ] Pulumi stack created for sponsor/environment
- [ ] GCP project provisioned via Pulumi
- [ ] Cloud SQL instance created with appropriate tier
- [ ] VPC networking configured (private IP for production)
- [ ] Service accounts created with minimal permissions
- [ ] Identity Platform configured
- [ ] Cloud Run service deployed
- [ ] Backup storage bucket created
- [ ] Monitoring alerts configured

**Database**:
- [ ] Database and user created
- [ ] Schema deployed via migrations
- [ ] RLS policies verified
- [ ] Connection pooling configured

**Security**:
- [ ] SSL/TLS enforced (automatic for Cloud SQL)
- [ ] Credentials stored in Doppler
- [ ] Pulumi secrets configured for sensitive values

**Validation**:
- [ ] `pulumi preview` shows no unexpected changes
- [ ] Load testing completed
- [ ] Documentation reviewed
- [ ] Incident response plan ready

**Deploy Command**:
```bash
cd infrastructure/pulumi/sponsors/${SPONSOR}/${ENV}
doppler run -- pulumi up
```

---

## Common Issues and Solutions

### Issue: Connection refused

**Solution**: Ensure Cloud SQL Proxy is running or use proper connection string:
```bash
# Start Cloud SQL Proxy
cloud_sql_proxy -instances=$PROJECT_ID:$REGION:${SPONSOR}-db=tcp:5432

# Or use Unix socket in Cloud Run
DATABASE_URL="postgresql://user:pass@/dbname?host=/cloudsql/project:region:instance"
```

### Issue: Permission denied for RLS

**Solution**: Ensure session variables are set before queries:
```sql
SET app.current_user_id = 'user_123';
SET app.current_user_role = 'USER';
```

### Issue: Too many connections

**Solution**:
- Use connection pooling in application
- Increase Cloud SQL tier
- Check for connection leaks

### Issue: Slow queries

**Solution**:
- Enable Cloud SQL Insights
- Check indexes: `EXPLAIN ANALYZE your_query`
- Run `ANALYZE` on tables
- Consider upgrading instance tier

---

## Next Steps

**After Initial Setup**:

1. **Review Architecture**: Read prd-architecture-multi-sponsor.md for complete multi-sponsor architecture
2. **Implementation Details**: Review dev-database.md for schema details and Event Sourcing pattern
3. **Deploy Backend**: Follow ops-deployment.md to deploy Cloud Run server
4. **Configure Monitoring**: Set up dashboards and alerts per ops-monitoring-observability.md
5. **Migration Strategy**: Review ops-database-migration.md for schema update procedures

**For Additional Sponsors**:
- Repeat this entire guide with new GCP project
- Use same core schema version for consistency
- Maintain separate credentials and configurations

---

## References

- **Multi-Sponsor Architecture**: prd-architecture-multi-sponsor.md
- **Database Implementation**: dev-database.md
- **Database Migrations**: ops-database-migration.md
- **Deployment Procedures**: ops-deployment.md
- **Daily Operations**: ops-operations.md
- **Security Operations**: ops-security.md

---

## Support

**GCP Platform**:
- Cloud SQL Docs: https://cloud.google.com/sql/docs
- Identity Platform: https://cloud.google.com/identity-platform/docs
- Cloud Run: https://cloud.google.com/run/docs

**Diary Platform**:
- Review spec/ directory for architecture and implementation details
- Contact platform team for architecture questions
- Refer to ops-operations.md for incident response procedures

---

**Document Status**: Active setup guide
**Review Cycle**: Quarterly or when GCP platform changes
**Owner**: Database Team / DevOps
