# Database Implementation Guide

**Version**: 1.0
**Audience**: Software Developers
**Last Updated**: 2025-01-24
**Status**: Active

> **Scope**: Supabase implementation, deployment procedures, Edge Functions, development workflow
>
> **See**: prd-database.md for schema architecture and Event Sourcing pattern
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor deployment model
> **See**: ops-database-setup.md for production deployment procedures
> **See**: ops-database-migration.md for migration strategies

---

## Executive Summary

This guide covers **how to implement and deploy** the database using Supabase. Each sponsor has a dedicated Supabase project with core schema + sponsor-specific extensions.

**Technology Stack**:
- **Platform**: Supabase (managed PostgreSQL + Auth + Edge Functions)
- **Database**: PostgreSQL 15+
- **Edge Functions**: Deno runtime (TypeScript)
- **CLI**: Supabase CLI for local development and deployment

---

## Development Environment Setup

### Install Supabase CLI

```bash
# macOS
brew install supabase/tap/supabase

# Linux/WSL
brew install supabase/tap/supabase

# Windows
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Verify installation
supabase --version
```

### Login to Supabase

```bash
# Login (opens browser for authentication)
supabase login

# Verify login
supabase projects list
```

---

## Repository Structure

```
clinical-diary/                      # Public core repository
  packages/
     database/
          schema.sql              # Core tables
          triggers.sql            # Event Sourcing triggers
          functions.sql           # Helper functions
          rls_policies.sql        # Row-level security
         indexes.sql             # Performance indexes

clinical-diary-{sponsor}/            # Private sponsor repository
  database/
      extensions.sql              # Sponsor-specific tables/functions
     seed_data.sql               # Initial data for sponsor
  edge_functions/
      edc-sync/                   # EDC integration (if proxy mode)
          index.ts
         _shared/
     custom-validations/         # Sponsor-specific validations
         index.ts
 supabase/
     config.toml                 # Supabase project configuration
```

---

## Core Schema Deployment

# REQ-d00007: Database Schema Implementation and Deployment

**Level**: Dev | **Implements**: o00004 | **Status**: Active

Database schema files SHALL be implemented as versioned SQL scripts organized by functional area (schema, triggers, functions, RLS policies, indexes), enabling repeatable deployment to sponsor-specific Supabase instances while maintaining schema consistency across all sponsors.

Implementation SHALL include:
- SQL files organized by functional area (schema.sql, triggers.sql, functions.sql, rls_policies.sql, indexes.sql)
- Schema versioning following semantic versioning conventions
- Deployment scripts validating schema integrity after execution
- Supabase CLI integration for automated deployment
- Migration scripts for schema evolution with rollback capability
- Documentation of schema dependencies and deployment order

**Rationale**: Implements database schema deployment (o00004) at the development level. Supabase CLI provides tooling for SQL execution and schema management, enabling consistent schema deployment across multiple sponsor databases.

**Acceptance Criteria**:
- All schema files execute without errors on PostgreSQL 15+
- Deployment scripts validate table creation and trigger installation
- Schema deployed successfully to Supabase test instance
- Migration scripts include both forward and rollback operations
- Deployment process documented with step-by-step instructions
- Schema version tracked in database metadata table

*End* *Database Schema Implementation and Deployment* | **Hash**: 6bb78566
---

# REQ-d00011: Multi-Site Schema Implementation

**Level**: Dev | **Implements**: o00011 | **Status**: Active

The database schema SHALL implement multi-site support through sites table, site assignment tables, and row-level security policies that enforce site-based data access control within each sponsor's database.

Implementation SHALL include:
- sites table with site metadata (site_id, site_name, site_number, location, contact)
- investigator_site_assignments table mapping investigators to sites
- analyst_site_assignments table mapping analysts to sites
- user_site_assignments table mapping patients to enrollment sites
- RLS policies filtering queries by user's assigned sites
- Site context captured in all audit trail records

**Rationale**: Implements multi-site configuration (o00011) at the database code level. Sites table and assignment tables enable flexible multi-site trial management, while RLS policies enforce site-level access control automatically at the database layer.

**Acceptance Criteria**:
- sites table supports unlimited sites per sponsor
- Assignment tables support many-to-many site relationships
- RLS policies correctly filter data by assigned sites
- Site context preserved in record_audit for compliance
- Site-based queries perform efficiently with proper indexes
- Site assignments modifiable by administrators only

*End* *Multi-Site Schema Implementation* | **Hash**: bf785d33
---

### Option 1: GitHub Package Registry (Recommended)

Core schema published as versioned package:

```bash
# In sponsor repository
npm install @clinical-diary/database@1.2.3

# Deploy core schema
supabase db push --file node_modules/@clinical-diary/database/schema.sql
supabase db push --file node_modules/@clinical-diary/database/triggers.sql
supabase db push --file node_modules/@clinical-diary/database/functions.sql
supabase db push --file node_modules/@clinical-diary/database/rls_policies.sql
supabase db push --file node_modules/@clinical-diary/database/indexes.sql
```

### Option 2: Git Submodule (Alternative)

```bash
# Add core as submodule
git submodule add https://github.com/org/clinical-diary core

# Deploy core schema
supabase db push --file core/packages/database/schema.sql
# ... (other files)
```

### Option 3: Direct SQL Execution

```bash
# Clone core repository locally
git clone https://github.com/org/clinical-diary

# Connect to Supabase project
supabase link --project-ref your-project-ref

# Execute SQL files
cd clinical-diary/packages/database
for file in schema.sql triggers.sql functions.sql rls_policies.sql indexes.sql; do
  supabase db execute --file $file
done
```

---

## Sponsor Extensions Deployment

After core schema is deployed, add sponsor-specific extensions:

```bash
# In sponsor repository
cd database

# Deploy sponsor extensions
supabase db execute --file extensions.sql

# Verify deployment
supabase db diff
```

**Example extensions.sql**:
```sql
-- Sponsor-specific custom fields table
CREATE TABLE IF NOT EXISTS custom_patient_fields (
  patient_id TEXT PRIMARY KEY REFERENCES auth.users(id),
  sponsor_custom_id TEXT,
  enrollment_cohort TEXT,
  custom_data JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS policies for custom table
ALTER TABLE custom_patient_fields ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_select_own ON custom_patient_fields
  FOR SELECT TO authenticated
  USING (patient_id = auth.uid());

-- Sponsor-specific function
CREATE OR REPLACE FUNCTION calculate_sponsor_metric(patient_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
  -- Sponsor-specific calculation logic
  RETURN '{"metric": "value"}'::jsonb;
END;
$$;
```

---

## Edge Functions

### Edge Function Structure

Edge Functions run on Deno runtime (TypeScript) at the edge (globally distributed).

**Use Cases**:
- EDC sync (proxy mode sponsors)
- Custom data validations
- Scheduled jobs
- Webhook handlers

### Creating an Edge Function

```bash
# Create new Edge Function
supabase functions new edc-sync

# This creates:
# edge_functions/edc-sync/index.ts
```

**Example: EDC Sync Function** (edc-sync/index.ts):

> **CRITICAL**: Event ordering MUST be preserved during retries. The `audit_id` field (auto-incrementing) establishes chronological order. Retry queries MUST use `ORDER BY audit_id ASC` to maintain event sequence integrity in the EDC system.

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    // Get Supabase client (authenticated with service role)
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Parse incoming sync request
    const { event_uuid, operation } = await req.json()

    // Fetch event from audit trail
    const { data: auditEvent, error } = await supabaseClient
      .from('record_audit')
      .select('audit_id, event_uuid, patient_id, operation, data, server_timestamp')
      .eq('event_uuid', event_uuid)
      .single()

    if (error) throw error

    // Transform to EDC format (sponsor-specific)
    const edcPayload = transformToEdcFormat(auditEvent)

    // Send to EDC system
    const edcResponse = await fetch(Deno.env.get('EDC_ENDPOINT')!, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('EDC_API_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(edcPayload),
    })

    if (!edcResponse.ok) {
      // Log sync failure with retry scheduling
      // NOTE: audit_id maintains event ordering for retries
      const attemptCount = 1
      const nextRetryAt = new Date(Date.now() + Math.pow(2, attemptCount) * 60000) // Exponential backoff

      await supabaseClient.from('edc_sync_log').insert({
        audit_id: auditEvent.audit_id,
        event_uuid: auditEvent.event_uuid,
        sync_status: 'FAILED',
        attempt_count: attemptCount,
        next_retry_at: nextRetryAt.toISOString(),
        last_error: `EDC API error: ${edcResponse.statusText}`,
      })

      throw new Error(`EDC sync failed: ${edcResponse.statusText}`)
    }

    // Log sync success
    await supabaseClient.from('edc_sync_log').insert({
      audit_id: auditEvent.audit_id,
      event_uuid: auditEvent.event_uuid,
      sync_status: 'SUCCESS',
      edc_response: await edcResponse.json(),
    })

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

function transformToEdcFormat(auditEvent: any): any {
  // Sponsor-specific transformation logic
  return {
    subject_id: auditEvent.patient_id,
    visit_date: auditEvent.data.date,
    // ... other EDC fields
  }
}
```

### Deploying Edge Functions

```bash
# Deploy single function
supabase functions deploy edc-sync

# Deploy all functions
supabase functions deploy

# Set environment variables (secrets)
supabase secrets set EDC_ENDPOINT=https://edc.example.com/api
supabase secrets set EDC_API_KEY=secret_key_here

# Test function locally
supabase functions serve edc-sync

# Invoke for testing
curl -X POST http://localhost:54321/functions/v1/edc-sync \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{"event_uuid": "test-uuid"}'
```

### Shared Code Between Functions

```typescript
// edge_functions/_shared/db.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

export function getSupabaseClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )
}

// edge_functions/edc-sync/index.ts
import { getSupabaseClient } from '../_shared/db.ts'

serve(async (req) => {
  const supabase = getSupabaseClient()
  // ... use supabase client
})
```

---

## Local Development Workflow

### Start Local Supabase

```bash
# Initialize Supabase in project
supabase init

# Start local Supabase (PostgreSQL + Auth + Edge Functions)
supabase start

# This starts:
# - Database: postgresql://postgres:postgres@localhost:54322/postgres
# - Studio UI: http://localhost:54323
# - API: http://localhost:54321
```

### Apply Schema Locally

```bash
# Option 1: Direct execution
supabase db execute --file packages/database/schema.sql

# Option 2: Migrations (recommended)
supabase migration new initial_schema
# Copy SQL into migration file
supabase db reset  # Applies all migrations
```

### Test Changes Locally

```bash
# Open Supabase Studio
open http://localhost:54323

# Or use psql
psql postgresql://postgres:postgres@localhost:54322/postgres

# Test Edge Functions locally
supabase functions serve

# In another terminal
curl http://localhost:54321/functions/v1/your-function \
  -d '{"test": "data"}'
```

---

## Migration Workflow

### Creating Migrations

```bash
# Create new migration
supabase migration new add_custom_fields

# Edit migration file: supabase/migrations/YYYYMMDDHHMMSS_add_custom_fields.sql
```

**Migration File Example**:
```sql
-- supabase/migrations/20250124120000_add_custom_fields.sql

-- Add new column to record_audit
ALTER TABLE record_audit
ADD COLUMN IF NOT EXISTS custom_metadata JSONB;

-- Create index
CREATE INDEX IF NOT EXISTS idx_record_audit_custom_metadata
ON record_audit USING GIN (custom_metadata);

-- Add comment
COMMENT ON COLUMN record_audit.custom_metadata IS
  'Sponsor-specific custom metadata fields';
```

### Applying Migrations

```bash
# Apply to local database
supabase db reset  # Resets and applies all migrations

# Or apply specific migration
supabase migration up

# Check migration status
supabase migration list
```

### Deploying Migrations to Production

```bash
# Link to production project
supabase link --project-ref prod-project-ref

# Preview changes
supabase db diff

# Apply migrations
supabase db push

# Verify
supabase db remote-status
```

---

## Database Schema Composition

### Core Schema (from packages/database/)

**Tables**:
- `record_audit` - Immutable event log
- `record_state` - Current state (auto-updated by triggers)
- `sites` - Clinical trial sites
- `user_profiles` - User metadata
- `investigator_site_assignments` - Site access control
- `sync_conflicts` - Offline sync conflict tracking

**See**: prd-database.md for complete schema documentation

### Sponsor Extensions

**Common Extension Patterns**:

1. **Custom Patient Fields**:
```sql
CREATE TABLE custom_patient_fields (
  patient_id TEXT PRIMARY KEY REFERENCES auth.users(id),
  sponsor_custom_id TEXT UNIQUE,
  cohort TEXT,
  custom_data JSONB
);
```

2. **EDC Sync Tracking**:

> **CRITICAL**: The `audit_id` foreign key is required to maintain chronological event ordering during retries. EDC systems require events in the exact order they occurred to maintain data integrity.

```sql
CREATE TABLE edc_sync_log (
  sync_id BIGSERIAL PRIMARY KEY,
  audit_id BIGINT NOT NULL REFERENCES record_audit(audit_id),
  event_uuid UUID NOT NULL REFERENCES record_audit(event_uuid),
  sync_status TEXT CHECK (sync_status IN ('PENDING', 'SUCCESS', 'FAILED')),
  attempt_count INTEGER DEFAULT 1,
  next_retry_at TIMESTAMPTZ,
  last_error TEXT,
  edc_response JSONB,
  synced_at TIMESTAMPTZ DEFAULT now()
);

-- Partial index for efficient retry queue queries (ordered by audit_id to maintain event order)
CREATE INDEX idx_edc_retry_queue ON edc_sync_log(audit_id, next_retry_at)
  WHERE sync_status = 'FAILED' AND next_retry_at IS NOT NULL;

-- Ensure one sync record per audit event
CREATE UNIQUE INDEX idx_edc_sync_audit_unique ON edc_sync_log(audit_id);
```

3. **Custom Validations**:
```sql
CREATE OR REPLACE FUNCTION validate_sponsor_data(data JSONB)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  -- Sponsor-specific validation logic
  IF data->>'required_field' IS NULL THEN
    RETURN FALSE;
  END IF;
  RETURN TRUE;
END;
$$;
```

---

## Supabase Auth Integration

### Custom JWT Claims

Add custom claims to JWT via Supabase Auth hook:

```sql
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  claims JSONB;
  user_role TEXT;
  site_assignments TEXT[];
BEGIN
  -- Fetch user profile
  SELECT role, active_site INTO user_role
  FROM public.user_profiles
  WHERE user_id = (event->>'user_id')::TEXT;

  -- Fetch site assignments (if applicable)
  IF user_role IN ('INVESTIGATOR', 'ANALYST') THEN
    SELECT array_agg(site_id) INTO site_assignments
    FROM investigator_site_assignments
    WHERE investigator_id = (event->>'user_id')::TEXT
      AND is_active = true;
  END IF;

  -- Build claims
  claims := event->'claims';
  claims := jsonb_set(claims, '{role}', to_jsonb(COALESCE(user_role, 'USER')));

  IF site_assignments IS NOT NULL THEN
    claims := jsonb_set(claims, '{site_assignments}', to_jsonb(site_assignments));
  END IF;

  -- Update event
  event := jsonb_set(event, '{claims}', claims);

  RETURN event;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.custom_access_token_hook TO supabase_auth_admin;
GRANT SELECT ON TABLE public.user_profiles TO supabase_auth_admin;
GRANT SELECT ON TABLE investigator_site_assignments TO supabase_auth_admin;

REVOKE EXECUTE ON FUNCTION public.custom_access_token_hook FROM authenticated, anon, public;
```

**Configure in Supabase Dashboard**:
1. Go to Authentication � Hooks
2. Enable "Custom access token" hook
3. Select `custom_access_token_hook` function

---

## Testing

### Unit Testing SQL Functions

```sql
-- Test helper function
DO $$
DECLARE
  result JSONB;
BEGIN
  -- Test validate_sponsor_data function
  result := validate_sponsor_data('{"required_field": "value"}'::JSONB);

  IF result != TRUE THEN
    RAISE EXCEPTION 'Validation test failed';
  END IF;

  RAISE NOTICE 'Test passed: validate_sponsor_data';
END $$;
```

### Integration Testing

```typescript
// test/database/integration.test.ts
import { createClient } from '@supabase/supabase-js'

describe('Database Integration Tests', () => {
  let supabase: SupabaseClient

  beforeAll(() => {
    supabase = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    )
  })

  test('Event Sourcing: Insert audit creates state', async () => {
    const eventUuid = crypto.randomUUID()

    // Insert into audit
    const { error: auditError } = await supabase
      .from('record_audit')
      .insert({
        event_uuid: eventUuid,
        patient_id: 'test_patient',
        site_id: 'test_site',
        operation: 'USER_CREATE',
        data: { test: 'data' },
        created_by: 'test_user',
        role: 'USER',
        client_timestamp: new Date().toISOString(),
        change_reason: 'Test',
      })

    expect(auditError).toBeNull()

    // Verify state was created
    const { data: state, error: stateError } = await supabase
      .from('record_state')
      .select('*')
      .eq('event_uuid', eventUuid)
      .single()

    expect(stateError).toBeNull()
    expect(state.data).toEqual({ test: 'data' })
  })

  test('RLS: User can only access own data', async () => {
    // Test as user (with anon key)
    const userClient = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_ANON_KEY!
    )

    // Sign in as test user
    await userClient.auth.signInWithPassword({
      email: 'test@example.com',
      password: 'testpassword',
    })

    // Query should only return own data
    const { data, error } = await userClient
      .from('record_state')
      .select('*')

    expect(error).toBeNull()
    expect(data.every(row => row.patient_id === 'test_user_id')).toBe(true)
  })
})
```

---

## Performance Optimization

### Analyzing Query Performance

```sql
-- Enable query timing
\timing on

-- Analyze query plan
EXPLAIN ANALYZE
SELECT * FROM record_state
WHERE patient_id = 'patient_001'
  AND is_deleted = false
ORDER BY updated_at DESC
LIMIT 20;

-- Check slow queries
SELECT
  query,
  mean_exec_time,
  calls
FROM pg_stat_statements
WHERE mean_exec_time > 1000  -- > 1 second
ORDER BY mean_exec_time DESC
LIMIT 10;
```

### Index Optimization

```sql
-- Check index usage
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan ASC;

-- Find missing indexes
SELECT
  schemaname,
  tablename,
  attname,
  n_distinct,
  correlation
FROM pg_stats
WHERE schemaname = 'public'
  AND n_distinct > 100  -- High cardinality
  AND correlation < 0.1;  -- Low correlation (might benefit from index)
```

### Connection Pooling

Use Supabase connection pooler for better performance:

```typescript
// Use pooler (port 6543) for serverless/high concurrency
const supabase = createClient(
  'https://your-project.supabase.co',
  'your-anon-key',
  {
    db: {
      schema: 'public',
    },
    global: {
      headers: {
        'x-connection-pool': 'transaction',  // or 'session'
      },
    },
  }
)
```

---

## Monitoring & Debugging

### Database Logs

```bash
# View real-time logs
supabase logs db

# View specific timeframe
supabase logs db --from "2025-01-24 10:00:00" --to "2025-01-24 11:00:00"
```

### Query Statistics

```sql
-- Top tables by size
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
  pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY size_bytes DESC
LIMIT 10;

-- Table bloat check
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS size,
  n_live_tup,
  n_dead_tup,
  ROUND(100 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_ratio
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_dead_tup DESC;
```

---

## Common Development Tasks

### Reset Local Database

```bash
# Complete reset (drops and recreates)
supabase db reset

# Or manually
supabase db reset --db-url postgresql://postgres:postgres@localhost:54322/postgres
```

### Dump Production Data (for debugging)

```bash
# Dump schema only
supabase db dump --schema-only > schema.sql

# Dump specific table data
supabase db dump --table record_audit --data-only > audit_data.sql

# Full dump (BE CAREFUL - may contain PHI)
supabase db dump > full_dump.sql
```

### Generate TypeScript Types

```bash
# Generate TypeScript types from database
supabase gen types typescript --linked > types/database.types.ts
```

**Usage in code**:
```typescript
import { Database } from './types/database.types'

type RecordAudit = Database['public']['Tables']['record_audit']['Row']
type RecordInsert = Database['public']['Tables']['record_audit']['Insert']
```

---

## Troubleshooting

### Issue: Migration Fails

**Symptoms**: `supabase db push` fails with error

**Solutions**:
```bash
# Check current migration status
supabase migration list

# Preview what would change
supabase db diff

# If stuck, manually inspect
psql postgresql://postgres:postgres@localhost:54322/postgres
\dt  # List tables
\d table_name  # Describe table

# Fix migration file and retry
supabase migration repair
supabase db reset
```

### Issue: Edge Function Not Responding

**Debug steps**:
```bash
# Check function logs
supabase functions logs edc-sync

# Test locally with verbose output
supabase functions serve edc-sync --debug

# Check secrets are set
supabase secrets list
```

### Issue: RLS Blocking Legitimate Access

**Debug**:
```sql
-- Test with specific user claims
SET request.jwt.claims = '{"sub": "user_123", "role": "INVESTIGATOR", "active_site": "site_001"}';

-- Try query
SELECT * FROM record_state WHERE site_id = 'site_001';

-- Check if RLS is problem
SET row_security = off;  -- Only works for superuser
SELECT * FROM record_state WHERE site_id = 'site_001';
```

---

## Security Best Practices

### Never Commit Secrets

```bash
# Add to .gitignore
echo ".env.local" >> .gitignore
echo "supabase/.env" >> .gitignore

# Use environment variables
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_ANON_KEY=your-anon-key
```

### Service Role Key Usage

**ONLY use service role key**:
- In Edge Functions (server-side)
- In backend services
- For admin operations

**NEVER**:
- In client applications
- In frontend code
- In git repositories

### RLS Testing

Always test RLS policies thoroughly:
```sql
-- Test as different roles
SET request.jwt.claims = '{"sub": "test_user", "role": "USER"}';
-- Verify user can only see own data

SET request.jwt.claims = '{"sub": "test_inv", "role": "INVESTIGATOR", "active_site": "site_001"}';
-- Verify investigator limited to assigned site
```

---

## References

- **Schema Architecture**: prd-database.md
- **Multi-Sponsor Architecture**: prd-architecture-multi-sponsor.md
- **Production Setup**: ops-database-setup.md
- **Migration Strategy**: ops-database-migration.md
- **Supabase Documentation**: https://supabase.com/docs
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/

---

## Revision History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2025-01-24 | Initial developer database guide | Development Team |

---

**Document Classification**: Internal Use - Developer Guide
**Review Frequency**: When database architecture changes
**Owner**: Database Team / Technical Lead


---

# Database Architecture (from prd-database.md)

# Clinical Trial Diary Database Architecture

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-10-23
**Status**: Active
**Compliance**: FDA 21 CFR Part 11

> **See**: prd-architecture-multi-sponsor.md for multi-sponsor deployment architecture
> **See**: prd-database-event-sourcing.md for Event Sourcing pattern details
> **See**: prd-security-RBAC.md for access control
> **See**: prd-clinical-trials.md for FDA compliance requirements
> **See**: dev-database.md for implementation guide

---

## Executive Summary

A PostgreSQL-based database system for clinical trial patient diary data deployed as **separate Supabase instances per sponsor**, with offline-first mobile app support, complete audit trail for FDA compliance, and multi-site access control.

**Architecture Pattern**: Event Sourcing with CQRS (Command Query Responsibility Segregation)

**Key Features**:
- Immutable event store for complete audit trail
- Materialized read model for fast queries
- Row-level security for multi-site access control
- Offline-first sync with conflict resolution
- Cryptographic tamper detection
- FDA 21 CFR Part 11 compliant

---

## Core Architecture

See **prd-database-event-sourcing.md** for complete Event Sourcing pattern details.

### Quick Overview

**Event Store (record_audit)**:
- Source of truth
- Immutable append-only log
- Every change captured as event
- Provides audit trail for compliance

**Read Model (record_state)**:
- Current state view
- Derived from event store via triggers
- Optimized for queries
- Cannot be directly modified

**Pattern**: Write to event store → Read from read model

---

## Data Identification

### UUID Generation
- **UUIDs generated by mobile app** (client-side)
- Ensures offline-first functionality
- Same UUID used across multiple database instances
- Prevents duplicate key conflicts during sync
- Format: UUID v4 (random)

### Multi-Sponsor Database Architecture

**Deployment Model**: Each sponsor has a dedicated Supabase project (separate PostgreSQL database + Auth instance).

**Sponsor Isolation**:
- Each sponsor = separate Supabase instance
- No shared database infrastructure
- Independent audit trails per sponsor
- Complete data isolation at infrastructure level

**Shared UUID Space**:
- Client-generated UUIDs (UUID v4) enable future data portability
- Same UUID format across all sponsor instances
- Prevents key conflicts if data ever needs to move between sponsors
- Each sponsor's database maintains independent audit trail for same UUID

**See**: prd-architecture-multi-sponsor.md for complete multi-sponsor architecture

---

## Database Enforcement Rules

### 1. Referential Integrity
- Enforced via PostgreSQL foreign key constraints
- Cascading rules defined for deletions (where applicable)
- Orphaned records prevented at database level

### 2. Data Validation
- Database triggers validate data format and ranges
- Required fields enforced via NOT NULL constraints
- CHECK constraints for enum-like fields
- JSONB schema validation via triggers

### 3. Event Store Maintenance
- **Database triggers** automatically update read model when events are written
- Trigger ensures atomic transaction: both event store write and read model update
- Failed transactions rollback both tables
- No application code can bypass event logging

### 4. Read Model Derivation
- Trigger on event store automatically updates read model
- Application cannot directly update read model (enforced by permissions)
- Ensures read model always reflects event history
- Read model can be rebuilt by replaying events

---

## Access Control

See **prd-security-RBAC.md** for complete role definitions and permissions.

### Role Summary
- **User (Patient)**: Read/write own data only
- **Investigator**: Site-scoped read, can annotate
- **Analyst**: Site-scoped read-only, de-identified data
- **Admin**: Global access, all actions logged

### Row-Level Security (RLS)
- PostgreSQL RLS policies enforce access control
- User isolation by patient_id
- Site-based investigator access
- All policies enforced at database level

---

## Conflict Resolution

### Multi-Device Sync Conflicts
- Detected when `parent_audit_id` doesn't match current state
- Client must resolve before server accepts update
- Resolution strategies:
  - User chooses version (client or server)
  - Field-level merge (non-conflicting fields combined)
  - Manual review UI for true conflicts
- Resolution creates new audit entry with conflict metadata

### Investigator vs. User Conflicts
- Not true conflicts - stored as separate layers
- User data remains authoritative
- Investigator corrections stored as annotations
- Both visible to patient on next sync

---

## Data Synchronization

### Offline-First App Architecture
- Mobile app stores data locally (IndexedDB/SQLite)
- Changes queued for sync when online
- Background sync every 15 minutes when connected
- Delta sync: only changed records transmitted

### Sync Protocol
1. App sends: event UUID, data, parent_audit_id, client timestamp
2. Database checks for conflicts (parent_audit_id match)
3. If no conflict: accept and return new audit_id
4. If conflict: return current state and conflict indicator
5. App resolves conflict and resubmits
6. Database writes event to event store and updates read model

### Batch Operations
- App can submit multiple events in single transaction
- All-or-nothing: entire batch succeeds or fails
- Reduces network overhead for catch-up syncs

---

## Data Model Summary

### Core Tables
1. **record_audit** - Event store (immutable event log)
2. **record_state** - Read model (current state view)
3. **investigator_annotations** - Notes/corrections layer
4. **sites** - Clinical trial site information
5. **user_site_assignments** - Patient enrollment per site
6. **investigator_site_assignments** - Investigator access per site
7. **analyst_site_assignments** - Analyst access per site
8. **sync_conflicts** - Multi-device sync conflict tracking

### Key Fields
- **Event UUID**: Client-generated, globally unique identifier (same across databases)
- **Patient ID**: Links to user authentication system
- **Site ID**: Clinical trial site for RBAC
- **Audit ID**: Auto-incrementing event ID, establishes chronological order in event store
- **Parent Audit ID**: Links to previous event for version tracking (Event Sourcing lineage)
- **Data (JSONB)**: Flexible schema for diary events
- **Timestamps**: Client and server, with timezone
- **Change Reason**: Required for all modifications

---

## Performance Considerations

### Indexing Strategy
- Primary keys on all tables
- Indexes on: patient_id, site_id, UUID, timestamps
- GIN index on JSONB columns for fast queries
- Partial indexes for common filters (e.g., pending sync)

### Partitioning
- Event store (record_audit) partitioned by month (performance)
- Old partitions archived to cold storage after 2 years
- Read model (record_state) not partitioned (always small)

### Scaling
- Read replicas for investigator portal queries
- Connection pooling (PgBouncer)
- Materialized views for common aggregate queries
- Automatic vacuum and analyze scheduled

---

## Security Requirements

### Encryption
- Database encrypted at rest (AES-256)
- All connections use TLS 1.3
- JWT tokens for authentication
- Passwords hashed with bcrypt

### Access Logging
- All database connections logged
- Failed authentication attempts logged
- Admin actions logged with justification
- Suspicious patterns trigger alerts

### Backup and Recovery
- Automated backups every 6 hours
- 30-day point-in-time recovery
- Cross-region replication for disaster recovery
- Backup encryption with separate keys

---

## Future Enhancements

### Phase 2 (6-12 months)
- Real-time sync via WebSockets
- Advanced analytics dashboard
- Machine learning for data quality checks
- Integration with electronic health records (EHR)

### Phase 3 (12-24 months)
- Multi-language support
- Blockchain-based audit trail (optional)
- Federated learning across trials
- Advanced query builder for researchers

---

## Success Metrics

### Data Quality
- 100% audit trail completeness (no missing entries)
- <5% sync conflict rate
- <1% manual conflict resolution rate
- 99.9%+ data integrity verification success

### Performance
- <3 seconds average sync time
- <100ms database query latency (95th percentile)
- 99.9% API uptime
- Support 10,000 concurrent users

### Compliance
- Zero critical FDA audit findings
- 100% of corrections properly documented
- Zero unauthorized data access incidents
- 100% backup success rate

---

## Appendix: Database Schema Quick Reference

```
record_audit (INSERT-only event store)
├─ audit_id (PK, auto-increment)
├─ event_uuid (from app)
├─ patient_id
├─ site_id
├─ operation
├─ data (JSONB)
├─ created_by
├─ role
├─ client_timestamp
├─ server_timestamp
├─ parent_audit_id (FK → audit_id)
└─ change_reason

record_state (updatable via triggers only - read model)
├─ event_uuid (PK, from app)
├─ patient_id
├─ site_id
├─ current_data (JSONB)
├─ version
├─ last_audit_id (FK → audit_id)
└─ sync_metadata

investigator_annotations
├─ annotation_id (PK)
├─ event_uuid (FK)
├─ investigator_id
├─ site_id
├─ annotation_text
├─ requires_response
└─ resolved

sites
├─ site_id (PK)
├─ site_name
└─ site_number

user_site_assignments
├─ patient_id (PK)
├─ site_id (FK)
└─ enrolled_at

investigator_site_assignments
├─ investigator_id (PK)
├─ site_id (FK)
└─ access_level

analyst_site_assignments
├─ analyst_id (PK)
├─ site_id (FK)
└─ access_level
```

---

## References

- **Event Sourcing Pattern**: prd-database-event-sourcing.md
- **JSONB Schema**: dev-data-models-jsonb.md
- **Access Control**: prd-security-RBAC.md
- **FDA Compliance**: prd-clinical-trials.md
- **Implementation**: dev-database.md
- **Deployment**: ops-database-setup.md
- **ADR**: docs/adr/ADR-001-event-sourcing-pattern.md

---

**Source**: Extracted and consolidated from db-spec.md


---

# Event Sourcing Pattern (from prd-database-event-sourcing.md)

# Event Sourcing Architecture Pattern

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-10-23

> **See**: prd-database.md for complete database architecture
> **See**: dev-database.md for implementation details  
> **See**: docs/adr/ADR-001-event-sourcing-pattern.md for architectural decision rationale

---

## Overview

This system implements **Event Sourcing** - all changes are stored as a sequence of immutable events, with current state derived from replaying those events. This architectural pattern combined with CQRS (Command Query Responsibility Segregation) provides:

- Complete audit trail for FDA 21 CFR Part 11 compliance
- Point-in-time reconstruction of any record
- Event replay capability
- Temporal queries
- Data integrity guarantees

---

## 1. Event Store (record_audit table)

### Purpose
The **source of truth** for all diary data changes. Every modification to patient data is captured as an immutable event.

### Characteristics
- **Immutable append-only log** - no updates or deletes allowed
- Records every state change as an event
- INSERT-only operations
- Database triggers prevent UPDATE/DELETE operations

### Event Structure
Each event contains:
- **Auto-incrementing audit ID** - establishes chronological order
- **Event UUID** - generated by mobile app, globally unique
- **Patient ID** - data owner
- **Site ID** - clinical trial site
- **Full data snapshot (JSONB)** - complete state at this point
- **Actor** - user/investigator/admin who made change
- **Role** - role under which actor was operating
- **Timestamps** - client-side and server-side (with timezone)
- **Change reason** - required for audit trail (FDA requirement)
- **Parent audit ID** - tracks event lineage for versioning
- **Operation** - type of change (CREATE, UPDATE, DELETE, etc.)
- **Conflict metadata** - for multi-device sync resolution

### Capabilities
- Point-in-time reconstruction of any record
- Event replay for read model rebuilding
- Temporal queries ("show me this record as of 2025-01-15")
- Complete change history with attribution
- Tamper-evident via cryptographic hashes 

---

## 2. Read Model (record_state table)

### Purpose
**Materialized view** of current state, optimized for queries. This is the CQRS "read side."

### Characteristics
- One row per diary entry
- Derived from event stream via database triggers
- Automatically updated when events are written to event store
- Optimized for queries with appropriate indexes

### Record Structure
Each row contains:
- **Event UUID** - primary key, generated by app
- **Patient ID** - data owner
- **Site ID** - clinical trial site
- **Current data (JSONB)** - latest state
- **Version number** - count of events for this record
- **Reference to last audit entry** - last_audit_id
- **Sync metadata** - for offline-first app
- **Soft delete flag** - is_deleted (preserves audit trail)
- **Updated timestamp** - when last modified

### Update Rules
- **Application queries this table, not the event store**
- Application **cannot** directly update read model
- Updates enforced via database triggers only
- Can be rebuilt from event store if corrupted
- All writes flow through event store

---

## 3. Event Sourcing Flow

### Write Path (Command Side)
```
1. App submits change → event store (record_audit)
2. Database trigger validates event
3. Event written to event store (INSERT only)
4. Trigger automatically updates read model (record_state)
5. Transaction commits (atomic: both tables updated or both rollback)
```

### Read Path (Query Side)
```
1. App queries read model (record_state) for current data
2. Fast access via indexes
3. No event replay needed for normal queries
```

### Audit/Compliance Path
```
1. Auditor queries event store (record_audit) for history
2. Can reconstruct any point-in-time view
3. Can verify integrity via cryptographic hashes
```

---

## References

- **Complete Architecture**: prd-database.md
- **Implementation Guide**: dev-database.md
- **JSONB Schema**: dev-data-models-jsonb.md
- **ADR**: docs/adr/ADR-001-event-sourcing-pattern.md
- **Database Schema**: database/schema.sql
- **Triggers**: database/triggers.sql

---

**Source**: Extracted from db-spec.md (Event Sourcing Pattern section)

