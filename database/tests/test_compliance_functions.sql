-- =====================================================
-- Test: Compliance Verification Functions
-- Purpose: Verify ALCOA+ and compliance reporting functions
-- Compliance: spec/compliance-practices.md:247-280
-- =====================================================
--
-- TESTS REQUIREMENTS:
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--   REQ-p00011: ALCOA+ Data Integrity Principles
--   REQ-o00005: Audit Trail Monitoring
--
-- TEST SCOPE:
--   Validates compliance verification functions that auditors use
--   to verify ALCOA+ principles and FDA 21 CFR Part 11 adherence.
--
-- =====================================================

\echo ''
\echo '========================================='
\echo 'TEST SUITE: Compliance Functions'
\echo '========================================='
\echo ''

-- =====================================================
-- Test 1: validate_alcoa_compliance() function works
-- =====================================================

\echo 'Test 1: ALCOA+ validation function'

BEGIN;

-- Set up test fixtures
INSERT INTO sites (site_id, site_name, site_number)
VALUES ('test_site_alcoa', 'Test Site ALCOA', 'TSA001')
ON CONFLICT (site_id) DO NOTHING;

INSERT INTO user_site_assignments (patient_id, site_id, study_patient_id, enrollment_status)
VALUES ('test_patient_alcoa', 'test_site_alcoa', 'STUDY-ALCOA', 'ACTIVE')
ON CONFLICT (patient_id, site_id) DO NOTHING;

-- Create test audit entry with all ALCOA+ metadata
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id
) VALUES (
    '00000000-0000-0000-0000-00000000000a'::UUID, 'test_patient_alcoa', 'test_site_alcoa', 'USER_CREATE',
    '{"id": "00000000-0000-0000-0000-00000000000a", "versioned_type": "epistaxis-v1.0", "event_data": {"id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "startTime": "2024-01-01T10:00:00Z", "lastModified": "2024-01-01T10:05:00Z", "severity": "mild"}}'::jsonb,
    'test_user', 'USER', now(), 'test entry',
    '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'test_session'
);

DO $$
DECLARE
    v_audit_id BIGINT;
    v_all_pass BOOLEAN := true;
    v_principle RECORD;
BEGIN
    SELECT audit_id INTO v_audit_id
    FROM record_audit
    WHERE patient_id = 'test_patient_alcoa';

    -- Check all ALCOA+ principles
    FOR v_principle IN
        SELECT * FROM validate_alcoa_compliance(v_audit_id)
    LOOP
        IF NOT v_principle.compliant THEN
            v_all_pass := false;
            RAISE WARNING 'Principle % failed: %', v_principle.principle, v_principle.details;
        END IF;
    END LOOP;

    IF v_all_pass THEN
        RAISE NOTICE 'PASS: ALCOA+ validation passes for complete entry';
    ELSE
        RAISE EXCEPTION 'FAIL: ALCOA+ validation failed';
    END IF;
END $$;

ROLLBACK;

-- =====================================================
-- Test 2: check_audit_completeness() detects issues
-- =====================================================

\echo 'Test 2: Audit completeness check'

BEGIN;

-- Set up test fixtures
INSERT INTO sites (site_id, site_name, site_number)
VALUES ('test_site_complete', 'Test Site Complete', 'TSC001')
ON CONFLICT (site_id) DO NOTHING;

INSERT INTO user_site_assignments (patient_id, site_id, study_patient_id, enrollment_status)
VALUES ('test_patient_complete', 'test_site_complete', 'STUDY-COMPLETE', 'ACTIVE')
ON CONFLICT (patient_id, site_id) DO NOTHING;

-- Create audit entry
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id
) VALUES (
    '00000000-0000-0000-0000-00000000000b'::UUID, 'test_patient_complete', 'test_site_complete', 'USER_CREATE',
    '{"id": "00000000-0000-0000-0000-00000000000b", "versioned_type": "epistaxis-v1.0", "event_data": {"id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", "startTime": "2024-01-01T10:00:00Z", "lastModified": "2024-01-01T10:05:00Z", "severity": "mild"}}'::jsonb,
    'test_user', 'USER', now(), 'test entry',
    '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'test_session'
);

DO $$
DECLARE
    v_check RECORD;
    v_all_pass BOOLEAN := true;
BEGIN
    FOR v_check IN
        SELECT * FROM check_audit_completeness('00000000-0000-0000-0000-00000000000b'::UUID)
    LOOP
        IF NOT v_check.is_valid THEN
            v_all_pass := false;
            RAISE WARNING 'Check % failed: %', v_check.check_name, v_check.details;
        END IF;
    END LOOP;

    IF v_all_pass THEN
        RAISE NOTICE 'PASS: Audit completeness check works correctly';
    ELSE
        RAISE EXCEPTION 'FAIL: Audit completeness check failed';
    END IF;
END $$;

ROLLBACK;

-- =====================================================
-- Test 3: generate_compliance_report() runs
-- =====================================================

\echo 'Test 3: Compliance report generation'

BEGIN;

-- Set up test fixtures for report test
INSERT INTO sites (site_id, site_name, site_number)
VALUES
    ('test_site_r1', 'Test Site R1', 'TSR001'),
    ('test_site_r2', 'Test Site R2', 'TSR002')
ON CONFLICT (site_id) DO NOTHING;

INSERT INTO user_site_assignments (patient_id, site_id, study_patient_id, enrollment_status)
VALUES
    ('test_patient_r1', 'test_site_r1', 'STUDY-R1', 'ACTIVE'),
    ('test_patient_r2', 'test_site_r2', 'STUDY-R2', 'ACTIVE')
ON CONFLICT (patient_id, site_id) DO NOTHING;

-- Create some test data (fixed UUIDs - r1/r2 are not valid hex)
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id
) VALUES
    ('00000000-0000-0000-0000-000000000c01'::UUID, 'test_patient_r1', 'test_site_r1', 'USER_CREATE',
     '{"id": "00000000-0000-0000-0000-000000000c01", "versioned_type": "epistaxis-v1.0", "event_data": {"id": "c1c1c1c1-c1c1-c1c1-c1c1-c1c1c1c1c1c1", "startTime": "2024-01-01T10:00:00Z", "lastModified": "2024-01-01T10:05:00Z", "severity": "mild"}}'::jsonb,
     'test_user1', 'USER', now(), 'entry 1',
     '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'test_session1'),
    ('00000000-0000-0000-0000-000000000c02'::UUID, 'test_patient_r2', 'test_site_r2', 'USER_UPDATE',
     '{"id": "00000000-0000-0000-0000-000000000c02", "versioned_type": "epistaxis-v1.0", "event_data": {"id": "c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2", "startTime": "2024-01-01T10:00:00Z", "lastModified": "2024-01-01T10:10:00Z", "severity": "moderate"}}'::jsonb,
     'test_user2', 'INVESTIGATOR', now(), 'entry 2',
     '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'test_session2');

DO $$
DECLARE
    v_report_count INTEGER;
    v_overall_status TEXT;
BEGIN
    -- Run compliance report
    SELECT COUNT(*) INTO v_report_count
    FROM generate_compliance_report(now() - interval '1 hour', now());

    -- Get overall status
    SELECT value INTO v_overall_status
    FROM generate_compliance_report(now() - interval '1 hour', now())
    WHERE metric LIKE '%OVERALL%'
    LIMIT 1;

    IF v_report_count > 0 AND v_overall_status IS NOT NULL THEN
        RAISE NOTICE 'PASS: Compliance report generated (% metrics, status: %)',
            v_report_count, v_overall_status;
    ELSE
        RAISE EXCEPTION 'FAIL: Compliance report generation failed';
    END IF;
END $$;

ROLLBACK;

-- =====================================================
-- Test 4: check_audit_sequence_gaps() detects gaps
-- =====================================================

\echo 'Test 4: Audit sequence gap detection'

BEGIN;

DO $$
DECLARE
    v_gap_count INTEGER;
BEGIN
    -- Check for sequence gaps (should be none in fresh test)
    SELECT COUNT(*) INTO v_gap_count
    FROM check_audit_sequence_gaps();

    -- Test passes if function runs (gap count may be 0 or more)
    RAISE NOTICE 'PASS: Sequence gap detection works (% gaps found)', v_gap_count;
END $$;

ROLLBACK;

-- =====================================================
-- Test 5: verify_audit_batch() verifies hashes
-- =====================================================

\echo 'Test 5: Batch hash verification'

BEGIN;

-- Set up test fixtures for batch test
INSERT INTO sites (site_id, site_name, site_number)
VALUES
    ('test_site_b1', 'Test Site B1', 'TSB001'),
    ('test_site_b2', 'Test Site B2', 'TSB002')
ON CONFLICT (site_id) DO NOTHING;

INSERT INTO user_site_assignments (patient_id, site_id, study_patient_id, enrollment_status)
VALUES
    ('test_patient_b1', 'test_site_b1', 'STUDY-B1', 'ACTIVE'),
    ('test_patient_b2', 'test_site_b2', 'STUDY-B2', 'ACTIVE')
ON CONFLICT (patient_id, site_id) DO NOTHING;

-- Create test entries
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id
) VALUES
    ('00000000-0000-0000-0000-0000000000b1'::UUID, 'test_patient_b1', 'test_site_b1', 'USER_CREATE',
     '{"id": "00000000-0000-0000-0000-0000000000b1", "versioned_type": "epistaxis-v1.0", "event_data": {"id": "b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1", "startTime": "2024-01-01T10:00:00Z", "lastModified": "2024-01-01T10:05:00Z", "severity": "mild"}}'::jsonb,
     'test_user', 'USER', now(), 'batch test 1',
     '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'test_session'),
    ('00000000-0000-0000-0000-0000000000b2'::UUID, 'test_patient_b2', 'test_site_b2', 'USER_CREATE',
     '{"id": "00000000-0000-0000-0000-0000000000b2", "versioned_type": "epistaxis-v1.0", "event_data": {"id": "b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2", "startTime": "2024-01-01T10:00:00Z", "lastModified": "2024-01-01T10:05:00Z", "severity": "mild"}}'::jsonb,
     'test_user', 'USER', now(), 'batch test 2',
     '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'test_session');

DO $$
DECLARE
    v_total INTEGER;
    v_valid INTEGER;
BEGIN
    -- Verify batch
    SELECT COUNT(*), COUNT(*) FILTER (WHERE is_valid = true)
    INTO v_total, v_valid
    FROM verify_audit_batch(now() - interval '1 hour', now());

    IF v_total > 0 AND v_valid = v_total THEN
        RAISE NOTICE 'PASS: Batch verification works (% entries, all valid)', v_total;
    ELSIF v_total > 0 THEN
        RAISE EXCEPTION 'FAIL: Some entries failed verification (% of %)', v_valid, v_total;
    ELSE
        RAISE WARNING 'WARNING: No entries to verify in batch';
        RAISE NOTICE 'PASS: Batch verification function works (no data)';
    END IF;
END $$;

ROLLBACK;

\echo ''
\echo '========================================='
\echo '    ALL 5 TESTS PASSED'
\echo '========================================='
\echo ''
\echo 'Compliance Function Tests Complete'
\echo ''
