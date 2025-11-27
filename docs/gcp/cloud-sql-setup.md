# Cloud SQL Setup Guide

**Version**: 1.0
**Status**: Active
**Created**: 2025-11-25

> **Purpose**: Step-by-step guide for provisioning and configuring Cloud SQL PostgreSQL instances for the Clinical Trial Diary Platform.

---

## Executive Summary

Each sponsor's Clinical Trial Diary deployment uses a dedicated Cloud SQL PostgreSQL instance within their isolated GCP project. This guide covers provisioning, configuration, security, and maintenance procedures.

**Key Features**:
- PostgreSQL 15 (latest stable)
- High Availability for production
- Private IP with VPC peering
- Automated backups with point-in-time recovery
- Event sourcing schema with RLS policies

---

## Prerequisites

Before starting, ensure:

1. **GCP Project Created**: See docs/gcp/project-structure.md
2. **APIs Enabled**:
   ```bash
   gcloud services enable sqladmin.googleapis.com
   gcloud services enable compute.googleapis.com
   gcloud services enable servicenetworking.googleapis.com
   ```
3. **IAM Permissions**: `roles/cloudsql.admin` or `roles/owner`
4. **Tools Installed**:
   - `gcloud` CLI
   - `psql` (PostgreSQL client)
   - Cloud SQL Auth Proxy

---

## Instance Provisioning

### Step 1: Configure Variables

```bash
# Sponsor and environment
export SPONSOR="orion"
export ENV="prod"
export PROJECT_ID="hht-diary-${SPONSOR}-${ENV}"
export REGION="europe-west1"  # EU region for GDPR compliance

# Instance naming
export INSTANCE_NAME="${SPONSOR}-db-${ENV}"
export DATABASE_NAME="clinical_diary"

# Set project
gcloud config set project $PROJECT_ID
```

### Step 2: Create Private IP Range

Cloud SQL requires VPC peering for private connectivity:

```bash
# Reserve IP range for private services
gcloud compute addresses create google-managed-services-default \
  --global \
  --purpose=VPC_PEERING \
  --prefix-length=16 \
  --network=default \
  --project=$PROJECT_ID

# Create private connection
gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=google-managed-services-default \
  --network=default \
  --project=$PROJECT_ID
```

### Step 3: Create Cloud SQL Instance

#### Production Configuration

```bash
# Generate secure root password
ROOT_PASSWORD=$(openssl rand -base64 32)
echo "Root password (save to Secret Manager): $ROOT_PASSWORD"

# Create instance
gcloud sql instances create $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --database-version=POSTGRES_15 \
  --tier=db-custom-2-8192 \
  --region=$REGION \
  --availability-type=REGIONAL \
  --storage-type=SSD \
  --storage-size=100GB \
  --storage-auto-increase \
  --backup-start-time=02:00 \
  --enable-point-in-time-recovery \
  --maintenance-window-day=SUN \
  --maintenance-window-hour=03 \
  --database-flags=\
cloudsql.enable_pgaudit=on,\
log_checkpoints=on,\
log_connections=on,\
log_disconnections=on,\
log_lock_waits=on,\
log_temp_files=0 \
  --network=default \
  --no-assign-ip \
  --root-password="$ROOT_PASSWORD"
```

#### Staging Configuration

```bash
gcloud sql instances create $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --database-version=POSTGRES_15 \
  --tier=db-custom-1-3840 \
  --region=$REGION \
  --availability-type=ZONAL \
  --storage-type=SSD \
  --storage-size=50GB \
  --storage-auto-increase \
  --backup-start-time=02:00 \
  --enable-point-in-time-recovery \
  --network=default \
  --no-assign-ip \
  --root-password="$ROOT_PASSWORD"
```

#### Development Configuration

```bash
gcloud sql instances create $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=$REGION \
  --availability-type=ZONAL \
  --storage-type=HDD \
  --storage-size=10GB \
  --root-password="$ROOT_PASSWORD"
```

### Instance Sizing Reference

| Environment | Tier | vCPUs | Memory | Storage | HA |
| --- | --- | --- | --- | --- | --- |
| Development | db-f1-micro | Shared | 0.6 GB | 10 GB HDD | No |
| Staging | db-custom-1-3840 | 1 | 3.75 GB | 50 GB SSD | No |
| Production | db-custom-2-8192 | 2 | 8 GB | 100 GB SSD | Yes |
| Production (Large) | db-custom-4-16384 | 4 | 16 GB | 500 GB SSD | Yes |

---

## Database Configuration

### Step 4: Create Database

```bash
gcloud sql databases create $DATABASE_NAME \
  --instance=$INSTANCE_NAME \
  --charset=UTF8 \
  --collation=en_US.UTF8 \
  --project=$PROJECT_ID
```

### Step 5: Create Application User

```bash
# Generate application password
APP_PASSWORD=$(openssl rand -base64 32)
echo "App password (save to Secret Manager): $APP_PASSWORD"

# Create user
gcloud sql users create app_user \
  --instance=$INSTANCE_NAME \
  --password="$APP_PASSWORD" \
  --project=$PROJECT_ID
```

### Step 6: Store Credentials in Secret Manager

```bash
# Store root password
echo -n "$ROOT_PASSWORD" | \
  gcloud secrets create db-root-password --data-file=- --project=$PROJECT_ID

# Store app password
echo -n "$APP_PASSWORD" | \
  gcloud secrets create db-app-password --data-file=- --project=$PROJECT_ID

# Store connection string
CONNECTION_STRING="postgresql://app_user:${APP_PASSWORD}@/clinical_diary?host=/cloudsql/${PROJECT_ID}:${REGION}:${INSTANCE_NAME}"
echo -n "$CONNECTION_STRING" | \
  gcloud secrets create database-url --data-file=- --project=$PROJECT_ID
```

---

## Schema Deployment

### Step 7: Connect via Cloud SQL Auth Proxy

```bash
# Download Cloud SQL Auth Proxy (if not installed)
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.0/cloud-sql-proxy.darwin.arm64
chmod +x cloud-sql-proxy

# Start proxy (separate terminal)
./cloud-sql-proxy ${PROJECT_ID}:${REGION}:${INSTANCE_NAME} --port=5432

# Or use gcloud (simpler, slower)
gcloud sql connect $INSTANCE_NAME --user=app_user --database=$DATABASE_NAME
```

### Step 8: Deploy Core Schema

```bash
# Set connection variables
export PGHOST="127.0.0.1"
export PGPORT="5432"
export PGUSER="app_user"
export PGPASSWORD="$APP_PASSWORD"
export PGDATABASE="clinical_diary"

# Navigate to schema directory
cd packages/database

# Deploy in order
psql -f schema.sql
psql -f triggers.sql
psql -f roles.sql
psql -f rls_policies.sql
psql -f indexes.sql

# Verify deployment
psql -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;"
```

### Expected Core Tables

```
 table_name
------------------------
 admin_action_log
 analyst_site_assignments
 investigator_site_assignments
 record_audit
 record_state
 role_change_log
 sites
 sync_conflicts
 user_profiles
 user_sessions
 user_site_assignments
```

---

## RLS Configuration

### Session Variables

The application sets session variables before each query:

```sql
-- Set by Dart server before queries
SET app.current_user_id = 'user_uuid_here';
SET app.current_user_role = 'USER';  -- USER, INVESTIGATOR, ANALYST, ADMIN
SET app.current_site_id = 'site_001';
```

### Verify RLS Policies

```sql
-- Check RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public';

-- Test as USER role
SET app.current_user_id = 'test_patient_001';
SET app.current_user_role = 'USER';
SELECT COUNT(*) FROM record_state;  -- Should see only own data

-- Test as ADMIN role
SET app.current_user_role = 'ADMIN';
SELECT COUNT(*) FROM record_state;  -- Should see all data
```

---

## Backup Configuration

### Automated Backups

Cloud SQL performs daily automated backups:

```bash
# Verify backup configuration
gcloud sql instances describe $INSTANCE_NAME \
  --format="yaml(settings.backupConfiguration)" \
  --project=$PROJECT_ID

# Configure retention (default 7, max 365 days)
gcloud sql instances patch $INSTANCE_NAME \
  --backup-retention-count=30 \
  --project=$PROJECT_ID
```

### Point-in-Time Recovery

PITR enabled by default, allows recovery to any point in the last 7 days:

```bash
# Verify PITR status
gcloud sql instances describe $INSTANCE_NAME \
  --format="get(settings.backupConfiguration.pointInTimeRecoveryEnabled)" \
  --project=$PROJECT_ID
```

### Manual Backup

```bash
# Create on-demand backup before major changes
gcloud sql backups create \
  --instance=$INSTANCE_NAME \
  --description="Pre-migration backup $(date +%Y-%m-%d)" \
  --project=$PROJECT_ID

# List backups
gcloud sql backups list --instance=$INSTANCE_NAME --project=$PROJECT_ID
```

### Export to Cloud Storage

For long-term archival:

```bash
# Create backup bucket
gsutil mb -l $REGION gs://${PROJECT_ID}-db-backups

# Export database
gcloud sql export sql $INSTANCE_NAME \
  gs://${PROJECT_ID}-db-backups/export-$(date +%Y%m%d-%H%M%S).sql \
  --database=$DATABASE_NAME \
  --project=$PROJECT_ID
```

---

## Monitoring Setup

### Enable Query Insights

```bash
gcloud sql instances patch $INSTANCE_NAME \
  --insights-config-query-insights-enabled \
  --insights-config-query-string-length=4096 \
  --insights-config-record-application-tags \
  --insights-config-record-client-address \
  --project=$PROJECT_ID
```

### Key Metrics to Monitor

| Metric | Alert Threshold | Description |
| --- | --- | --- |
| CPU Utilization | > 80% | Scale up instance |
| Memory Utilization | > 85% | Scale up or optimize queries |
| Disk Utilization | > 80% | Increase storage |
| Connections | > 80% of max | Connection pool issues |
| Replication Lag | > 10 seconds | HA replica falling behind |

### Create Alert Policies

```bash
# High CPU alert
gcloud monitoring alerting policies create \
  --display-name="Cloud SQL High CPU - $INSTANCE_NAME" \
  --condition-filter='resource.type="cloudsql_database" AND metric.type="cloudsql.googleapis.com/database/cpu/utilization"' \
  --condition-threshold-value=0.8 \
  --condition-threshold-comparison=COMPARISON_GT \
  --notification-channels=CHANNEL_ID \
  --project=$PROJECT_ID

# Storage alert
gcloud monitoring alerting policies create \
  --display-name="Cloud SQL Storage Alert - $INSTANCE_NAME" \
  --condition-filter='resource.type="cloudsql_database" AND metric.type="cloudsql.googleapis.com/database/disk/utilization"' \
  --condition-threshold-value=0.8 \
  --condition-threshold-comparison=COMPARISON_GT \
  --notification-channels=CHANNEL_ID \
  --project=$PROJECT_ID
```

---

## Maintenance

### Maintenance Windows

Production instances use scheduled maintenance windows:

```bash
gcloud sql instances patch $INSTANCE_NAME \
  --maintenance-window-day=SUN \
  --maintenance-window-hour=03 \
  --project=$PROJECT_ID
```

### Scaling

```bash
# Vertical scaling (requires restart)
gcloud sql instances patch $INSTANCE_NAME \
  --tier=db-custom-4-16384 \
  --project=$PROJECT_ID

# Storage increase (no restart)
gcloud sql instances patch $INSTANCE_NAME \
  --storage-size=200GB \
  --project=$PROJECT_ID
```

### Database Migrations

Use dbmate or similar tool:

```bash
# Set connection string
export DATABASE_URL="postgresql://app_user:${APP_PASSWORD}@127.0.0.1:5432/clinical_diary?sslmode=disable"

# Run migrations
dbmate up

# Check status
dbmate status
```

---

## Terraform Configuration

### Module Definition

```hcl
# infrastructure/terraform/modules/cloud-sql/main.tf
resource "google_sql_database_instance" "main" {
  name             = "${var.sponsor}-db-${var.environment}"
  database_version = "POSTGRES_15"
  region           = var.region
  project          = var.project_id

  settings {
    tier              = var.db_tier
    availability_type = var.environment == "prod" ? "REGIONAL" : "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = var.disk_size
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      start_time                     = "02:00"
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = var.backup_retention_days
      }
    }

    maintenance_window {
      day  = 7  # Sunday
      hour = 3
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_id
    }

    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    user_labels = var.labels
  }

  deletion_protection = var.environment == "prod"
}

resource "google_sql_database" "main" {
  name     = "clinical_diary"
  instance = google_sql_database_instance.main.name
  project  = var.project_id
}

resource "google_sql_user" "app" {
  name     = "app_user"
  instance = google_sql_database_instance.main.name
  password = var.db_password
  project  = var.project_id
}
```

### Usage

```hcl
module "cloud_sql" {
  source = "../../modules/cloud-sql"

  sponsor     = "orion"
  environment = "prod"
  project_id  = "hht-diary-orion-prod"
  region      = "europe-west1"  # EU region for GDPR

  db_tier              = "db-custom-2-8192"
  disk_size            = 100
  backup_retention_days = 30

  vpc_id      = google_compute_network.main.id
  db_password = var.db_app_password

  labels = {
    sponsor     = "orion"
    environment = "prod"
    managed-by  = "terraform"
  }
}
```

---

## Troubleshooting

### Connection Issues

```bash
# Verify instance is running
gcloud sql instances describe $INSTANCE_NAME --format="get(state)"

# Check connectivity
gcloud sql connect $INSTANCE_NAME --user=app_user

# Verify private IP
gcloud sql instances describe $INSTANCE_NAME --format="get(ipAddresses)"
```

### Performance Issues

```sql
-- Check active connections
SELECT * FROM pg_stat_activity WHERE state = 'active';

-- Find slow queries
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 10;

-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;
```

### Disk Space

```sql
-- Table sizes
SELECT relname, pg_size_pretty(pg_total_relation_size(relid))
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;

-- Database size
SELECT pg_size_pretty(pg_database_size('clinical_diary'));
```

---

## Security Checklist

- [ ] Instance uses private IP only (no public IP)
- [ ] VPC peering configured for private access
- [ ] Strong passwords generated and stored in Secret Manager
- [ ] Application user has minimal required permissions
- [ ] SSL/TLS enforced (automatic with Cloud SQL)
- [ ] Audit logging enabled (pgAudit)
- [ ] Backup encryption enabled (automatic)
- [ ] Point-in-time recovery enabled
- [ ] Monitoring alerts configured
- [ ] Deletion protection enabled (production)

---

## References

- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
- [Cloud SQL PostgreSQL](https://cloud.google.com/sql/docs/postgres)
- [Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/postgres/sql-proxy)
- [Terraform google_sql_database_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance)
- **Database Schema**: spec/dev-database.md
- **RLS Policies**: spec/dev-security-RLS.md

---

## Change Log

| Date | Version | Changes | Author |
| --- | --- | --- | --- |
| 2025-11-25 | 1.0 | Initial Cloud SQL setup guide | Claude |
