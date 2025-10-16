# Clinical Trial Diary Database

PostgreSQL database architecture for FDA 21 CFR Part 11 compliant clinical trial patient diary data with offline-first mobile app support, complete audit trail, and multi-site access control.

**Target Platform:** Supabase
**PostgreSQL Version:** 15+
**Compliance:** FDA 21 CFR Part 11

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Quick Start](#quick-start)
- [Deployment to Supabase](#deployment-to-supabase)
- [Database Schema](#database-schema)
- [Access Control](#access-control)
- [Security Features](#security-features)
- [Usage Examples](#usage-examples)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### Core Components

1. **Event Store** (`record_audit`) - Immutable event log recording all changes
2. **Read Model** (`record_state`) - Current view of diary entries
3. **Annotations Table** (`investigator_annotations`) - Investigator notes/corrections layer
4. **Access Control** - Row-Level Security (RLS) policies for role-based access
5. **Automated Triggers** - Maintain audit trail and state synchronization

### Key Features

- **Offline-First Support** - Client-generated UUIDs for conflict-free sync
- **Complete Audit Trail** - Every change tracked with who, what, when, why
- **Role-Based Access Control** - USER, INVESTIGATOR, ANALYST, ADMIN roles
- **Site Isolation** - Multi-site trials with proper data segregation
- **Conflict Resolution** - Automated detection and resolution workflow
- **FDA Compliance** - Electronic signatures, validation, and audit requirements

---

## Quick Start

### Prerequisites

- Supabase account (free or paid tier)
- PostgreSQL client (psql) or Supabase SQL Editor access
- Basic understanding of PostgreSQL and SQL

### Installation Steps

1. **Clone or download this repository**

2. **Review the database specification**
   ```bash
   cat spec/db-spec.md
   ```

3. **Initialize the database**
   ```bash
   # PostgreSQL
   psql -U postgres -d your_database -f database/init.sql

   # Or use Supabase SQL Editor (see below)
   ```

4. **Verify deployment**
   ```sql
   SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';
   -- Expected: 13 tables
   ```

5. **Load seed data** (optional, for testing)
   ```bash
   psql -U postgres -d your_database -f database/seed_data.sql
   ```

---

## Deployment to Supabase

### Option 1: Supabase SQL Editor (Recommended)

1. **Log into Supabase Dashboard**
   - Go to https://app.supabase.com
   - Select your project

2. **Open SQL Editor**
   - Navigate to SQL Editor in the left sidebar
   - Click "New query"

3. **Run Initialization Script**

   **Note:** Supabase SQL Editor doesn't support `\ir` include directives, so you'll need to copy/paste each file individually in order:

   ```sql
   -- Step 1: Copy and paste database/schema.sql → Run
   -- Step 2: Copy and paste database/triggers.sql → Run
   -- Step 3: Copy and paste database/roles.sql → Run
   -- Step 4: Copy and paste database/rls_policies.sql → Run
   -- Step 5: Copy and paste database/indexes.sql → Run
   -- Step 6: Copy and paste database/tamper_detection.sql → Run
   -- Step 7: Copy and paste database/auth_audit.sql → Run
   ```

   **Or use Option 2** (psql) to run `database/init.sql` automatically.

4. **Verify Deployment**
   ```sql
   -- Check tables
   SELECT tablename FROM pg_tables
   WHERE schemaname = 'public'
   ORDER BY tablename;

   -- Check RLS is enabled
   SELECT tablename, rowsecurity
   FROM pg_tables t
   JOIN pg_class c ON c.relname = t.tablename
   WHERE schemaname = 'public';

   -- Check triggers
   SELECT trigger_name, event_manipulation, event_object_table
   FROM information_schema.triggers
   WHERE trigger_schema = 'public';
   ```

### Option 2: Supabase Migrations (For Production)

1. **Install Supabase CLI**
   ```bash
   npm install -g supabase
   ```

2. **Link to your project**
   ```bash
   supabase link --project-ref your-project-ref
   ```

3. **Create migration files**
   ```bash
   supabase migration new init_clinical_trial_db
   ```

4. **Copy SQL files into migration**
   ```bash
   cat schema.sql triggers.sql roles.sql rls_policies.sql indexes.sql > \
     supabase/migrations/TIMESTAMP_init_clinical_trial_db.sql
   ```

5. **Apply migrations**
   ```bash
   supabase db push
   ```

### Option 3: Direct PostgreSQL Connection

1. **Get connection string from Supabase**
   - Project Settings → Database → Connection string
   - Use "Connection pooling" for better performance

2. **Connect via psql**
   ```bash
   psql "postgresql://postgres:[PASSWORD]@[HOST]:6543/postgres"
   ```

3. **Run initialization**
   ```bash
   \i schema.sql
   \i triggers.sql
   \i roles.sql
   \i rls_policies.sql
   \i indexes.sql
   ```

---

## Database Schema

### Core Tables

#### `sites`
Clinical trial site information and metadata.
```sql
CREATE TABLE sites (
    site_id TEXT PRIMARY KEY,
    site_name TEXT NOT NULL,
    site_number TEXT NOT NULL UNIQUE,
    -- ... additional fields
);
```

#### `record_audit` (Immutable)
Complete audit log - INSERT ONLY, no updates or deletes.
```sql
CREATE TABLE record_audit (
    audit_id BIGSERIAL PRIMARY KEY,
    event_uuid UUID NOT NULL,
    patient_id TEXT NOT NULL,
    site_id TEXT NOT NULL,
    operation TEXT NOT NULL,
    data JSONB NOT NULL,
    -- ... audit fields
);
```

#### `record_state`
Current state of diary entries - updated via triggers only.
```sql
CREATE TABLE record_state (
    event_uuid UUID PRIMARY KEY,
    patient_id TEXT NOT NULL,
    current_data JSONB NOT NULL,
    version INTEGER NOT NULL,
    -- ... state fields
);
```

#### `investigator_annotations`
Investigator notes - separate layer from patient data.
```sql
CREATE TABLE investigator_annotations (
    annotation_id BIGSERIAL PRIMARY KEY,
    event_uuid UUID NOT NULL,
    investigator_id TEXT NOT NULL,
    annotation_text TEXT NOT NULL,
    -- ... annotation fields
);
```

### Supporting Tables

- `user_site_assignments` - Patient enrollment
- `investigator_site_assignments` - Investigator access
- `analyst_site_assignments` - Analyst access
- `sync_conflicts` - Multi-device conflict tracking
- `admin_action_log` - Administrative action audit
- `user_profiles` - User metadata and roles
- `role_change_log` - Role modification audit
- `user_sessions` - Active session tracking

---

## Access Control

### Roles

The database supports four primary roles via JWT claims:

#### 1. USER (Patient)
- Create and modify own diary entries
- View own data and investigator annotations
- Cannot access other patients' data

#### 2. INVESTIGATOR
- Read access to all patients at assigned sites
- Create annotations and queries
- Transcribe paper diaries
- Cannot modify patient's original data

#### 3. ANALYST
- Read-only access to de-identified data at assigned sites
- Export data for analysis
- Cannot see full PII

#### 4. ADMIN
- Global read/write access
- Manage site assignments
- All actions logged and flagged for review
- Requires 2FA

### Row-Level Security (RLS)

All tables have RLS policies enforcing access control:

```sql
-- Example: Users can only see their own records
CREATE POLICY user_isolation ON record_state
    FOR SELECT TO authenticated
    USING (patient_id = current_user_id());

-- Example: Investigators can see records at their sites
CREATE POLICY investigator_site_access ON record_state
    FOR SELECT TO authenticated
    USING (
        current_user_role() = 'INVESTIGATOR'
        AND site_id IN (
            SELECT site_id FROM investigator_site_assignments
            WHERE investigator_id = current_user_id()
            AND is_active = true
        )
    );
```

### Setting User Roles

User roles are stored in the `user_profiles` table and embedded in JWT tokens:

```sql
-- Create a new investigator
INSERT INTO user_profiles (user_id, email, full_name, role)
VALUES ('inv_123', 'dr.smith@hospital.org', 'Dr. Smith', 'INVESTIGATOR');

-- Assign to site
INSERT INTO investigator_site_assignments (investigator_id, site_id, access_level)
VALUES ('inv_123', 'site_001', 'READ_WRITE');
```

---

## Security Features

### 1. Encryption
- Database encrypted at rest (Supabase default: AES-256)
- All connections use TLS 1.3
- JWT tokens for authentication
- bcrypt password hashing (handled by Supabase Auth)

### 2. Audit Trail
- Every modification creates immutable audit entry
- No way to modify event store (enforced by database rules)
- Complete chain of custody
- Includes: who, what, when, why

### 3. Access Control
- Row-Level Security on all tables
- Site-based isolation
- Role-based permissions
- Service role for backend automation

### 4. Two-Factor Authentication
Required for:
- All ADMIN users
- All INVESTIGATOR users
- Optional for USER and ANALYST

### 5. Session Management
- Active session tracking
- IP address and user agent logging
- Automatic session expiration
- Suspicious activity detection

---

## Usage Examples

### Creating a Diary Entry

**Client-side (Mobile App):**
```javascript
// Generate UUID on client
const eventUuid = crypto.randomUUID();

// Create diary entry
const entry = {
    event_uuid: eventUuid,
    patient_id: currentUser.id,
    site_id: currentUser.site_id,
    operation: 'USER_CREATE',
    data: {
        event_type: 'epistaxis',
        date: '2025-02-15',
        time: '14:30',
        duration_minutes: 15,
        intensity: 'moderate',
        side: 'right',
        notes: 'Started after exercise'
    },
    created_by: currentUser.id,
    role: 'USER',
    client_timestamp: new Date().toISOString(),
    change_reason: 'Initial entry'
};

// Insert into event store (read model updates automatically)
const { data, error } = await supabase
    .from('record_audit')
    .insert(entry);
```

### Updating an Entry

```javascript
// User realizes they need to correct the duration
const update = {
    event_uuid: eventUuid, // Same UUID as original
    patient_id: currentUser.id,
    site_id: currentUser.site_id,
    operation: 'USER_UPDATE',
    data: {
        ...originalData,
        duration_minutes: 20, // Updated value
        notes: 'Started after exercise - corrected duration'
    },
    created_by: currentUser.id,
    role: 'USER',
    client_timestamp: new Date().toISOString(),
    parent_audit_id: lastAuditId, // Reference to previous version
    change_reason: 'Corrected duration estimate'
};

await supabase.from('record_audit').insert(update);
```

### Investigator Annotation

```javascript
// Investigator adds a note
const annotation = {
    event_uuid: eventUuid,
    investigator_id: currentUser.id,
    site_id: siteId,
    annotation_text: 'Please provide more detail about activities prior to event',
    annotation_type: 'QUERY',
    requires_response: true
};

await supabase.from('investigator_annotations').insert(annotation);
```

### Querying Patient Data

```sql
-- Get all current diary entries for a patient
SELECT
    event_uuid,
    current_data,
    version,
    updated_at
FROM record_state
WHERE patient_id = 'patient_001'
    AND is_deleted = false
ORDER BY updated_at DESC;

-- Get complete history of a specific entry
SELECT
    audit_id,
    operation,
    data,
    created_by,
    server_timestamp,
    change_reason
FROM record_audit
WHERE event_uuid = '550e8400-e29b-41d4-a716-446655440001'
ORDER BY audit_id ASC;

-- Get unresolved annotations for a patient
SELECT
    a.annotation_text,
    a.annotation_type,
    a.created_at,
    u.full_name as investigator_name
FROM investigator_annotations a
JOIN user_profiles u ON a.investigator_id = u.user_id
WHERE a.event_uuid IN (
    SELECT event_uuid FROM record_state WHERE patient_id = 'patient_001'
)
AND a.resolved = false
ORDER BY a.created_at DESC;
```

### Site-wide Reporting

```sql
-- Daily summary for a site
SELECT
    summary_date,
    active_patients,
    total_events,
    user_actions,
    investigator_actions
FROM daily_site_summary
WHERE site_id = 'site_001'
ORDER BY summary_date DESC
LIMIT 30;

-- Patient compliance report
SELECT
    p.full_name,
    u.study_patient_id,
    pas.total_entries,
    pas.entries_last_7_days,
    pas.last_entry_time
FROM patient_activity_summary pas
JOIN user_profiles p ON pas.patient_id = p.user_id
JOIN user_site_assignments u ON pas.patient_id = u.patient_id
WHERE pas.site_id = 'site_001'
ORDER BY pas.last_entry_time DESC;
```

---

## Maintenance

### Daily Tasks

1. **Monitor Active Sessions**
   ```sql
   SELECT COUNT(*) FROM user_sessions WHERE is_active = true;
   ```

2. **Check for Unresolved Conflicts**
   ```sql
   SELECT COUNT(*) FROM sync_conflicts WHERE resolved = false;
   ```

3. **Review Pending Admin Actions**
   ```sql
   SELECT * FROM admin_action_log
   WHERE approval_status = 'PENDING'
   ORDER BY created_at;
   ```

### Weekly Tasks

1. **Refresh Materialized Views**
   ```sql
   SELECT refresh_reporting_views();
   ```

2. **Review Annotations Requiring Response**
   ```sql
   SELECT COUNT(*) FROM investigator_annotations
   WHERE requires_response = true AND resolved = false;
   ```

3. **Check Database Size**
   ```sql
   SELECT
       schemaname,
       tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
   FROM pg_tables
   WHERE schemaname = 'public'
   ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
   ```

### Monthly Tasks

1. **Analyze Audit Trail Growth**
   ```sql
   SELECT
       DATE_TRUNC('month', server_timestamp) as month,
       COUNT(*) as audit_entries,
       pg_size_pretty(SUM(pg_column_size(data))) as data_size
   FROM record_audit
   GROUP BY month
   ORDER BY month DESC;
   ```

2. **Review Role Changes**
   ```sql
   SELECT * FROM role_change_log
   WHERE created_at > now() - interval '30 days'
   ORDER BY created_at DESC;
   ```

3. **Archive Old Audit Data** (after 2+ years)
   ```sql
   -- Export to cold storage before deletion
   -- This should be done carefully with proper backups
   ```

### Performance Monitoring

```sql
-- Check slow queries
SELECT
    query,
    calls,
    total_time,
    mean_time,
    max_time
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat%'
ORDER BY mean_time DESC
LIMIT 20;

-- Check index usage
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan ASC;
```

---

## Troubleshooting

### Issue: "permission denied for table record_audit"

**Cause:** RLS policies may be blocking access or user doesn't have correct role.

**Solution:**
```sql
-- Check current user and role
SELECT current_user, current_user_id(), current_user_role();

-- Verify user profile exists
SELECT * FROM user_profiles WHERE user_id = current_user_id();

-- Check RLS policies on table
SELECT * FROM pg_policies WHERE tablename = 'record_audit';
```

### Issue: "Conflict detected for event"

**Cause:** Parent audit ID doesn't match current state (multi-device sync conflict).

**Solution:**
```sql
-- Check conflict details
SELECT * FROM sync_conflicts
WHERE event_uuid = 'your-uuid'
AND resolved = false;

-- Resolve conflict by creating new entry with conflict_resolved = true
INSERT INTO record_audit (
    event_uuid, ..., conflict_resolved
) VALUES (
    'uuid', ..., true
);

-- Mark conflict as resolved
UPDATE sync_conflicts
SET resolved = true,
    resolution_strategy = 'CLIENT_WINS'
WHERE event_uuid = 'your-uuid';
```

### Issue: "Direct modification of record_state is not allowed"

**Cause:** Attempting to directly modify read model instead of using event store.

**Solution:**
```sql
-- Don't do this:
-- UPDATE record_state SET current_data = ...

-- Instead, insert into event store:
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason
) VALUES (...);

-- Read model updates automatically via trigger
```

### Issue: Materialized views are out of date

**Cause:** Views need periodic refresh.

**Solution:**
```sql
-- Refresh all reporting views
SELECT refresh_reporting_views();

-- Or refresh individually
REFRESH MATERIALIZED VIEW CONCURRENTLY daily_site_summary;
REFRESH MATERIALIZED VIEW CONCURRENTLY patient_activity_summary;
```

### Issue: Poor query performance

**Cause:** Missing indexes or outdated statistics.

**Solution:**
```sql
-- Update statistics
ANALYZE record_audit;
ANALYZE record_state;

-- Check if indexes are being used
EXPLAIN ANALYZE
SELECT * FROM record_state WHERE patient_id = 'test';

-- Rebuild index if fragmented
REINDEX TABLE record_audit;
```

---

## File Structure

```
.
├── README.md              # This file
├── db-spec.md            # Detailed database specification
├── schema.sql            # Core table definitions
├── triggers.sql          # Audit automation triggers
├── roles.sql             # Role management and authentication
├── rls_policies.sql      # Row-level security policies
├── indexes.sql           # Performance indexes and optimizations
├── init.sql              # Complete initialization script
└── seed_data.sql         # Sample data for testing
```

---

## Additional Resources

- [Supabase Documentation](https://supabase.com/docs)
- [PostgreSQL RLS Guide](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [FDA 21 CFR Part 11](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/part-11-electronic-records-electronic-signatures-scope-and-application)
- [JSONB Performance Tips](https://www.postgresql.org/docs/current/datatype-json.html)

---

## Support and Contributing

For issues, questions, or contributions, please contact the database architecture team.

**Version:** 1.0
**Last Updated:** 2025
**License:** Proprietary - Clinical Trial Use Only
