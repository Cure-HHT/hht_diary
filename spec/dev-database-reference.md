# Database Query Reference Guide

**Version**: 1.0
**Audience**: Developers
**Last Updated**: 2025-12-27

> **See**: prd-database.md for architecture overview
> **See**: ops-database-setup.md for deployment procedures
> **See**: dev-data-models-jsonb.md for JSONB schema details

Fast reference for common database operations.

---

## Database Structure

```
record_audit (immutable log)
    ↓ trigger
record_state (current view)
    ↑ references
investigator_annotations (notes layer)

sites → user_site_assignments → patients
     → investigator_site_assignments → investigators
     → analyst_site_assignments → analysts
```

---

## Key Concepts

- **UUID**: Generated client-side for offline support
- **Audit Trail**: Every change creates immutable audit entry
- **State Table**: Auto-updated via triggers, never modify directly
- **RLS**: Row-Level Security enforces access control
- **Roles**: USER, INVESTIGATOR, ANALYST, ADMIN

---

## Common SQL Operations

### Create Diary Entry

```sql
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation, data,
    created_by, role, client_timestamp, change_reason
) VALUES (
    gen_random_uuid(),
    'patient_001',
    'site_001',
    'USER_CREATE',
    '{"event_type": "epistaxis", "date": "2025-02-15", "time": "14:30"}'::jsonb,
    'patient_001',
    'USER',
    now(),
    'Initial entry'
);
```

### Update Entry

```sql
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation, data,
    created_by, role, client_timestamp, change_reason, parent_audit_id
) VALUES (
    'existing-uuid',  -- Same UUID as original
    'patient_001',
    'site_001',
    'USER_UPDATE',
    '{"event_type": "epistaxis", "date": "2025-02-15", "time": "14:30", "duration_minutes": 20}'::jsonb,
    'patient_001',
    'USER',
    now(),
    'Corrected duration',
    (SELECT last_audit_id FROM record_state WHERE event_uuid = 'existing-uuid')
);
```

### Add Annotation

```sql
INSERT INTO investigator_annotations (
    event_uuid, investigator_id, site_id,
    annotation_text, annotation_type, requires_response
) VALUES (
    'event-uuid',
    'inv_001',
    'site_001',
    'Please clarify the timing of this event',
    'QUERY',
    true
);
```

### View Current Entries

```sql
SELECT * FROM record_state
WHERE patient_id = 'patient_001'
  AND is_deleted = false
ORDER BY updated_at DESC;
```

### View Audit History

```sql
SELECT
    audit_id,
    operation,
    data,
    created_by,
    server_timestamp,
    change_reason
FROM record_audit
WHERE event_uuid = 'your-uuid'
ORDER BY audit_id ASC;
```
---

## Role-Based Access

> **See**: prd-security-RBAC.md for role definitions and requirements
---

## Useful Queries

### Patient Compliance

```sql
SELECT
    p.full_name,
    u.study_patient_id,
    COUNT(DISTINCT rs.event_uuid) as total_entries,
    MAX(rs.updated_at) as last_entry,
    COUNT(*) FILTER (
        WHERE rs.updated_at > now() - interval '7 days'
    ) as entries_last_week
FROM user_profiles p
JOIN user_site_assignments u ON p.user_id = u.patient_id
LEFT JOIN record_state rs ON p.user_id = rs.patient_id
WHERE u.site_id = 'site_001'
  AND u.enrollment_status = 'ACTIVE'
GROUP BY p.user_id, p.full_name, u.study_patient_id
ORDER BY last_entry DESC;
```

### Unresolved Queries

```sql
SELECT
    a.annotation_text,
    a.created_at,
    rs.patient_id,
    u.study_patient_id,
    inv.full_name as investigator_name
FROM investigator_annotations a
JOIN record_state rs ON a.event_uuid = rs.event_uuid
JOIN user_site_assignments u ON rs.patient_id = u.patient_id
JOIN user_profiles inv ON a.investigator_id = inv.user_id
WHERE a.requires_response = true
  AND a.resolved = false
  AND a.site_id = 'site_001'
ORDER BY a.created_at DESC;
```

### Site Activity Summary

```sql
SELECT
    s.site_name,
    COUNT(DISTINCT u.patient_id) as enrolled_patients,
    COUNT(DISTINCT rs.event_uuid) as total_entries,
    COUNT(DISTINCT rs.event_uuid) FILTER (
        WHERE rs.updated_at > now() - interval '30 days'
    ) as entries_last_month,
    MAX(rs.updated_at) as last_activity
FROM sites s
LEFT JOIN user_site_assignments u ON s.site_id = u.site_id
LEFT JOIN record_state rs ON u.patient_id = rs.patient_id
WHERE s.is_active = true
  AND u.enrollment_status = 'ACTIVE'
GROUP BY s.site_id, s.site_name
ORDER BY s.site_name;
```

### Audit Trail Analysis

```sql
SELECT
    DATE(server_timestamp) as date,
    operation,
    COUNT(*) as count
FROM record_audit
WHERE site_id = 'site_001'
  AND server_timestamp > now() - interval '30 days'
GROUP BY DATE(server_timestamp), operation
ORDER BY date DESC, count DESC;
```

---

## Conflict Resolution

> **See**: prd-database.md for conflict resolution architecture

### Detect Conflict

```sql
SELECT * FROM sync_conflicts
WHERE event_uuid = 'your-uuid'
  AND resolved = false;
```

### Resolve Conflict

```sql
-- 1. Insert resolved entry
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation, data,
    created_by, role, client_timestamp, change_reason,
    parent_audit_id, conflict_resolved
) VALUES (
    'conflict-uuid',
    'patient_001',
    'site_001',
    'USER_UPDATE',
    '{"merged": "data"}'::jsonb,
    'patient_001',
    'USER',
    now(),
    'Conflict resolved - merged changes',
    (SELECT MAX(audit_id) FROM record_audit WHERE event_uuid = 'conflict-uuid'),
    true
);

-- 2. Mark conflict as resolved
UPDATE sync_conflicts
SET resolved = true,
    resolved_at = now(),
    resolution_strategy = 'MERGE',
    resolved_by = 'patient_001'
WHERE event_uuid = 'conflict-uuid';
```

---

## Maintenance Commands

### Refresh Views

```sql
SELECT refresh_reporting_views();
```

### Update Statistics

```sql
ANALYZE record_audit;
ANALYZE record_state;
```

### Check Table Sizes

```sql
SELECT
    tablename,
    pg_size_pretty(pg_total_relation_size('public.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size('public.'||tablename) DESC;
```

### Check Active Connections

```sql
SELECT COUNT(*) FROM pg_stat_activity;
```

### Check Slow Queries

```sql
SELECT
    query,
    mean_exec_time,
    calls
FROM pg_stat_statements
WHERE mean_exec_time > 1000  -- > 1 second
ORDER BY mean_exec_time DESC
LIMIT 10;
```

---

## Environment Variables

> **See**: ops-database-setup.md for complete configuration guide

```bash
# GCP Configuration
GCP_PROJECT_ID=sponsor-project-id
GCP_REGION=us-central1

# Cloud SQL (for server - via Unix socket in Cloud Run)
DB_SOCKET_PATH=/cloudsql/project:region:instance
DB_NAME=clinical_diary
DB_USER=app_user
# DB_PASSWORD from Secret Manager

# Cloud SQL (for local development - via Cloud SQL Proxy)
DATABASE_URL=postgresql://app_user:[PASSWORD]@localhost:5432/clinical_diary

# Identity Platform (for Flutter app)
GOOGLE_PROJECT_ID=sponsor-project-id
PORTAL_API_KEY=AIza...

# API (Cloud Run URL)
API_BASE_URL=https://api-xxxxx-uc.a.run.app

# Application
ENVIRONMENT=production
```

---

## Troubleshooting

### Can't insert into record_state
**Error:** "Direct modification of record_state is not allowed"
**Fix:** Insert into `record_audit` instead (state updates automatically)

### Permission denied
**Error:** "permission denied for table X"
**Fix:** Check RLS policies and user role in `user_profiles`

### Conflict detected
**Error:** "Conflict detected for event"
**Fix:** Check `sync_conflicts` table and resolve before retrying

### Invalid JWT
**Error:** "Invalid JWT token" or "Token expired"
**Fix:** Re-authenticate via Identity Platform or refresh token with `getIdToken(true)`

---

## References

- **Architecture**: prd-database.md
- **Setup Guide**: ops-database-setup.md
- **JSONB Schemas**: dev-data-models-jsonb.md
- **Compliance**: dev-compliance-practices.md
- **Cloud SQL Docs**: https://cloud.google.com/sql/docs
- **Identity Platform Docs**: https://firebase.google.com/docs/auth
- **PostgreSQL Docs**: https://www.postgresql.org/docs/

---

**Source Files**:
- `database_code_reference.md` (moved 2025-10-17)
