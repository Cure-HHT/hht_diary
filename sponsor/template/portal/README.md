# Portal Application (Optional)

This directory contains the sponsor-specific portal web application.

## Structure

- `app/`: Portal application code
- `database/`: Database schema (standalone)

## Important: Standalone Schema

Portal schemas are **standalone copies** from `packages/database/schema.sql`.
They are **NOT inherited** - each sponsor maintains their own schema independently.

### Initial Setup

1. Copy core schema:
   ```bash
   cp packages/database/schema.sql sponsor/<sponsor-name>/portal/database/schema.sql
   ```

2. Add sponsor-specific tables and modifications

3. Deploy to sponsor's Supabase instance

### Schema Maintenance

- Bugfixes must be manually applied to each sponsor
- No automated synchronization
- Document all changes in schema comments
- Use migration files for production updates

### Known Limitation

This approach requires manual propagation of core schema fixes to each sponsor.
This is an accepted trade-off for complete sponsor independence.

## Deployment

The portal deploys to the sponsor's dedicated Supabase instance configured
in `sponsor-config.yml`.

```yaml
portal:
  deployment:
    supabase_project_id: "<sponsor>-portal-prod"
    region: "eu-west-1"
```

## Testing

Test the portal locally:
```bash
cd portal
supabase start
supabase db reset
# Test portal functionality
```
