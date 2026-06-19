# Cloud SQL Module

Provisions a Cloud SQL PostgreSQL 17 instance with daily automated backups,
point-in-time recovery, and FDA 21 CFR Part 11 compliance settings.

## Features

- **Daily automated backups** stored in the same project and region
- **Point-in-time recovery (PITR)** via continuous transaction log shipping (configurable 1-7 day window)
- **Storage auto-resize** with environment-aware limits (prod 500 GB, uat 100 GB, dev/qa 50 GB)
- **SSL required** (`ENCRYPTED_ONLY`) — no credentials travel in plain text
- **Maintenance window** defaults to Sunday 06:00 CET (05:00 UTC)
- **Environment-aware defaults** for tier, disk, and backup retention
  - Production: 30 retained backups, REGIONAL HA
  - UAT: 14 retained backups
  - Dev/QA: 7 retained backups
- **pgaudit** enabled for FDA-compliant audit logging
- **Private IP only** with enforced SSL encryption
- **Query Insights** for performance monitoring
- **Sponsor-isolated** naming and labelling

## Implemented Requirements

| Requirement | Title | Assertions Covered |
| ----------- | ----- | ------------------ |
| REQ-o00056 | IaC for portal deployment | Infrastructure managed via Terraform |
| REQ-p00042 | Infrastructure audit trail for FDA compliance | pgaudit, connection/query logging |
| REQ-p00047 | Data Backup and Archival | A (automated backups), C (PITR), F (sponsor isolation) |
| REQ-o00008 | Backup and Retention Policy | A (Cloud SQL automated backups), B (30-day PITR) |

See `spec/prd-backup.md` and `spec/ops-operations.md` for full requirement text.

## Usage

```hcl
module "database" {
  source = "../modules/cloud-sql"

  project_id             = var.project_id
  sponsor                = var.sponsor
  environment            = var.environment          # dev | qa | uat | prod
  region                 = var.region
  vpc_network_id         = data.terraform_remote_state.bootstrap.outputs.network_ids[var.environment]
  private_vpc_connection = data.terraform_remote_state.bootstrap.outputs.private_vpc_connections[var.environment]
  database_name          = var.database_name
  db_username            = var.db_username
  DB_PASSWORD            = var.DB_PASSWORD
  disk_size              = var.disk_size             # 0 = environment default

  # Backup & recovery (REQ-p00047, REQ-o00008)
  backup_start_time              = var.backup_start_time
  transaction_log_retention_days = var.transaction_log_retention_days
  backup_retention_override      = var.backup_retention_override

  # Disk auto-resize
  disk_autoresize_limit_override = var.disk_autoresize_limit_override

  # Maintenance window (default: Sunday 05:00 UTC = 06:00 CET)
  maintenance_window_day  = 7
  maintenance_window_hour = 5
}
```

All required variables are set via per-environment `.tfvars` files in
`sponsor-envs/sponsor-configs/` (e.g., `callisto4-dev.tfvars`).

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | -------- |
| project_id | GCP Project ID | string | - | yes |
| sponsor | Sponsor name | string | - | yes |
| environment | Environment (dev, qa, uat, prod) | string | - | yes |
| region | GCP region | string | - | yes |
| vpc_network_id | VPC network ID for private IP | string | - | no |
| private_vpc_connection | Private VPC connection (for depends_on) | string | - | no |
| database_name | Database name | string | - | yes |
| db_username | Database username | string | - | yes |
| DB_PASSWORD | Database password (sensitive) | string | - | yes |
| db_tier | Instance tier (empty = env default) | string | `""` | no |
| edition | PostgreSQL edition (empty = env default) | string | `""` | no |
| disk_size | Initial disk size in GB (0 = env default) | number | - | yes |
| backup_start_time | Daily backup start time in HH:MM UTC | string | - | yes |
| transaction_log_retention_days | Transaction log retention for PITR (1-7) | number | - | yes |
| backup_retention_override | Override retained backup count (0 = env default) | number | - | yes |
| disk_autoresize_limit_override | Disk auto-resize limit in GB (0 = env default) | number | - | yes |
| maintenance_window_day | Day of week for maintenance (1=Mon .. 7=Sun) | number | `7` | no |
| maintenance_window_hour | Hour (UTC) for maintenance window | number | `5` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| instance_name | Cloud SQL instance name |
| instance_connection_name | Connection name for Cloud SQL Proxy |
| instance_self_link | Instance self link |
| private_ip_address | Private IP address |
| database_name | Database name |
| database_user | Database username |
| connection_string | PostgreSQL connection string (without password) |
| instance_tier | Instance machine tier |
| availability_type | ZONAL or REGIONAL |
| backup_configuration | Backup settings summary (start_time, retention, PITR) |

## Backup Strategy

Cloud SQL automated backups run daily at the configured `backup_start_time`.
Backups are stored in the same region as the instance (encrypted at rest by GCP).
Point-in-time recovery allows restoring to any second within the
`transaction_log_retention_days` window.

| Environment | Retained Backups | PITR Window |
| ----------- | --------------- | ----------- |
| prod | 30 | 7 days |
| uat | 14 | 7 days |
| dev / qa | 7 | 7 days |

For long-term archival (7-year regulatory requirement), see `spec/prd-backup.md`
(REQ-p00047 assertion D) and `spec/ops-operations.md` (REQ-o00008 assertion C).

## Restoring a Backup to a Temporary Clone Instance

Use `gcloud sql instances clone` to create a temporary clone from any daily
backup or from a specific point in time. The clone is created in the same
project and region. Delete it when verification is complete.

### Prerequisites

```bash
# Authenticate and set the project
gcloud auth login
gcloud config set project <PROJECT_ID>
```

### Clone from the latest backup

```bash
# List available backups
gcloud sql backups list --instance <INSTANCE_NAME>

# Clone from a specific backup ID
gcloud sql instances clone <INSTANCE_NAME> <CLONE_NAME> \
  --backup-id <BACKUP_ID>

# Example:
gcloud sql instances clone callisto4-dev-db-a1b2 callisto4-dev-db-restore-test \
  --backup-id 1234567890
```

### Clone to a specific point in time (PITR)

```bash
# Clone to a point in time within the transaction log retention window
gcloud sql instances clone <INSTANCE_NAME> <CLONE_NAME> \
  --point-in-time "<TIMESTAMP>"

# Example (restore to 1 hour ago):
gcloud sql instances clone callisto4-dev-db-a1b2 callisto4-dev-db-restore-test \
  --point-in-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S.%3NZ)"

# macOS date equivalent:
gcloud sql instances clone callisto4-dev-db-a1b2 callisto4-dev-db-restore-test \
  --point-in-time "$(date -u -v-1H +%Y-%m-%dT%H:%M:%S.000Z)"
```

### Verify and clean up

```bash
# Wait for clone operation to complete
gcloud sql operations list --instance <CLONE_NAME> --limit 1

# Connect to the clone and verify data
gcloud sql connect <CLONE_NAME> --user <DB_USER> --database <DB_NAME>

# Delete the clone when done
gcloud sql instances delete <CLONE_NAME> --quiet
```

### Using the deploy script

The module is deployed via `deploy-environment.sh`:

```bash
# Preview changes (plan only)
doppler run -- ./infrastructure/terraform/scripts/deploy-environment.sh <sponsor> <env>

# Apply changes
doppler run -- ./infrastructure/terraform/scripts/deploy-environment.sh <sponsor> <env> --apply
```

Backup configuration is applied automatically. No extra flags are needed —
the module enables daily backups, PITR, SSL, and auto-resize by default.

## Security

- **SSL enforced**: `ssl_mode = ENCRYPTED_ONLY` — all connections must use TLS
- **Private IP only**: `ipv4_enabled = false` — no public IP assigned
- **Credentials**: Database password passed via Doppler (`TF_VAR_DB_PASSWORD`), never stored in tfvars
- **Encryption at rest**: GCP default (Google-managed keys)
