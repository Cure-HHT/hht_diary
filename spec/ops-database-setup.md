# Supabase Database Setup Guide

**Version**: 1.0
**Audience**: Operations (Database Administrators, DevOps Engineers)
**Last Updated**: 2025-01-24
**Status**: Active

> **See**: prd-architecture-multi-sponsor.md for multi-sponsor deployment architecture
> **See**: dev-database.md for database implementation details
> **See**: ops-database-migration.md for schema migration procedures
> **See**: ops-deployment.md for full deployment workflows

---

## Executive Summary

Complete guide for deploying the Clinical Trial Diary Database to Supabase in a multi-sponsor architecture. Each sponsor operates an independent Supabase project (separate PostgreSQL database + Auth instance) for complete data isolation.

**Key Principles**:
- **One Supabase project per sponsor** - Complete infrastructure isolation
- **Identical core schema** - All sponsors use same base schema from core repository
- **Sponsor-specific extensions** - Each sponsor can add custom tables/functions
- **Independent operations** - Each sponsor has separate credentials, backups, monitoring

**Multi-Sponsor Deployment**:
```
Sponsor A                    Sponsor B                    Sponsor C
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│ Supabase Project A  │     │ Supabase Project B  │     │ Supabase Project C  │
│ - PostgreSQL DB     │     │ - PostgreSQL DB     │     │ - PostgreSQL DB     │
│ - Supabase Auth     │     │ - Supabase Auth     │     │ - Supabase Auth     │
│ - Edge Functions    │     │ - Edge Functions    │     │ - Edge Functions    │
│ - Isolated Backups  │     │ - Isolated Backups  │     │ - Isolated Backups  │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
```

**This Guide Covers**: Setup procedures for a single sponsor's Supabase instance. Repeat these steps for each sponsor with their own Supabase project.

---

## Prerequisites

1. **Supabase Account**
   - Sign up at https://supabase.com
   - Free tier is sufficient for development/testing
   - Production deployments should use Pro tier or higher

2. **Project Created**
   - Create a new project in Supabase dashboard
   - Choose a region close to your users
   - Note your project URL and anon/service keys

---

## Multi-Sponsor Setup Context

### REQ-o00003: Supabase Project Provisioning Per Sponsor

**Level**: Ops | **Implements**: p00003, o00001 | **Status**: Active

Each sponsor SHALL be provisioned with dedicated Supabase project(s) for their environments (staging, production), ensuring complete database infrastructure isolation.

Provisioning SHALL include:
- Unique Supabase project created per sponsor per environment
- Project naming follows convention: `clinical-diary-{sponsor}-{env}`
- Geographic region selected based on sponsor's user base
- Appropriate tier selected (Free for dev/staging, Pro+ for production)
- Project credentials stored securely in sponsor's GitHub Secrets

**Rationale**: Implements database isolation requirement (p00003) at the infrastructure provisioning level. Each Supabase project provides isolated PostgreSQL database, authentication system, and API endpoints.

**Acceptance Criteria**:
- Each sponsor has dedicated project URL (`https://{unique-ref}.supabase.co`)
- Projects cannot share databases or authentication systems
- Credentials unique per project and never reused
- Project provisioning documented in runbook
- Staging and production use separate projects

---

### Per-Sponsor Supabase Projects

**Each sponsor requires**:
1. Dedicated Supabase project (separate account or organization)
2. Unique project name: `clinical-diary-{sponsor-name}` (e.g., `clinical-diary-pfizer`)
3. Region selection based on sponsor's primary user base
4. Appropriate tier (Free for dev/staging, Pro+ for production)

### Project Naming Convention

**Format**: `clinical-diary-{sponsor}-{environment}`

**Examples**:
- `clinical-diary-pfizer-prod` - Pfizer production
- `clinical-diary-pfizer-staging` - Pfizer staging/UAT
- `clinical-diary-novartis-prod` - Novartis production

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
- Project URL: `https://{project-ref}.supabase.co`
- Anon key (public, for client apps)
- Service role key (secret, for backend/migrations)
- Database password

**Security**: Credentials must NEVER be shared between sponsors

**Storage**: Use GitHub Secrets per sponsor repository

---

## Step 1: Database Deployment

### Option A: SQL Editor (Quickest)

1. Navigate to **SQL Editor** in Supabase Dashboard
2. Create a new query
3. Copy and paste each file in this order:
   - `schema.sql`
   - `triggers.sql`
   - `roles.sql`
   - `rls_policies.sql`
   - `indexes.sql`
4. Click "Run" after each file
5. Verify success (no errors in output)

### Option B: Migrations (Recommended for Production)

**Deploy Core Schema + Sponsor Extensions**:

```bash
# Install Supabase CLI
npm install -g supabase

# Login to Supabase
supabase login

# Link to sponsor's Supabase project
cd clinical-diary-{sponsor}
supabase link --project-ref {sponsor-project-ref}

# Option 1: Use core schema from GitHub package
npm install @clinical-diary/database@1.2.3

supabase db push --include node_modules/@clinical-diary/database/schema.sql
supabase db push --include node_modules/@clinical-diary/database/triggers.sql
supabase db push --include node_modules/@clinical-diary/database/rls_policies.sql
supabase db push --include node_modules/@clinical-diary/database/indexes.sql

# Option 2: Use core schema from local clone
supabase db push --include ../clinical-diary/packages/database/schema.sql
supabase db push --include ../clinical-diary/packages/database/triggers.sql
supabase db push --include ../clinical-diary/packages/database/rls_policies.sql
supabase db push --include ../clinical-diary/packages/database/indexes.sql

# Deploy sponsor-specific extensions (if any)
supabase db push --include ./database/extensions.sql
```

**Verification**:

```bash
# Verify core tables deployed
supabase db diff --schema public

# Run integration tests
flutter test integration_test/database_test.dart
```

---

## Step 2: Authentication Setup

### Enable Email Authentication

1. Go to **Authentication → Providers** in Supabase Dashboard
2. Enable Email provider
3. Configure email templates (optional)
4. Set up SMTP for production (required for emails)

### Configure JWT Settings

1. Go to **Settings → API**
2. Note your JWT secret (automatically configured)
3. JWT tokens will include these claims:
   ```json
   {
     "sub": "user-uuid",
     "email": "user@example.com",
     "role": "USER" // or INVESTIGATOR, ANALYST, ADMIN
   }
   ```

### Custom Claims Setup

To add the `role` claim to JWT tokens, you need to create a database function:

```sql
-- Create function to add custom claims
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  claims jsonb;
  user_role text;
BEGIN
  -- Fetch the user role from user_profiles
  SELECT role INTO user_role
  FROM public.user_profiles
  WHERE user_id = (event->>'user_id')::text;

  claims := event->'claims';

  -- Add custom role claim
  IF user_role IS NOT NULL THEN
    claims := jsonb_set(claims, '{role}', to_jsonb(user_role));
  ELSE
    claims := jsonb_set(claims, '{role}', to_jsonb('USER'::text));
  END IF;

  -- Update the 'claims' object in the original event
  event := jsonb_set(event, '{claims}', claims);

  RETURN event;
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.custom_access_token_hook TO supabase_auth_admin;
GRANT ALL ON TABLE public.user_profiles TO supabase_auth_admin;

REVOKE EXECUTE ON FUNCTION public.custom_access_token_hook FROM authenticated, anon, public;
```

Then configure in Supabase Dashboard:
1. Go to **Authentication → Hooks**
2. Enable "Custom access token" hook
3. Select the `custom_access_token_hook` function

---

## Step 3: Initial User Setup

### Create Admin User

1. **Via Supabase Dashboard:**
   - Go to **Authentication → Users**
   - Click "Add user"
   - Enter email and password
   - Enable "Auto-confirm user"
   - Note the user UUID

2. **Add to user_profiles:**
   ```sql
   INSERT INTO user_profiles (user_id, email, full_name, role, two_factor_enabled)
   VALUES (
       'user-uuid-from-auth',
       'admin@your-org.com',
       'System Administrator',
       'ADMIN',
       true
   );
   ```

### Create First Site

```sql
INSERT INTO sites (site_id, site_name, site_number, address, contact_info)
VALUES (
    'site_001',
    'Main Clinical Site',
    'SITE-001',
    '{"street": "123 Medical Plaza", "city": "Boston", "state": "MA", "zip": "02101"}'::jsonb,
    '{"phone": "555-0100", "email": "trials@example.org"}'::jsonb
);
```

---

## Step 4: API Configuration

### Get Your API Keys

1. Go to **Settings → API**
2. Copy the following:
   - **Project URL:** `https://your-project.supabase.co`
   - **Anon (public) key:** For client-side applications
   - **Service role key:** For backend operations (keep secret!)

### Client Configuration

**JavaScript/TypeScript:**
```javascript
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://your-project.supabase.co'
const supabaseAnonKey = 'your-anon-key'

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

**Environment Variables:**
```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-key  # Backend only!
```

---

## Step 5: Security Configuration

### Enable RLS (Already Done)

All tables have RLS enabled via `rls_policies.sql`. Verify:

```sql
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename NOT LIKE 'pg_%';
```

All should show `rowsecurity = true`.

### Configure CORS (if needed)

1. Go to **Settings → API**
2. Add allowed origins under CORS configuration
3. For development: `http://localhost:3000`
4. For production: `https://your-app.com`

### Set Up Realtime (Optional)

To enable real-time subscriptions:

1. Go to **Database → Replication**
2. Enable replication for tables you want to subscribe to:
   - `record_state` (for live diary updates)
   - `investigator_annotations` (for real-time notifications)
   - `sync_conflicts` (for conflict alerts)

3. Configure in your application:
   ```javascript
   const channel = supabase
     .channel('diary-updates')
     .on(
       'postgres_changes',
       {
         event: 'INSERT',
         schema: 'public',
         table: 'record_state',
         filter: `patient_id=eq.${userId}`
       },
       (payload) => {
         console.log('New diary entry:', payload)
       }
     )
     .subscribe()
   ```

---

## Step 6: Backup Configuration

### Enable Point-in-Time Recovery

1. Go to **Settings → Database**
2. Enable PITR (available on Pro plan and above)
3. Configure retention period (default: 7 days)

### Set Up Scheduled Backups

Supabase automatically backs up your database, but for critical data:

1. **Pro plan:** Daily backups retained for 7 days
2. **Team plan:** Daily backups retained for 14 days
3. **Enterprise:** Custom retention

### Manual Backup

```bash
# Using Supabase CLI
supabase db dump -f backup_$(date +%Y%m%d).sql

# Or using pg_dump directly
pg_dump "postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres" > backup.sql
```

---

## Step 7: Monitoring Setup

### Enable Logs

1. Go to **Logs → Database**
2. Enable log retention
3. Set up log exports to external service (optional)

### Create Alerts

Monitor these metrics:
- Database CPU usage
- Connection count
- Slow query log
- Error rate

### Database Health Checks

Add these queries to your monitoring:

```sql
-- Active connections
SELECT COUNT(*) FROM pg_stat_activity;

-- Table sizes
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Unresolved conflicts
SELECT COUNT(*) FROM sync_conflicts WHERE resolved = false;

-- Recent errors (check logs)
```

---

## Step 8: Performance Optimization

### Enable Connection Pooling

Supabase provides connection pooling by default. Use the pooler connection string for better performance:

- **Transaction mode:** For short transactions (recommended)
  `postgresql://postgres:[PASSWORD]@[HOST]:6543/postgres`

- **Session mode:** For long-running queries
  `postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres`

### Configure Compute Resources

1. Go to **Settings → Database**
2. Upgrade compute if needed (Pro plan+):
   - Small: 2GB RAM, 2-core CPU
   - Medium: 4GB RAM, 2-core CPU
   - Large: 8GB RAM, 4-core CPU
   - XL: 16GB RAM, 8-core CPU

### Index Maintenance

Already configured in `indexes.sql`, but monitor:

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

## Step 9: Scheduled Jobs

### Refresh Materialized Views

Set up a cron job using pg_cron (available on Pro plan+):

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule view refresh every hour
SELECT cron.schedule(
    'refresh-reporting-views',
    '0 * * * *',  -- Every hour
    $$SELECT refresh_reporting_views();$$
);

-- Schedule daily at 2 AM
SELECT cron.schedule(
    'refresh-reporting-views-daily',
    '0 2 * * *',  -- 2 AM daily
    $$SELECT refresh_reporting_views();$$
);
```

### Clean Up Old Sessions

```sql
-- Schedule cleanup of expired sessions
SELECT cron.schedule(
    'cleanup-expired-sessions',
    '*/30 * * * *',  -- Every 30 minutes
    $$DELETE FROM user_sessions WHERE expires_at < now();$$
);
```

---

## Step 10: Testing

### Load Test Data

```bash
# In Supabase SQL Editor
\i seed_data.sql
```

Or copy the contents of `seed_data.sql` into the SQL Editor.

### Test Authentication Flow

```javascript
// Sign up
const { data, error } = await supabase.auth.signUp({
  email: 'test@example.com',
  password: 'secure-password-123'
})

// Sign in
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'test@example.com',
  password: 'secure-password-123'
})

// Get session
const { data: { session } } = await supabase.auth.getSession()
```

### Test RLS Policies

```javascript
// Should work - user can see own data
const { data, error } = await supabase
  .from('record_state')
  .select('*')
  .eq('patient_id', userId)

// Should return empty - user cannot see others' data
const { data, error } = await supabase
  .from('record_state')
  .select('*')
  .eq('patient_id', 'different-user-id')
```

### Test Audit Trail

```javascript
// Create entry
const { data, error } = await supabase
  .from('record_audit')
  .insert({
    event_uuid: crypto.randomUUID(),
    patient_id: userId,
    site_id: 'site_001',
    operation: 'USER_CREATE',
    data: { event_type: 'test', date: '2025-02-15' },
    created_by: userId,
    role: 'USER',
    client_timestamp: new Date().toISOString(),
    change_reason: 'Test entry'
  })

// Verify state table updated automatically
const { data: state } = await supabase
  .from('record_state')
  .select('*')
  .eq('event_uuid', eventUuid)
  .single()
```

---

## Common Issues and Solutions

### Issue: "Invalid JWT token"

**Solution:**
- Verify JWT secret is correct
- Check token hasn't expired
- Ensure custom claims hook is configured

### Issue: "Row-level security policy violation"

**Solution:**
- Check user has correct role in `user_profiles`
- Verify site assignments exist
- Review RLS policies for the table

### Issue: "Too many connections"

**Solution:**
- Use connection pooler (port 6543)
- Upgrade database plan
- Optimize application connection handling

### Issue: Slow queries

**Solution:**
- Check indexes are being used: `EXPLAIN ANALYZE your_query`
- Run `ANALYZE` on tables
- Consider upgrading compute resources

---

## Production Checklist

Before going live:

- [ ] Database initialized with all scripts
- [ ] Admin user created and tested
- [ ] Sites configured
- [ ] RLS policies verified
- [ ] Custom JWT claims hook enabled
- [ ] Backup strategy configured
- [ ] Monitoring and alerts set up
- [ ] Connection pooling enabled
- [ ] SSL/TLS enforced
- [ ] Environment variables secured
- [ ] 2FA enabled for admin users
- [ ] Scheduled jobs configured (view refresh)
- [ ] Load testing completed
- [ ] Documentation reviewed
- [ ] Incident response plan ready

---

## Next Steps

**After Initial Setup**:

1. **Review Architecture**: Read prd-architecture-multi-sponsor.md for complete multi-sponsor architecture
2. **Implementation Details**: Review dev-database.md for schema details and Event Sourcing pattern
3. **Deploy Portal**: Follow ops-deployment.md to deploy sponsor's portal
4. **Configure Monitoring**: Set up dashboards and alerts per ops-operations.md
5. **Migration Strategy**: Review ops-database-migration.md for schema update procedures

**For Additional Sponsors**:
- Repeat this entire guide with new Supabase project
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

**Supabase Platform**:
- Supabase Docs: https://supabase.com/docs
- Supabase Discord: https://discord.supabase.com
- Supabase Support: support@supabase.com (Pro plan: <4 hour SLA)

**Clinical Diary System**:
- Review spec/ directory for architecture and implementation details
- Contact platform team for architecture questions
- Refer to ops-operations.md for incident response procedures

---

**Document Status**: Active setup guide
**Review Cycle**: Quarterly or when Supabase platform changes
**Owner**: Database Team / DevOps
