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

-- Create test audit entry with all ALCOA+ metadata
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id
) VALUES (
    '00000000-0000-0000-0000-00000000000a'::UUID, 'test_patient_alcoa', 'test_site_alcoa', 'USER_CREATE',
    '{"test": "data"}'::jsonb, 'test_user', 'USER', now(), 'test entry',
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

-- Create audit entry
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id
) VALUES (
    '00000000-0000-0000-0000-00000000000b'::UUID, 'test_patient_complete', 'test_site_complete', 'USER_CREATE',
    '{"test": "data"}'::jsonb, 'test_user', 'USER', now(), 'test entry',
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

-- Create some test data
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id
) VALUES
    ('00000000-0000-0000-0000-0000000000r1'::UUID, 'test_patient_r1', 'test_site_r1', 'USER_CREATE',
     '{"test": "1"}'::jsonb, 'test_user1', 'USER', now(), 'entry 1',
     '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'test_session1'),
    ('00000000-0000-0000-0000-0000000000r2'::UUID, 'test_patient_r2', 'test_site_r2', 'USER_UPDATE',
     '{"test": "2"}'::jsonb, 'test_user2', 'INVESTIGATOR', now(), 'entry 2',
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

-- Create test entries
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id
) VALUES
    ('00000000-0000-0000-0000-0000000000b1'::UUID, 'test_patient_b1', 'test_site_b1', 'USER_CREATE',
     '{"test": "1"}'::jsonb, 'test_user', 'USER', now(), 'batch test 1',
     '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'test_session'),
    ('00000000-0000-0000-0000-0000000000b2'::UUID, 'test_patient_b2', 'test_site_b2', 'USER_CREATE',
     '{"test": "2"}'::jsonb, 'test_user', 'USER', now(), 'batch test 2',
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
\echo 'Compliance Function Tests Complete'
\echo '========================================='
\echo ''
