# Cloud SQL Database Setup Guide

**Version**: 2.0
**Audience**: Operations (Database Administrators, DevOps Engineers)
**Last Updated**: 2025-11-24
**Status**: Active

> **See**: prd-architecture-multi-sponsor.md for multi-sponsor deployment architecture
> **See**: dev-database.md for database implementation details
> **See**: ops-database-migration.md for schema migration procedures
> **See**: ops-deployment.md for full deployment workflows

---

## Executive Summary

Complete guide for deploying the Clinical Trial Diary Database to Google Cloud SQL in a multi-sponsor architecture. Each sponsor operates an independent GCP project with isolated Cloud SQL instances for complete data isolation.

**Key Principles**:
- **One GCP project per sponsor** - Complete infrastructure isolation
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
```

**This Guide Covers**: Setup procedures for a single sponsor's Cloud SQL instance. Repeat these steps for each sponsor with their own GCP project.

---

## Prerequisites

1. **GCP Account**
   - Organization or standalone GCP account
   - Billing enabled
   - Appropriate IAM permissions (Cloud SQL Admin, IAM Admin)

2. **GCP Project Created**
   - Create a new project per sponsor
   - Enable required APIs (Cloud SQL, Compute Engine, Secret Manager)
   - Note project ID

3. **Local Tools**
   - `gcloud` CLI installed and configured
   - `cloud_sql_proxy` for local development
   - `psql` PostgreSQL client
   - Terraform (optional, for IaC)

---

## Multi-Sponsor Setup Context

# REQ-o00003: GCP Project Provisioning Per Sponsor

**Level**: Ops | **Implements**: p00003, o00001 | **Status**: Active

Each sponsor SHALL be provisioned with a dedicated GCP project for their environments (staging, production), ensuring complete database infrastructure isolation.

Provisioning SHALL include:
- Unique GCP project created per sponsor per environment
- Project naming follows convention: `clinical-diary-{sponsor}-{env}`
- Geographic region selected based on sponsor's user base and data residency requirements
- Appropriate Cloud SQL tier selected based on workload
- Project credentials stored securely in Doppler

**Rationale**: Implements database isolation requirement (p00003) at the infrastructure provisioning level. Each GCP project provides isolated Cloud SQL database, Identity Platform authentication, and Cloud Run services.

**Acceptance Criteria**:
- Each sponsor has dedicated GCP project
- Projects cannot share databases or authentication systems
- Credentials unique per project and never reused
- Project provisioning documented in runbook
- Staging and production use separate projects

*End* *GCP Project Provisioning Per Sponsor* | **Hash**: 10544ffd
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

## Step 1: GCP Project Setup

### Create Project

```bash
# Set variables
export SPONSOR="orion"
export ENV="prod"
export PROJECT_ID="clinical-diary-${SPONSOR}-${ENV}"
export REGION="us-central1"

# Create project (requires org admin or standalone)
gcloud projects create $PROJECT_ID --name="Clinical Diary ${SPONSOR} ${ENV}"

# Set as active project
gcloud config set project $PROJECT_ID

# Link billing account
gcloud billing projects link $PROJECT_ID --billing-account=BILLING_ACCOUNT_ID

# Enable required APIs
gcloud services enable sqladmin.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable identitytoolkit.googleapis.com
```

---

## Step 2: Cloud SQL Instance Creation

# REQ-o00004: Database Schema Deployment

**Level**: Ops | **Implements**: p00003, p00004, p00013 | **Status**: Active

Each sponsor's database SHALL be deployed with the core schema supporting event sourcing, audit trails, and complete change history, ensuring consistent implementation across all sponsors.

Schema deployment SHALL include:
- Core schema from central repository (versioned)
- Event sourcing tables (record_audit, record_state)
- Row-level security policies
- Database triggers for audit trail enforcement
- Indexes for query performance
- Optional sponsor-specific extensions

**Rationale**: Implements database isolation (p00003), event sourcing (p00004), and change history (p00013) through consistent schema deployment. Centralized core schema ensures all sponsors benefit from improvements while allowing sponsor-specific customizations.

**Acceptance Criteria**:
- Schema deployed via automated migration process
- Core schema version tracked per deployment
- Sponsor extensions isolated from core schema
- Schema validation checks pass before deployment
- Rollback capability for failed deployments

*End* *Database Schema Deployment* | **Hash**: b9f6a0b5
---

### Create Cloud SQL Instance

```bash
# Create Cloud SQL instance
gcloud sql instances create "${SPONSOR}-db" \
  --project=$PROJECT_ID \
  --database-version=POSTGRES_15 \
  --tier=db-custom-2-8192 \
  --region=$REGION \
  --storage-type=SSD \
  --storage-size=100GB \
  --storage-auto-increase \
  --availability-type=REGIONAL \
  --backup-start-time=02:00 \
  --enable-point-in-time-recovery \
  --maintenance-window-day=SUN \
  --maintenance-window-hour=03 \
  --database-flags=cloudsql.enable_pgaudit=on \
  --root-password=$(openssl rand -base64 32)

# Note: Store root password in Doppler immediately!
```

### Instance Sizing Guide

| Environment | Tier | vCPUs | Memory | Storage | HA |
| --- | --- | --- | --- | --- | --- |
| Development | db-f1-micro | Shared | 0.6 GB | 10 GB | No |
| Staging | db-custom-1-3840 | 1 | 3.75 GB | 50 GB | No |
| Production | db-custom-2-8192 | 2 | 8 GB | 100 GB | Yes (Regional) |
| Production (Large) | db-custom-4-16384 | 4 | 16 GB | 500 GB | Yes |

### Create Database and User

```bash
# Create clinical diary database
gcloud sql databases create clinical_diary \
  --instance="${SPONSOR}-db" \
  --charset=UTF8 \
  --collation=en_US.UTF8

# Generate secure password
DB_PASSWORD=$(openssl rand -base64 32)

# Create application user
gcloud sql users create app_user \
  --instance="${SPONSOR}-db" \
  --password="$DB_PASSWORD"

# Store password in Doppler
echo "Store this password in Doppler as DATABASE_PASSWORD: $DB_PASSWORD"
```

### Configure Private IP (Recommended for Production)

```bash
# Reserve IP range for VPC peering
gcloud compute addresses create google-managed-services-default \
  --global \
  --purpose=VPC_PEERING \
  --prefix-length=16 \
  --network=default

# Create VPC peering connection
gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=google-managed-services-default \
  --network=default

# Update instance to use private IP
gcloud sql instances patch "${SPONSOR}-db" \
  --network=default \
  --no-assign-ip
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

### Enable Identity Platform

```bash
# Enable Identity Platform API
gcloud services enable identitytoolkit.googleapis.com

# Configure Identity Platform (via console or Terraform)
# Console: https://console.cloud.google.com/customer-identity
```

### Configure OAuth Providers

1. Navigate to **Identity Platform** in GCP Console
2. Go to **Providers** tab
3. Enable required providers:
   - Email/Password
   - Google OAuth
   - Apple Sign-In (requires Apple Developer account)
   - Microsoft OAuth

### Custom Claims for RBAC

Create a Cloud Function to add custom claims to JWT tokens:

```javascript
// functions/customClaims/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.addCustomClaims = functions.auth.user().onCreate(async (user) => {
  // Default role for new users
  const defaultRole = 'USER';

  try {
    await admin.auth().setCustomUserClaims(user.uid, {
      role: defaultRole,
      sponsorId: process.env.SPONSOR_ID,
    });

    console.log(`Custom claims set for user ${user.uid}`);
  } catch (error) {
    console.error('Error setting custom claims:', error);
  }
});

// Function to update role (called by admin)
exports.updateUserRole = functions.https.onCall(async (data, context) => {
  // Verify caller is admin
  if (!context.auth?.token?.role || context.auth.token.role !== 'ADMIN') {
    throw new functions.https.HttpsError('permission-denied', 'Must be admin');
  }

  const { userId, newRole } = data;
  const validRoles = ['USER', 'INVESTIGATOR', 'ANALYST', 'ADMIN'];

  if (!validRoles.includes(newRole)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid role');
  }

  await admin.auth().setCustomUserClaims(userId, {
    ...context.auth.token,
    role: newRole,
  });

  return { success: true };
});
```

Deploy the function:

```bash
cd functions/customClaims
gcloud functions deploy addCustomClaims \
  --runtime=nodejs18 \
  --trigger-event=providers/firebase.auth/eventTypes/user.create \
  --region=$REGION \
  --set-env-vars=SPONSOR_ID=$SPONSOR
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

### Create Service Account for Cloud Run

```bash
# Create service account
gcloud iam service-accounts create clinical-diary-server \
  --display-name="Clinical Diary Server"

# Grant Cloud SQL Client role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:clinical-diary-server@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

# Grant Secret Manager access
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:clinical-diary-server@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

---

## Step 7: Backup Configuration

### Automated Backups

Cloud SQL provides automated daily backups:

```bash
# Verify backup configuration
gcloud sql instances describe "${SPONSOR}-db" \
  --format="get(settings.backupConfiguration)"

# Configure retention (7 days default, up to 365)
gcloud sql instances patch "${SPONSOR}-db" \
  --backup-retention-count=30
```

### Point-in-Time Recovery

```bash
# Verify PITR is enabled
gcloud sql instances describe "${SPONSOR}-db" \
  --format="get(settings.backupConfiguration.pointInTimeRecoveryEnabled)"

# PITR retention: 7 days (automatic)
```

### Manual Backup

```bash
# Create on-demand backup
gcloud sql backups create \
  --instance="${SPONSOR}-db" \
  --description="Manual backup before migration"

# List backups
gcloud sql backups list --instance="${SPONSOR}-db"
```

### Export to Cloud Storage (Long-term Retention)

```bash
# Create storage bucket for backups
gsutil mb -l $REGION gs://${PROJECT_ID}-backups

# Export database to Cloud Storage
gcloud sql export sql "${SPONSOR}-db" \
  gs://${PROJECT_ID}-backups/backup-$(date +%Y%m%d).sql \
  --database=clinical_diary
```

---

## Step 8: Monitoring Setup

### Enable Cloud SQL Insights

```bash
# Enable query insights
gcloud sql instances patch "${SPONSOR}-db" \
  --insights-config-query-insights-enabled \
  --insights-config-query-string-length=4096 \
  --insights-config-record-application-tags \
  --insights-config-record-client-address
```

### Create Monitoring Alerts

```bash
# Alert on high CPU
gcloud monitoring alert-policies create \
  --display-name="Cloud SQL High CPU" \
  --condition-filter='resource.type="cloudsql_database" AND metric.type="cloudsql.googleapis.com/database/cpu/utilization"' \
  --condition-threshold-value=0.8 \
  --condition-threshold-comparison=COMPARISON_GT \
  --notification-channels=CHANNEL_ID

# Alert on storage usage
gcloud monitoring alert-policies create \
  --display-name="Cloud SQL Storage Alert" \
  --condition-filter='resource.type="cloudsql_database" AND metric.type="cloudsql.googleapis.com/database/disk/utilization"' \
  --condition-threshold-value=0.8 \
  --condition-threshold-comparison=COMPARISON_GT \
  --notification-channels=CHANNEL_ID
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

- [ ] Cloud SQL instance created with appropriate tier
- [ ] Database and user created
- [ ] Schema deployed via migrations
- [ ] RLS policies verified
- [ ] Identity Platform configured
- [ ] Custom claims function deployed
- [ ] Service account created with minimal permissions
- [ ] Backup configuration verified (daily + PITR)
- [ ] Connection pooling configured
- [ ] Monitoring alerts configured
- [ ] SSL/TLS enforced (automatic for Cloud SQL)
- [ ] Credentials stored in Doppler
- [ ] VPC peering configured (production)
- [ ] Load testing completed
- [ ] Documentation reviewed
- [ ] Incident response plan ready

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

**Clinical Diary System**:
- Review spec/ directory for architecture and implementation details
- Contact platform team for architecture questions
- Refer to ops-operations.md for incident response procedures

---

**Document Status**: Active setup guide
**Review Cycle**: Quarterly or when GCP platform changes
**Owner**: Database Team / DevOps
