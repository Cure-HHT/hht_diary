# Supabase Deployment Guide

## Overview

This guide covers deploying JSONB validation functions and RLS policies to your Supabase database.

## IMPLEMENTS REQUIREMENTS

- REQ-o00004: Database Schema Deployment
- REQ-o00027: Event Sourcing State Protection Policy Deployment
- REQ-d00007: Database Schema Implementation and Deployment

---

## Single Source of Truth for Schemas

### Schema Definition Hierarchy

**The authoritative source for event schemas is:**

1. **spec/JSONB_SCHEMA.md** - Primary documentation defining data structures
2. **database/schema.sql** (validation functions) - Enforces the schema at database level
3. **database/dart/models.dart** - Implements the schema in the application

These must stay synchronized. When making schema changes:

1. Update `spec/JSONB_SCHEMA.md` first (documentation)
2. Update validation functions in migration scripts
3. Update Dart models to match
4. Run tests to verify synchronization

### Current Event Types

**Epistaxis (Nosebleed) Events**
- Version: `epistaxis-v1.0`
- Single definition in spec/JSONB_SCHEMA.md
- Validated by `validate_epistaxis_data()` function
- Implemented in `EpistaxisRecord` class

**Survey Events**
- Version: `survey-v1.0`
- **Generic structure** that can accommodate multiple survey types
- Validated by `validate_survey_data()` function
- Implemented in `SurveyRecord` class

### Planned Survey Types

You mentioned two surveys are planned. The current `survey-v1.0` structure is generic and can handle different survey types through:

1. **Question IDs** - Use prefixed IDs to distinguish surveys:
   - QoL Survey: `qol_q1_pain`, `qol_q2_fatigue`, etc.
   - Symptom Survey: `symptom_q1_frequency`, `symptom_q2_severity`, etc.

2. **Versioned Types** - Alternatively, create specific types:
   - `quality_of_life-v1.0`
   - `symptom_survey-v1.0`

**Recommendation**: Start with the generic `survey-v1.0` structure. If surveys need different validation rules, create separate versioned types later.

---

## Prerequisites

### 1. Supabase Project Setup

- Active Supabase project
- Database connection details
- Admin/service role access

### 2. Local Environment

```bash
# Install Supabase CLI (if not already installed)
npm install -g supabase

# Or use brew on macOS
brew install supabase/tap/supabase
```

### 3. Link to Your Project

```bash
# In your project directory
supabase link --project-ref <your-project-ref>

# Login if needed
supabase login
```

---

## Deployment Steps

### Step 1: Deploy Base Schema (if not already done)

```bash
# Deploy the base schema
supabase db push database/schema.sql
```

Verify in Supabase Dashboard:
- Navigate to **Database** → **Tables**
- Check that `record_audit`, `record_state`, and other tables exist

### Step 2: Deploy JSONB Validation Functions

```bash
# Deploy migration 008
supabase db push database/migrations/008_add_jsonb_validation.sql
```

**Verify deployment:**

1. Go to Supabase Dashboard → **SQL Editor**
2. Run this test query:

```sql
-- Test UUID validation
SELECT is_valid_uuid('550e8400-e29b-41d4-a716-446655440000') AS valid_uuid;
-- Should return: true

-- Test ISO 8601 validation
SELECT is_valid_iso8601('2025-10-15T14:30:00-05:00') AS valid_timestamp;
-- Should return: true

-- Test main validator exists
SELECT proname, prokind
FROM pg_proc
WHERE proname IN ('validate_diary_data', 'validate_epistaxis_data', 'validate_survey_data');
-- Should return 3 rows
```

### Step 3: Test Validation Functions

Run comprehensive tests in Supabase **SQL Editor**:

```sql
-- =====================================================
-- TEST 1: Valid Epistaxis Event
-- =====================================================
DO $$
BEGIN
    PERFORM validate_diary_data('{
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "versioned_type": "epistaxis-v1.0",
        "event_data": {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "startTime": "2025-10-15T14:30:00-05:00",
            "endTime": "2025-10-15T14:45:00-05:00",
            "severity": "moderate",
            "user_notes": "Test event",
            "lastModified": "2025-10-15T14:50:00-05:00"
        }
    }'::jsonb);

    RAISE NOTICE 'TEST 1 PASSED: Valid epistaxis event accepted';
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'TEST 1 FAILED: %', SQLERRM;
END $$;

-- =====================================================
-- TEST 2: Invalid Severity Enum (Should Fail)
-- =====================================================
DO $$
BEGIN
    PERFORM validate_diary_data('{
        "id": "550e8400-e29b-41d4-a716-446655440001",
        "versioned_type": "epistaxis-v1.0",
        "event_data": {
            "id": "550e8400-e29b-41d4-a716-446655440001",
            "startTime": "2025-10-15T14:30:00-05:00",
            "severity": "INVALID_SEVERITY",
            "lastModified": "2025-10-15T14:50:00-05:00"
        }
    }'::jsonb);

    RAISE EXCEPTION 'TEST 2 FAILED: Invalid severity should have been rejected';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE '%Invalid severity%' THEN
            RAISE NOTICE 'TEST 2 PASSED: Invalid severity correctly rejected';
        ELSE
            RAISE EXCEPTION 'TEST 2 FAILED: Unexpected error: %', SQLERRM;
        END IF;
END $$;

-- =====================================================
-- TEST 3: Mutual Exclusivity Violation (Should Fail)
-- =====================================================
DO $$
BEGIN
    PERFORM validate_diary_data('{
        "id": "550e8400-e29b-41d4-a716-446655440002",
        "versioned_type": "epistaxis-v1.0",
        "event_data": {
            "id": "550e8400-e29b-41d4-a716-446655440002",
            "startTime": "2025-10-15T14:30:00-05:00",
            "isNoNosebleedsEvent": true,
            "isUnknownNosebleedsEvent": true,
            "lastModified": "2025-10-15T14:50:00-05:00"
        }
    }'::jsonb);

    RAISE EXCEPTION 'TEST 3 FAILED: Mutual exclusivity violation should have been rejected';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE '%cannot both be true%' THEN
            RAISE NOTICE 'TEST 3 PASSED: Mutual exclusivity correctly enforced';
        ELSE
            RAISE EXCEPTION 'TEST 3 FAILED: Unexpected error: %', SQLERRM;
        END IF;
END $$;

-- =====================================================
-- TEST 4: Valid Survey Event
-- =====================================================
DO $$
BEGIN
    PERFORM validate_diary_data('{
        "id": "550e8400-e29b-41d4-a716-446655440003",
        "versioned_type": "survey-v1.0",
        "event_data": {
            "id": "550e8400-e29b-41d4-a716-446655440003",
            "completedAt": "2025-10-15T15:00:00-05:00",
            "survey": [
                {
                    "question_id": "q1",
                    "question_text": "Test question?",
                    "response": "answer"
                }
            ],
            "lastModified": "2025-10-15T15:00:00-05:00"
        }
    }'::jsonb);

    RAISE NOTICE 'TEST 4 PASSED: Valid survey event accepted';
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'TEST 4 FAILED: %', SQLERRM;
END $$;

-- =====================================================
-- TEST 5: Invalid Versioned Type (Should Fail)
-- =====================================================
DO $$
BEGIN
    PERFORM validate_diary_data('{
        "id": "550e8400-e29b-41d4-a716-446655440004",
        "versioned_type": "invalid_type",
        "event_data": {}
    }'::jsonb);

    RAISE EXCEPTION 'TEST 5 FAILED: Invalid versioned_type should have been rejected';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE '%Invalid versioned_type format%' THEN
            RAISE NOTICE 'TEST 5 PASSED: Invalid versioned_type correctly rejected';
        ELSE
            RAISE EXCEPTION 'TEST 5 FAILED: Unexpected error: %', SQLERRM;
        END IF;
END $$;
```

**Expected output:**
```
NOTICE:  TEST 1 PASSED: Valid epistaxis event accepted
NOTICE:  TEST 2 PASSED: Invalid severity correctly rejected
NOTICE:  TEST 3 PASSED: Mutual exclusivity correctly enforced
NOTICE:  TEST 4 PASSED: Valid survey event accepted
NOTICE:  TEST 5 PASSED: Invalid versioned_type correctly rejected
```

### Step 4: Deploy RLS Policies

```bash
# Deploy migration 009
supabase db push database/migrations/009_configure_rls.sql
```

**Verify deployment:**

```sql
-- Check RLS is enabled on critical tables
SELECT
    schemaname,
    tablename,
    rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename IN ('record_audit', 'record_state')
ORDER BY tablename;
-- Both should show rls_enabled = true

-- Count policies per table
SELECT
    tablename,
    COUNT(*) AS policy_count
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;

-- Check critical user isolation policies exist
SELECT
    tablename,
    policyname,
    cmd,
    qual
FROM pg_policies
WHERE schemaname = 'public'
    AND policyname IN ('audit_user_select', 'state_user_select')
ORDER BY tablename, policyname;
```

### Step 5: Test RLS Policies

This requires creating test users with different roles. In Supabase Dashboard:

1. **Create Test Site**:

```sql
INSERT INTO sites (site_id, site_name, site_number, is_active)
VALUES ('test_site_001', 'Test Clinical Site', 'SITE-001', true);
```

2. **Create Test Users** (via Supabase Auth dashboard):
   - User 1: `test-user-1@example.com` (role: USER)
   - User 2: `test-user-2@example.com` (role: USER)

3. **Assign Users to Site**:

```sql
-- Get user IDs from Supabase Auth
-- Replace <user1_id> and <user2_id> with actual UUIDs

INSERT INTO user_site_assignments (patient_id, site_id, study_patient_id, enrollment_status)
VALUES
    ('<user1_id>', 'test_site_001', 'PATIENT-001', 'ACTIVE'),
    ('<user2_id>', 'test_site_001', 'PATIENT-002', 'ACTIVE');
```

4. **Test User Isolation**:

Login as User 1 and run:

```sql
-- This should return 0 rows (User 1 cannot see User 2's data)
SELECT COUNT(*)
FROM record_state
WHERE patient_id = '<user2_id>';

-- This should return only User 1's data
SELECT COUNT(*)
FROM record_state
WHERE patient_id = current_user_id();
```

### Step 6: Test Complete Data Flow

Insert a valid event through the audit table:

```sql
-- Insert as authenticated user
INSERT INTO record_audit (
    event_uuid,
    patient_id,
    site_id,
    operation,
    data,
    created_by,
    role,
    client_timestamp,
    change_reason
) VALUES (
    gen_random_uuid(),
    current_user_id(), -- Will be set by JWT
    'test_site_001',
    'USER_CREATE',
    '{
        "id": "550e8400-e29b-41d4-a716-446655440010",
        "versioned_type": "epistaxis-v1.0",
        "event_data": {
            "id": "550e8400-e29b-41d4-a716-446655440010",
            "startTime": "2025-10-15T14:30:00-05:00",
            "severity": "moderate",
            "user_notes": "Integration test event",
            "lastModified": "2025-10-15T14:50:00-05:00"
        }
    }'::jsonb,
    current_user_id(),
    'USER',
    now(),
    'Integration test'
);

-- Verify validation was applied
-- If invalid data, the insert should fail with validation error
```

---

## Rollback Procedures

### Rollback RLS Configuration

```bash
supabase db push database/migrations/rollback/009_rollback.sql
```

### Rollback Validation Functions

```bash
supabase db push database/migrations/rollback/008_rollback.sql
```

---

## Common Issues and Solutions

### Issue 1: Function Already Exists

**Error**: `function "validate_diary_data" already exists`

**Solution**: Use `CREATE OR REPLACE FUNCTION` (already in migration scripts)

### Issue 2: RLS Blocks All Access

**Symptom**: Users cannot see any data

**Check**:
1. Verify JWT token contains correct user ID
2. Check `current_user_id()` function returns correct value
3. Verify user is assigned to a site in `user_site_assignments`

**Debug query**:
```sql
SELECT
    current_user_id() AS current_user,
    current_user_role() AS current_role,
    current_setting('request.jwt.claims', true) AS jwt_claims;
```

### Issue 3: Validation Too Strict

**Symptom**: Valid data rejected by validator

**Debug**:
1. Test validation function directly:
   ```sql
   SELECT validate_diary_data('<your_json>'::jsonb);
   ```
2. Check error message for specific validation failure
3. Verify data matches spec/JSONB_SCHEMA.md exactly

### Issue 4: Service Role Needed

**Symptom**: Triggers cannot update `record_state`

**Solution**: Ensure service role has full access (already in migration)

```sql
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
```

---

## Post-Deployment Checklist

- [ ] All validation functions deployed
- [ ] Validation tests pass (5 tests above)
- [ ] RLS enabled on all tables
- [ ] User isolation policies verified
- [ ] Test users created and assigned
- [ ] Sample data inserted successfully
- [ ] Application can connect and insert data
- [ ] Rollback scripts tested

---

## Monitoring

### Query Performance

```sql
-- Check slow queries related to RLS
SELECT
    query,
    mean_exec_time,
    calls
FROM pg_stat_statements
WHERE query LIKE '%record_state%'
    OR query LIKE '%record_audit%'
ORDER BY mean_exec_time DESC
LIMIT 10;
```

### Policy Usage

```sql
-- Check which policies are being applied
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

### Validation Errors

Monitor application logs for validation errors. Common patterns:

- `Missing required field` - Check application is sending complete data
- `Invalid UUID format` - Check UUID generation in app
- `Invalid severity value` - Check enum values match exactly
- `Invalid ISO 8601 format` - Check timestamp serialization

---

## Next Steps

1. **Configure Authentication Roles**: Set up custom claims in Supabase Auth to include user roles
2. **Create Site Assignments**: Assign all users to their respective sites
3. **Set Up Investigator Access**: Create investigator accounts and site assignments
4. **Deploy Application**: Configure Flutter app with Supabase credentials
5. **Run Integration Tests**: Test complete flow from app to database

---

## Support

- **Schema Questions**: Refer to `spec/JSONB_SCHEMA.md`
- **RLS Issues**: Check `database/rls_policies.sql`
- **Validation Errors**: See validation functions in migration 008

---

## Appendix: Quick Reference

### Validation Function Signatures

```sql
is_valid_uuid(uuid_string TEXT) RETURNS BOOLEAN
is_valid_iso8601(timestamp_string TEXT) RETURNS BOOLEAN
validate_epistaxis_data(event_data JSONB) RETURNS BOOLEAN
validate_survey_data(event_data JSONB) RETURNS BOOLEAN
validate_diary_data(data JSONB) RETURNS BOOLEAN
```

### Critical RLS Policies

| Table | Policy | Purpose |
| --- | --- | --- |
| `record_audit` | `audit_user_select` | Users see only their audit entries |
| `record_audit` | `audit_user_insert` | Users insert only their own entries |
| `record_state` | `state_user_select` | Users see only their diary entries |
| `record_state` | `state_user_insert` | Direct inserts blocked |
| `record_state` | `state_service_all` | Service role can modify for triggers |

### Event Type Versions

| Type | Version | Status |
| --- | --- | --- |
| `epistaxis` | v1.0 | Production |
| `survey` | v1.0 | Production (generic) |
| `quality_of_life` | v1.0 | Planned |
| `symptom_survey` | v1.0 | Planned |
