# Row-Level Security Implementation

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-10-26
**Status**: Active

> **See**: prd-security-RLS.md for product requirements
> **See**: ops-security-RLS.md for deployment procedures
> **See**: dev-database.md for database schema details

---

## Executive Summary

This document specifies the implementation details for PostgreSQL Row-Level Security (RLS) policies that enforce access control at the database layer. Each policy is implemented as SQL functions and RLS policy definitions that validate user identity and permissions using JWT claims.

**Technology Stack**:
- PostgreSQL 15+ Row-Level Security
- Identity Platform (Firebase Auth) with JWT-based authentication
- Application-set session variables for RLS context
- PL/pgSQL functions for claim extraction
- Migration scripts for deployment

---

## RLS Policy Implementation Requirements

# REQ-d00019: Patient Data Isolation RLS Implementation

**Level**: Dev | **Implements**: o00020 | **Status**: Active

PostgreSQL RLS policies SHALL be implemented to enforce patient data isolation by filtering queries based on the authenticated user's patient ID from JWT claims.

Implementation SHALL include:
- RLS policy on `record_state` table: `(patient_id = current_user_id())`
- RLS policy on `record_audit` table: `(patient_id = current_user_id())`
- Helper function `current_user_id()` extracting `sub` claim from JWT
- Helper function `current_user_role()` extracting `role` claim from JWT
- Policies apply to SELECT, INSERT for USER role
- No UPDATE/DELETE policies (prevented by event sourcing)

**Implementation Details**:

```sql
-- Helper function to get current user ID from JWT
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS UUID AS $$
  SELECT COALESCE(
    current_setting('request.jwt.claims', true)::json->>'sub',
    NULL
  )::UUID;
$$ LANGUAGE SQL STABLE;

-- Helper function to get current user role from JWT
CREATE OR REPLACE FUNCTION current_user_role()
RETURNS TEXT AS $$
  SELECT COALESCE(
    current_setting('request.jwt.claims', true)::json->>'role',
    'anon'
  )::TEXT;
$$ LANGUAGE SQL STABLE;

-- Enable RLS on tables
ALTER TABLE record_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE record_audit ENABLE ROW LEVEL SECURITY;

-- Patient isolation policy for record_state
CREATE POLICY patient_isolation_state ON record_state
  FOR SELECT
  USING (
    current_user_role() = 'USER'
    AND patient_id = current_user_id()
  );

-- Patient isolation policy for record_audit
CREATE POLICY patient_isolation_audit ON record_audit
  FOR SELECT
  USING (
    current_user_role() = 'USER'
    AND patient_id = current_user_id()
  );

-- Patient insert policy (can only create own records)
CREATE POLICY patient_insert_audit ON record_audit
  FOR INSERT
  WITH CHECK (
    current_user_role() = 'USER'
    AND patient_id = current_user_id()
  );
```

**Rationale**: Implements patient data isolation (o00020) through JWT claim validation. Policies leverage application-set PostgreSQL session variables to extract user identity and enforce row-level filtering.

**Acceptance Criteria**:
- `current_user_id()` function returns UUID from JWT `sub` claim
- `current_user_role()` function returns role from JWT `role` claim
- Patients can SELECT only records where `patient_id` matches their ID
- Patients cannot INSERT records with different `patient_id`
- Policies execute without performance degradation (<50ms overhead)
- Unit tests cover all policy scenarios

*End* *Patient Data Isolation RLS Implementation* | **Hash**: 42079679
---

# REQ-d00020: Investigator Site-Scoped RLS Implementation

**Level**: Dev | **Implements**: o00021 | **Status**: Active

PostgreSQL RLS policies SHALL be implemented to restrict investigator access to data at their assigned sites through subquery validation against the site assignment table.

Implementation SHALL include:
- `investigator_site_assignments` table with (investigator_id, site_id, active) columns
- Composite index on (investigator_id, active) for performance
- RLS policies on clinical data tables using subquery to assignment table
- Single active site context enforced via application session variable
- Site de-assignment (active=false) immediately revokes access
- Policies apply to SELECT for INVESTIGATOR role

**Implementation Details**:

```sql
-- Site assignment table
CREATE TABLE investigator_site_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  investigator_id UUID NOT NULL REFERENCES auth.users(id),
  site_id UUID NOT NULL REFERENCES sites(id),
  active BOOLEAN NOT NULL DEFAULT true,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  assigned_by UUID NOT NULL REFERENCES auth.users(id),
  UNIQUE(investigator_id, site_id)
);

CREATE INDEX idx_investigator_active_sites
  ON investigator_site_assignments(investigator_id, active)
  WHERE active = true;

-- RLS policy for site-scoped investigator access
CREATE POLICY investigator_site_access ON record_state
  FOR SELECT
  USING (
    current_user_role() = 'INVESTIGATOR'
    AND site_id IN (
      SELECT site_id
      FROM investigator_site_assignments
      WHERE investigator_id = current_user_id()
        AND active = true
    )
  );

-- Similar policy for record_audit
CREATE POLICY investigator_site_audit ON record_audit
  FOR SELECT
  USING (
    current_user_role() = 'INVESTIGATOR'
    AND site_id IN (
      SELECT site_id
      FROM investigator_site_assignments
      WHERE investigator_id = current_user_id()
        AND active = true
    )
  );
```

**Rationale**: Implements site-scoped access (o00021) using subquery validation. Index on assignment table ensures performant policy evaluation. Active flag enables immediate access revocation without deleting assignment history.

**Acceptance Criteria**:
- `investigator_site_assignments` table created with proper schema
- Composite index improves subquery performance
- Investigators can SELECT only from assigned active sites
- Site de-assignment (active=false) immediately prevents access
- Policy subquery executes in <100ms
- Migration includes rollback script

*End* *Investigator Site-Scoped RLS Implementation* | **Hash**: 0b438bc8
---

# REQ-d00021: Investigator Annotation RLS Implementation

**Level**: Dev | **Implements**: o00022 | **Status**: Active

PostgreSQL RLS policies SHALL be implemented to allow investigators to create annotations while preventing modification of patient clinical data through selective policy application.

Implementation SHALL include:
- `investigator_annotations` table with proper schema
- INSERT policy on annotations table with site-scoping
- No UPDATE/DELETE policies on `record_audit` for INVESTIGATOR role
- No modification policies on `record_state` for INVESTIGATOR role
- Foreign key constraints ensuring annotation integrity
- Automatic timestamp and investigator_id population via triggers

**Implementation Details**:

```sql
-- Annotations table
CREATE TABLE investigator_annotations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  record_id UUID NOT NULL REFERENCES record_state(id),
  site_id UUID NOT NULL,
  investigator_id UUID NOT NULL REFERENCES auth.users(id),
  annotation_text TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_site FOREIGN KEY (site_id) REFERENCES sites(id)
);

CREATE INDEX idx_annotations_record ON investigator_annotations(record_id);
CREATE INDEX idx_annotations_investigator ON investigator_annotations(investigator_id);

-- Enable RLS
ALTER TABLE investigator_annotations ENABLE ROW LEVEL SECURITY;

-- Investigator can insert annotations at assigned sites
CREATE POLICY investigator_create_annotation ON investigator_annotations
  FOR INSERT
  WITH CHECK (
    current_user_role() = 'INVESTIGATOR'
    AND site_id IN (
      SELECT site_id
      FROM investigator_site_assignments
      WHERE investigator_id = current_user_id()
        AND active = true
    )
    AND investigator_id = current_user_id()
  );

-- Investigator can view annotations at assigned sites
CREATE POLICY investigator_read_annotation ON investigator_annotations
  FOR SELECT
  USING (
    current_user_role() = 'INVESTIGATOR'
    AND site_id IN (
      SELECT site_id
      FROM investigator_site_assignments
      WHERE investigator_id = current_user_id()
        AND active = true
    )
  );

-- Trigger to ensure investigator_id populated automatically
CREATE OR REPLACE FUNCTION set_annotation_investigator()
RETURNS TRIGGER AS $$
BEGIN
  NEW.investigator_id := current_user_id();
  NEW.created_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_set_annotation_investigator
  BEFORE INSERT ON investigator_annotations
  FOR EACH ROW EXECUTE FUNCTION set_annotation_investigator();
```

**Rationale**: Implements annotation restrictions (o00022) by creating separate annotation table with INSERT-only policies for investigators. Absence of modification policies on clinical data tables prevents data alteration.

**Acceptance Criteria**:
- Investigators can INSERT annotations at assigned sites
- Investigators cannot UPDATE or DELETE annotations
- Investigators cannot modify `record_state` or `record_audit`
- `investigator_id` and `created_at` populated automatically
- Foreign key constraints prevent orphaned annotations
- Annotation queries performant with proper indexes

*End* *Investigator Annotation RLS Implementation* | **Hash**: 024f5863
---

# REQ-d00022: Analyst Read-Only RLS Implementation

**Level**: Dev | **Implements**: o00023 | **Status**: Active

PostgreSQL RLS policies SHALL be implemented to provide analysts read-only access to de-identified clinical data at assigned sites through SELECT-only policies.

Implementation SHALL include:
- `analyst_site_assignments` table mirroring investigator assignment structure
- SELECT policies on clinical data tables for ANALYST role
- No INSERT, UPDATE, DELETE policies for ANALYST role
- Site-scoping via subquery to assignment table
- Query audit logging via PostgreSQL pgaudit extension
- De-identification enforcement (no patient identity columns)

**Implementation Details**:

```sql
-- Analyst site assignments table
CREATE TABLE analyst_site_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  analyst_id UUID NOT NULL REFERENCES auth.users(id),
  site_id UUID NOT NULL REFERENCES sites(id),
  active BOOLEAN NOT NULL DEFAULT true,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  assigned_by UUID NOT NULL REFERENCES auth.users(id),
  UNIQUE(analyst_id, site_id)
);

CREATE INDEX idx_analyst_active_sites
  ON analyst_site_assignments(analyst_id, active)
  WHERE active = true;

-- Read-only policy for analysts
CREATE POLICY analyst_read_state ON record_state
  FOR SELECT
  USING (
    current_user_role() = 'ANALYST'
    AND site_id IN (
      SELECT site_id
      FROM analyst_site_assignments
      WHERE analyst_id = current_user_id()
        AND active = true
    )
  );

-- Read-only policy for audit trail
CREATE POLICY analyst_read_audit ON record_audit
  FOR SELECT
  USING (
    current_user_role() = 'ANALYST'
    AND site_id IN (
      SELECT site_id
      FROM analyst_site_assignments
      WHERE analyst_id = current_user_id()
        AND active = true
    )
  );

-- Enable pgaudit logging for analyst queries
-- (Configured at database level, not in migration)
ALTER DATABASE clinical_diary SET pgaudit.role = 'ANALYST';
ALTER DATABASE clinical_diary SET pgaudit.log = 'read';
```

**Rationale**: Implements analyst read-only access (o00023) through SELECT-only policies. Missing write policies inherently enforce read-only at database level. PgAudit logs all analyst queries for compliance.

**Acceptance Criteria**:
- Analysts can SELECT from clinical data tables at assigned sites
- Analysts cannot INSERT, UPDATE, or DELETE any records
- Site assignments filter data visibility
- All analyst SELECT queries logged by pgaudit
- No patient identity information accessible
- Policy performance <100ms with proper indexes

*End* *Analyst Read-Only RLS Implementation* | **Hash**: ca57ee0e
---

# REQ-d00023: Sponsor Global Access RLS Implementation

**Level**: Dev | **Implements**: o00024 | **Status**: Active

PostgreSQL RLS policies SHALL be implemented to provide sponsors read access to all clinical data across all sites within their database instance, with write access limited to administrative tables.

Implementation SHALL include:
- SELECT policies on clinical data tables for SPONSOR role (no site filter)
- No modification policies on clinical data tables for SPONSOR role
- Full CRUD policies on `users`, `sites`, configuration tables for SPONSOR role
- Sponsor isolation enforced through separate database instances (not RLS)
- De-identification enforcement in SELECT policies
- Administrative action logging

**Implementation Details**:

```sql
-- Sponsor global read access to clinical data
CREATE POLICY sponsor_read_state ON record_state
  FOR SELECT
  USING (current_user_role() = 'SPONSOR');

CREATE POLICY sponsor_read_audit ON record_audit
  FOR SELECT
  USING (current_user_role() = 'SPONSOR');

-- Sponsor can manage users
CREATE POLICY sponsor_manage_users ON auth.users
  FOR ALL
  USING (current_user_role() = 'SPONSOR')
  WITH CHECK (current_user_role() = 'SPONSOR');

-- Sponsor can manage sites
CREATE POLICY sponsor_manage_sites ON sites
  FOR ALL
  USING (current_user_role() = 'SPONSOR')
  WITH CHECK (current_user_role() = 'SPONSOR');

-- Sponsor can manage site assignments
CREATE POLICY sponsor_manage_assignments ON investigator_site_assignments
  FOR ALL
  USING (current_user_role() = 'SPONSOR')
  WITH CHECK (current_user_role() = 'SPONSOR');

-- Audit logging for sponsor administrative actions
CREATE OR REPLACE FUNCTION log_sponsor_admin_action()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO admin_action_log (
    user_id,
    action_type,
    table_name,
    record_id,
    timestamp
  ) VALUES (
    current_user_id(),
    TG_OP,
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    now()
  );
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply audit trigger to administrative tables
CREATE TRIGGER trg_audit_sponsor_users
  AFTER INSERT OR UPDATE OR DELETE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION log_sponsor_admin_action();
```

**Rationale**: Implements sponsor global access (o00024) with read-only clinical data and full administrative control. Separate database per sponsor ensures cross-sponsor isolation without RLS complexity.

**Acceptance Criteria**:
- Sponsors can SELECT from all clinical data tables (no site filter)
- Sponsors cannot modify clinical data tables
- Sponsors can manage users, sites, and assignments
- Administrative actions logged in audit table
- No access to other sponsors' data (separate databases)
- De-identified data access only

*End* *Sponsor Global Access RLS Implementation* | **Hash**: 57c79cf5
---

# REQ-d00024: Auditor Compliance RLS Implementation

**Level**: Dev | **Implements**: o00025 | **Status**: Active

PostgreSQL RLS policies SHALL be implemented to provide auditors read-only access to all data including audit logs, with export functions capturing justification.

Implementation SHALL include:
- SELECT policies on all tables for AUDITOR role (no restrictions)
- No write policies for AUDITOR role
- Export function requiring justification parameter
- Export activity logged in separate table
- Quarterly access review query function
- Compliance report generation functions

**Implementation Details**:

```sql
-- Global read access for auditors
CREATE POLICY auditor_read_state ON record_state
  FOR SELECT
  USING (current_user_role() = 'AUDITOR');

CREATE POLICY auditor_read_audit ON record_audit
  FOR SELECT
  USING (current_user_role() = 'AUDITOR');

CREATE POLICY auditor_read_users ON auth.users
  FOR SELECT
  USING (current_user_role() = 'AUDITOR');

-- Apply to all other tables similarly...

-- Export logging table
CREATE TABLE auditor_export_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auditor_id UUID NOT NULL REFERENCES auth.users(id),
  export_timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
  justification TEXT NOT NULL,
  case_id TEXT NOT NULL,
  table_name TEXT NOT NULL,
  record_count INTEGER NOT NULL,
  export_format TEXT NOT NULL
);

-- Export function requiring justification
CREATE OR REPLACE FUNCTION export_clinical_data(
  p_table_name TEXT,
  p_justification TEXT,
  p_case_id TEXT,
  p_format TEXT DEFAULT 'csv'
)
RETURNS TABLE (export_id UUID, record_count INTEGER) AS $$
DECLARE
  v_export_id UUID;
  v_count INTEGER;
BEGIN
  -- Validate auditor role
  IF current_user_role() != 'AUDITOR' THEN
    RAISE EXCEPTION 'Only auditors can export data';
  END IF;

  -- Validate justification provided
  IF p_justification IS NULL OR length(p_justification) < 10 THEN
    RAISE EXCEPTION 'Justification required (min 10 characters)';
  END IF;

  -- Validate case ID provided
  IF p_case_id IS NULL OR length(p_case_id) < 5 THEN
    RAISE EXCEPTION 'Case ID required (min 5 characters)';
  END IF;

  -- Log export action
  INSERT INTO auditor_export_log (
    auditor_id,
    justification,
    case_id,
    table_name,
    record_count,
    export_format
  ) VALUES (
    current_user_id(),
    p_justification,
    p_case_id,
    p_table_name,
    0, -- Updated below
    p_format
  ) RETURNING id INTO v_export_id;

  -- Perform export (implementation depends on export mechanism)
  -- Update record count after export

  RETURN QUERY SELECT v_export_id, v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Quarterly access review function
CREATE OR REPLACE FUNCTION generate_access_review_report(
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ
)
RETURNS TABLE (
  user_id UUID,
  user_email TEXT,
  role TEXT,
  access_count BIGINT,
  last_access TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.id,
    u.email,
    u.role,
    COUNT(al.id) as access_count,
    MAX(al.timestamp) as last_access
  FROM auth.users u
  LEFT JOIN audit_log al ON al.user_id = u.id
  WHERE u.role IN ('AUDITOR', 'ADMIN')
    AND al.timestamp BETWEEN p_start_date AND p_end_date
  GROUP BY u.id, u.email, u.role
  ORDER BY access_count DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Rationale**: Implements auditor compliance access (o00025) with comprehensive logging. Export function enforces justification requirement and creates audit trail of all data extractions.

**Acceptance Criteria**:
- Auditors can SELECT from all tables (no restrictions)
- Auditors cannot modify any records
- Export function requires justification and case ID parameters
- Export actions logged with auditor identity
- Quarterly access review reports available
- Justification validation prevents empty exports

*End* *Auditor Compliance RLS Implementation* | **Hash**: 64a2ff2e
---

# REQ-d00025: Administrator Break-Glass RLS Implementation

**Level**: Dev | **Implements**: o00026 | **Status**: Active

PostgreSQL RLS policies SHALL be implemented for administrator access with break-glass authorization for protected health information access, validated by ticket ID and TTL.

Implementation SHALL include:
- Full access policies for ADMIN role on configuration tables
- Break-glass authorization table with ticket_id and expiry
- Break-glass validation function checking ticket validity and TTL
- Separate policies for routine admin vs. break-glass PHI access
- Break-glass session logging
- Automatic cleanup of expired break-glass sessions

**Implementation Details**:

```sql
-- Break-glass authorization table
CREATE TABLE break_glass_authorizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES auth.users(id),
  ticket_id TEXT NOT NULL,
  justification TEXT NOT NULL,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  granted_by UUID NOT NULL REFERENCES auth.users(id),
  revoked_at TIMESTAMPTZ,
  revoked_by UUID REFERENCES auth.users(id),
  CONSTRAINT valid_ttl CHECK (expires_at > granted_at),
  CONSTRAINT max_ttl CHECK (expires_at <= granted_at + INTERVAL '24 hours')
);

CREATE INDEX idx_break_glass_admin ON break_glass_authorizations(admin_id)
  WHERE revoked_at IS NULL AND expires_at > now();

-- Function to check break-glass authorization
CREATE OR REPLACE FUNCTION has_break_glass_auth()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM break_glass_authorizations
    WHERE admin_id = current_user_id()
      AND revoked_at IS NULL
      AND expires_at > now()
  );
$$ LANGUAGE SQL STABLE;

-- Admin routine access (no PHI)
CREATE POLICY admin_manage_config ON system_config
  FOR ALL
  USING (current_user_role() = 'ADMIN')
  WITH CHECK (current_user_role() = 'ADMIN');

-- Admin break-glass PHI access
CREATE POLICY admin_breakglass_state ON record_state
  FOR SELECT
  USING (
    current_user_role() = 'ADMIN'
    AND has_break_glass_auth()
  );

-- Log break-glass access
CREATE OR REPLACE FUNCTION log_break_glass_access()
RETURNS TRIGGER AS $$
BEGIN
  IF current_user_role() = 'ADMIN' AND has_break_glass_auth() THEN
    INSERT INTO break_glass_access_log (
      admin_id,
      table_name,
      action,
      timestamp
    ) VALUES (
      current_user_id(),
      TG_TABLE_NAME,
      TG_OP,
      now()
    );
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply break-glass logging to PHI tables
CREATE TRIGGER trg_log_breakglass_state
  AFTER SELECT ON record_state
  FOR EACH STATEMENT EXECUTE FUNCTION log_break_glass_access();

-- Cleanup expired break-glass sessions
CREATE OR REPLACE FUNCTION cleanup_expired_break_glass()
RETURNS void AS $$
BEGIN
  UPDATE break_glass_authorizations
  SET revoked_at = now(),
      revoked_by = NULL -- Automatic expiry
  WHERE revoked_at IS NULL
    AND expires_at <= now();
END;
$$ LANGUAGE plpgsql;

-- Schedule cleanup (via pg_cron or external scheduler)
-- SELECT cron.schedule('cleanup-break-glass', '*/15 * * * *',
--   'SELECT cleanup_expired_break_glass()');
```

**Rationale**: Implements administrator access with audit trail (o00026) using break-glass authorization system. TTL validation and ticket ID ensure accountability. Automatic cleanup prevents expired session reuse.

**Acceptance Criteria**:
- Admins can modify configuration tables without break-glass
- PHI access requires valid break-glass authorization
- Break-glass sessions validated by ticket ID and TTL
- TTL limited to maximum 24 hours
- All break-glass access logged
- Expired sessions cleaned up automatically

*End* *Administrator Break-Glass RLS Implementation* | **Hash**: 4a44951a
---

# REQ-d00026: Event Sourcing State Protection RLS Implementation

**Level**: Dev | **Implements**: o00027 | **Status**: Active

PostgreSQL RLS policies SHALL prevent direct modification of the `record_state` table by omitting write policies, with state updates handled exclusively through triggers on the event log.

Implementation SHALL include:
- No INSERT, UPDATE, DELETE policies on `record_state` table
- RLS enabled on `record_state` to block direct modification
- Trigger function on `record_audit` updating `record_state`
- Trigger function secured with SECURITY DEFINER
- State derivation logic tested for correctness
- Migration validating event sourcing integrity

**Implementation Details**:

```sql
-- Enable RLS on record_state
ALTER TABLE record_state ENABLE ROW LEVEL SECURITY;

-- NO WRITE POLICIES - intentionally omitted to prevent modification
-- Only SELECT policies exist (defined in other requirements)

-- Ensure RLS is enforced even for table owner
ALTER TABLE record_state FORCE ROW LEVEL SECURITY;

-- Trigger to update record_state from record_audit events
CREATE OR REPLACE FUNCTION update_state_from_event()
RETURNS TRIGGER AS $$
DECLARE
  v_current_state JSONB;
BEGIN
  -- Get current state or initialize
  SELECT state_data INTO v_current_state
  FROM record_state
  WHERE id = NEW.record_id;

  IF NOT FOUND THEN
    -- Create initial state
    INSERT INTO record_state (id, patient_id, site_id, state_data, version)
    VALUES (NEW.record_id, NEW.patient_id, NEW.site_id, NEW.event_data, 1);
  ELSE
    -- Update existing state by merging event data
    UPDATE record_state
    SET state_data = v_current_state || NEW.event_data,
        version = version + 1,
        updated_at = NEW.event_timestamp
    WHERE id = NEW.record_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_update_state_from_event
  AFTER INSERT ON record_audit
  FOR EACH ROW EXECUTE FUNCTION update_state_from_event();

-- Validation function to verify state integrity
CREATE OR REPLACE FUNCTION validate_state_integrity(p_record_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_derived_state JSONB;
  v_actual_state JSONB;
BEGIN
  -- Derive state by replaying events
  SELECT jsonb_object_agg(key, value ORDER BY event_timestamp)
  INTO v_derived_state
  FROM (
    SELECT (jsonb_each(event_data)).key,
           (jsonb_each(event_data)).value,
           event_timestamp
    FROM record_audit
    WHERE record_id = p_record_id
    ORDER BY event_timestamp
  ) AS events;

  -- Get actual state
  SELECT state_data INTO v_actual_state
  FROM record_state
  WHERE id = p_record_id;

  -- Compare
  RETURN v_derived_state = v_actual_state;
END;
$$ LANGUAGE plpgsql;
```

**Rationale**: Implements event sourcing state protection (o00027) by preventing direct state modification through absence of RLS write policies. SECURITY DEFINER trigger bypasses RLS to update state from events while maintaining event log as single source of truth.

**Acceptance Criteria**:
- Direct modification of `record_state` returns permission denied
- State updates only occur through `record_audit` trigger
- Trigger function executes with SECURITY DEFINER
- State derivation validated against event log
- Version number increments with each event
- Integrity validation function available

*End* *Event Sourcing State Protection RLS Implementation* | **Hash**: a665366e
---

## Implementation Guidelines

### Migration Script Structure

Each RLS policy implementation MUST be deployed via versioned migration script:

```sql
-- Migration: 001_rls_patient_isolation.sql
-- IMPLEMENTS REQUIREMENTS: REQ-d00019
-- Description: Patient data isolation RLS policies

BEGIN;

-- Create helper functions
CREATE OR REPLACE FUNCTION current_user_id() ...

-- Enable RLS
ALTER TABLE record_state ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY patient_isolation_state ON record_state ...

-- Verify deployment
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'record_state'
    AND policyname = 'patient_isolation_state'
  ) THEN
    RAISE EXCEPTION 'Policy deployment failed';
  END IF;
END $$;

COMMIT;
```

### Rollback Script Structure

Each migration MUST include rollback script:

```sql
-- Rollback: 001_rollback.sql
-- Reverts: 001_rls_patient_isolation.sql

BEGIN;

DROP POLICY IF EXISTS patient_isolation_state ON record_state;
DROP FUNCTION IF EXISTS current_user_id();

COMMIT;
```

### Testing Requirements

Each RLS policy MUST include unit tests:

```sql
-- Test: test_patient_isolation.sql
-- Tests: REQ-d00019

-- Setup test data
INSERT INTO auth.users (id, email, role) VALUES
  ('user-1', 'patient1@example.com', 'USER'),
  ('user-2', 'patient2@example.com', 'USER');

-- Set JWT context for patient 1
SET request.jwt.claims = '{"sub": "user-1", "role": "USER"}';

-- Positive test: Can access own data
SELECT assert_equals(
  (SELECT COUNT(*) FROM record_state WHERE patient_id = 'user-1'),
  10,
  'Patient should see own records'
);

-- Negative test: Cannot access other patient data
SELECT assert_equals(
  (SELECT COUNT(*) FROM record_state WHERE patient_id = 'user-2'),
  0,
  'Patient should not see other records'
);
```

---

## Performance Considerations

### Index Strategy

RLS policies with subqueries require proper indexing:

```sql
-- For site assignment lookups
CREATE INDEX idx_investigator_active_sites
  ON investigator_site_assignments(investigator_id, active)
  WHERE active = true;

-- For patient lookups
CREATE INDEX idx_record_state_patient
  ON record_state(patient_id);

-- For site filtering
CREATE INDEX idx_record_state_site
  ON record_state(site_id);
```

### Query Plan Analysis

Monitor policy overhead:

```sql
-- Analyze query with RLS enabled
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM record_state WHERE site_id = 'test-site';

-- Expected overhead: <50ms for patient policies, <100ms for site policies
```

### Caching Strategies

Helper functions should be STABLE to enable caching:

```sql
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS UUID AS $$
  SELECT ...
$$ LANGUAGE SQL STABLE;  -- STABLE enables caching within query
```

---

## Security Considerations

### Service Role Bypass

Service role BYPASSES RLS policies. Use with extreme caution:

```sql
-- Service role can bypass RLS for system operations
-- Only use for:
-- - Trigger functions (SECURITY DEFINER)
-- - Background jobs
-- - Database migrations
```

### JWT Claim Validation

Always validate JWT claims exist before use:

```sql
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS UUID AS $$
  SELECT COALESCE(
    current_setting('request.jwt.claims', true)::json->>'sub',
    NULL  -- Return NULL if claim missing (policy will deny)
  )::UUID;
$$ LANGUAGE SQL STABLE;
```

### Policy Testing in Production

Never disable RLS in production:

```sql
-- NEVER do this in production:
-- ALTER TABLE record_state DISABLE ROW LEVEL SECURITY;

-- Instead, test policies in staging with real JWT tokens
```

---

## References

- **Product Requirements**: prd-security-RLS.md
- **Operations Procedures**: ops-security-RLS.md
- **Database Schema**: dev-database.md
- **PostgreSQL RLS Documentation**: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- **Cloud SQL Documentation**: https://cloud.google.com/sql/docs/postgres

---

## Revision History

| Version | Date | Changes | Author |
| --- | --- | --- | --- |
| 1.0 | 2025-10-26 | Initial RLS implementation requirements | Development Team |

---

**Document Classification**: Internal Use - Development Specifications
**Review Frequency**: After security changes or schema modifications
**Owner**: Backend Engineering Team / Database Team
