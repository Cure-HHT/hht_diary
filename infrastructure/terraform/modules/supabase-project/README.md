# Supabase Project Terraform Module

This module creates and configures a Supabase project with database, authentication, storage, and API settings.

## Usage

```hcl
module "supabase" {
  source = "../../modules/supabase-project"

  organization_id   = "your-org-id"
  project_name      = "clinical-diary-dev"
  database_password = var.database_password  # From Doppler

  region = "us-west-1"
  tier   = "pro"

  enable_backups        = true
  backup_retention_days = 30
  enable_pitr           = true

  site_url      = "https://clinical-diary-dev.com"
  enable_signup = true

  tags = {
    Environment = "development"
    Project     = "clinical-diary"
    ManagedBy   = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
| --- | --- | --- | --- | --- |
| organization_id | Supabase organization ID | string | - | yes |
| project_name | Name of the Supabase project | string | - | yes |
| database_password | Database password (sensitive) | string | - | yes |
| region | AWS region | string | us-west-1 | no |
| tier | Project tier (free/pro/team/enterprise) | string | free | no |
| site_url | Site URL for auth redirects | string | http://localhost:3000 | no |
| enable_signup | Enable user signups | bool | true | no |
| max_connections | Max database connections | number | 100 | no |
| file_size_limit_mb | File upload limit (MB) | number | 50 | no |
| enable_backups | Enable automated backups | bool | true | no |
| backup_retention_days | Backup retention (days) | number | 30 | no |
| enable_pitr | Enable point-in-time recovery | bool | false | no |
| doppler_token | Doppler token (optional) | string | "" | no |
| create_preview_branch | Create preview branch | bool | false | no |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description | Sensitive |
| --- | --- | --- |
| project_id | Supabase project ID | no |
| project_name | Project name | no |
| project_region | Project region | no |
| project_url | Project URL | no |
| api_url | API URL | no |
| graphql_url | GraphQL URL | no |
| database_host | Database host | no |
| database_port | Database port | no |
| anon_key | Anonymous key (public) | no |
| service_role_key | Service role key | **yes** |
| jwt_secret | JWT secret | **yes** |
| backup_schedule | Backup schedule | no |
| preview_branch_id | Preview branch ID | no |

## Requirements

- Terraform >= 1.6
- Supabase Terraform Provider ~> 1.0

## Providers

- [supabase](https://registry.terraform.io/providers/supabase/supabase)

## FDA Compliance

This module implements:
- REQ-o00041: Infrastructure as Code
- REQ-o00042: Change Control
- REQ-o00050: Environment Parity

**Validation Required**:
- IQ: Verify module creates project correctly
- OQ: Verify settings are applied correctly
- PQ: Verify performance (< 1 hour provisioning)

## Security

**Sensitive Variables**:
- `database_password`: Store in Doppler, inject via `doppler run`
- `doppler_token`: Store in Doppler, inject via `doppler run`

**Sensitive Outputs**:
- `service_role_key`: Store in Doppler after creation
- `jwt_secret`: Store in Doppler after creation

## Examples

### Development Environment

```hcl
module "supabase_dev" {
  source = "../../modules/supabase-project"

  organization_id   = var.supabase_org_id
  project_name      = "clinical-diary-dev"
  database_password = var.database_password

  tier              = "free"
  enable_backups    = false
  enable_pitr       = false

  site_url = "http://localhost:3000"
}
```

### Staging Environment

```hcl
module "supabase_staging" {
  source = "../../modules/supabase-project"

  organization_id   = var.supabase_org_id
  project_name      = "clinical-diary-staging"
  database_password = var.database_password

  tier                  = "pro"
  enable_backups        = true
  backup_retention_days = 7
  enable_pitr           = false

  site_url = "https://staging.clinical-diary.com"
}
```

### Production Environment

```hcl
module "supabase_prod" {
  source = "../../modules/supabase-project"

  organization_id   = var.supabase_org_id
  project_name      = "clinical-diary-prod"
  database_password = var.database_password

  tier                  = "pro"
  enable_backups        = true
  backup_retention_days = 30
  enable_pitr           = true

  site_url      = "https://clinical-diary.com"
  enable_signup = true

  max_connections = 200

  tags = {
    Environment = "production"
    CriticalData = "true"
    Compliance   = "FDA-21-CFR-Part-11"
  }
}
```

## Maintenance

### Updating the Module

```bash
# Plan changes
terraform plan

# Apply changes
terraform apply

# Verify
terraform output
```

### Disaster Recovery

```bash
# List backups
supabase backups list --project-ref <project-id>

# Restore from backup
supabase db restore --project-ref <project-id> --backup-id <backup-id>
```

## Troubleshooting

### Project Creation Fails

**Error**: "Organization ID not found"
- **Solution**: Verify organization ID in Supabase dashboard

**Error**: "Database password too weak"
- **Solution**: Use password with 12+ characters, mix of letters/numbers/symbols

### Settings Not Applied

**Error**: "Feature not available on free tier"
- **Solution**: Upgrade to Pro tier or disable feature (e.g., backups, PITR)

## References

- [Supabase Terraform Provider](https://registry.terraform.io/providers/supabase/supabase)
- [Supabase Documentation](https://supabase.com/docs)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices)
