# Supabase Setup Guide

Complete guide for deploying the Clinical Trial Diary Database to Supabase.

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

```bash
# Install Supabase CLI
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Create migration
supabase migration new clinical_trial_db_init

# Copy all SQL files into the migration
cat schema.sql triggers.sql roles.sql rls_policies.sql indexes.sql > \
  supabase/migrations/$(ls -t supabase/migrations | head -1)

# Push to Supabase
supabase db push
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

1. Review the main [README.md](./README.md) for usage examples
2. Read the [db-spec.md](./db-spec.md) for architectural details
3. Set up your mobile application with Supabase client
4. Configure monitoring and alerts
5. Train your team on the system

---

## Support

For Supabase-specific issues:
- Supabase Docs: https://supabase.com/docs
- Supabase Discord: https://discord.supabase.com
- GitHub: https://github.com/supabase/supabase

For database architecture questions:
- Contact your database architect team
- Review the PRD in db-spec.md
