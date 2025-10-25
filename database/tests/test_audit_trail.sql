-- =====================================================
-- Test: Audit Trail Immutability and Integrity
-- Purpose: Verify FDA 21 CFR Part 11 compliance
-- Compliance: spec/compliance-practices.md:120-167
-- =====================================================
--
-- TESTS REQUIREMENTS:
--   REQ-p00004: Immutable Audit Trail via Event Sourcing
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--   REQ-p00011: ALCOA+ Data Integrity Principles
--
-- TEST SCOPE:
--   Validates that audit trail records are immutable (no UPDATE/DELETE)
--   and maintain cryptographic integrity per FDA 21 CFR Part 11.
--
-- =====================================================

\echo ''
\echo '========================================='
\echo 'TEST SUITE: Audit Trail Immutability'
\echo '========================================='
\echo ''

-- =====================================================
-- Test 1: Audit entries cannot be updated
-- =====================================================

\echo 'Test 1: Audit entries cannot be updated'

BEGIN;

-- Insert test audit entry
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id
) VALUES (
    'test-uuid-001'::UUID, 'test_patient_001', 'test_site_001', 'USER_CREATE',
    '{"test": "data"}'::jsonb, 'test_user', 'USER', now(), 'test entry',
    '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'test_session'
);

-- Attempt update (should be prevented by rule)
DO $$
DECLARE
    v_original_data JSONB;
    v_updated_data JSONB;
BEGIN
    -- Store original value
    SELECT data INTO v_original_data
    FROM record_audit
    WHERE patient_id = 'test_patient_001';

    -- Attempt to update
    UPDATE record_audit
    SET data = '{"modified": "data"}'::jsonb
    WHERE patient_id = 'test_patient_001';

    -- Check if data unchanged
    SELECT data INTO v_updated_data
    FROM record_audit
    WHERE patient_id = 'test_patient_001';

    IF v_original_data = v_updated_data THEN
        RAISE NOTICE 'PASS: Audit entry is immutable (UPDATE prevented)';
    ELSE
        RAISE EXCEPTION 'FAIL: Audit entry was modified';
    END IF;
END $$;

ROLLBACK;

-- =====================================================
-- Test 2: Audit entries cannot be deleted
-- =====================================================

\echo 'Test 2: Audit entries cannot be deleted'

BEGIN;

INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id
) VALUES (
    'test-uuid-002'::UUID, 'test_patient_002', 'test_site_002', 'USER_CREATE',
    '{"test": "data"}'::jsonb, 'test_user', 'USER', now(), 'test entry',
    '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'test_session'
);

DO $$
DECLARE
    v_count_before INTEGER;
    v_count_after INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count_before
    FROM record_audit
    WHERE patient_id = 'test_patient_002';

    -- Attempt to delete
    DELETE FROM record_audit
    WHERE patient_id = 'test_patient_002';

    SELECT COUNT(*) INTO v_count_after
    FROM record_audit
    WHERE patient_id = 'test_patient_002';

    IF v_count_before = v_count_after AND v_count_after > 0 THEN
        RAISE NOTICE 'PASS: Audit entry cannot be deleted (permanent)';
    ELSE
        RAISE EXCEPTION 'FAIL: Audit entry was deleted';
    END IF;
END $$;

ROLLBACK;

-- =====================================================
-- Test 3: Signature hash is automatically computed
-- =====================================================

\echo 'Test 3: Signature hash automatically computed'

BEGIN;

INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id
) VALUES (
    'test-uuid-003'::UUID, 'test_patient_003', 'test_site_003', 'USER_CREATE',
    '{"test": "data"}'::jsonb, 'test_user', 'USER', now(), 'test entry',
    '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'test_session'
);

DO $$
DECLARE
    v_hash TEXT;
BEGIN
    SELECT signature_hash INTO v_hash
    FROM record_audit
    WHERE patient_id = 'test_patient_003';

    IF v_hash IS NOT NULL AND length(v_hash) = 64 THEN
        RAISE NOTICE 'PASS: Signature hash automatically computed (SHA-256)';
    ELSE
        RAISE EXCEPTION 'FAIL: Signature hash not computed or invalid';
    END IF;
END $$;

ROLLBACK;

-- =====================================================
-- Test 4: Hash verification works correctly
-- =====================================================

\echo 'Test 4: Hash verification works correctly'

BEGIN;

INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id
) VALUES (
    'test-uuid-004'::UUID, 'test_patient_004', 'test_site_004', 'USER_CREATE',
    '{"test": "data"}'::jsonb, 'test_user', 'USER', now(), 'test entry',
    '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'test_session'
);

DO $$
DECLARE
    v_audit_id BIGINT;
    v_is_valid BOOLEAN;
BEGIN
    SELECT audit_id INTO v_audit_id
    FROM record_audit
    WHERE patient_id = 'test_patient_004';

    v_is_valid := verify_audit_hash(v_audit_id);

    IF v_is_valid THEN
        RAISE NOTICE 'PASS: Hash verification passes for valid entry';
    ELSE
        RAISE EXCEPTION 'FAIL: Hash verification failed for valid entry';
    END IF;
END $$;

ROLLBACK;

-- =====================================================
-- Test 5: Read model is automatically updated
-- =====================================================

\echo 'Test 5: Read model automatically updated from audit'

BEGIN;

INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id
) VALUES (
    'test-uuid-005'::UUID, 'test_patient_005', 'test_site_005', 'USER_CREATE',
    '{"symptoms": ["headache"]}'::jsonb, 'test_user', 'USER', now(), 'initial entry',
    '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'test_session'
);

DO $$
DECLARE
    v_state_exists BOOLEAN;
    v_state_data JSONB;
BEGIN
    v_state_exists := EXISTS(
        SELECT 1 FROM record_state
        WHERE event_uuid = 'test-uuid-005'::UUID
    );

    SELECT current_data INTO v_state_data
    FROM record_state
    WHERE event_uuid = 'test-uuid-005'::UUID;

    IF v_state_exists AND v_state_data->>'symptoms' = '["headache"]' THEN
        RAISE NOTICE 'PASS: Read model automatically updated via trigger';
    ELSE
        RAISE EXCEPTION 'FAIL: Read model not updated or data mismatch';
    END IF;
END $$;

ROLLBACK;

-- =====================================================
-- Test 6: All required metadata is captured
-- =====================================================

\echo 'Test 6: All required metadata captured'

BEGIN;

INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id
) VALUES (
    'test-uuid-006'::UUID, 'test_patient_006', 'test_site_006', 'USER_CREATE',
    '{"test": "data"}'::jsonb, 'test_user', 'USER', now(), 'test entry',
    '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'test_session'
);

DO $$
DECLARE
    v_record RECORD;
    v_all_present BOOLEAN := true;
BEGIN
    SELECT * INTO v_record
    FROM record_audit
    WHERE patient_id = 'test_patient_006';

    -- Check all required ALCOA+ fields
    IF v_record.created_by IS NULL THEN v_all_present := false; END IF;
    IF v_record.role IS NULL THEN v_all_present := false; END IF;
    IF v_record.client_timestamp IS NULL THEN v_all_present := false; END IF;
    IF v_record.server_timestamp IS NULL THEN v_all_present := false; END IF;
    IF v_record.change_reason IS NULL THEN v_all_present := false; END IF;
    IF v_record.device_info IS NULL THEN v_all_present := false; END IF;
    IF v_record.ip_address IS NULL THEN v_all_present := false; END IF;
    IF v_record.session_id IS NULL THEN v_all_present := false; END IF;
    IF v_record.signature_hash IS NULL THEN v_all_present := false; END IF;

    IF v_all_present THEN
        RAISE NOTICE 'PASS: All ALCOA+ metadata fields captured';
    ELSE
        RAISE EXCEPTION 'FAIL: Missing required metadata fields';
    END IF;
END $$;

ROLLBACK;

-- =====================================================
-- Test 7: Audit chain validation
-- =====================================================

\echo 'Test 7: Audit chain validation'

BEGIN;

-- Create parent entry
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id
) VALUES (
    'test-uuid-007'::UUID, 'test_patient_007', 'test_site_007', 'USER_CREATE',
    '{"value": 1}'::jsonb, 'test_user', 'USER', now(), 'initial',
    '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'test_session'
);

-- Create child entry with parent reference
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation,
    data, created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id, parent_audit_id
) VALUES (
    'test-uuid-007'::UUID, 'test_patient_007', 'test_site_007', 'USER_UPDATE',
    '{"value": 2}'::jsonb, 'test_user', 'USER', now(), 'update',
    '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'test_session',
    (SELECT audit_id FROM record_audit WHERE patient_id = 'test_patient_007' ORDER BY audit_id LIMIT 1)
);

DO $$
DECLARE
    v_chain_valid BOOLEAN;
BEGIN
    -- Validate audit chain
    v_chain_valid := NOT EXISTS(
        SELECT 1 FROM validate_audit_chain('test-uuid-007'::UUID)
        WHERE is_valid = false
    );

    IF v_chain_valid THEN
        RAISE NOTICE 'PASS: Audit chain validation works correctly';
    ELSE
        RAISE EXCEPTION 'FAIL: Audit chain validation failed';
    END IF;
END $$;

ROLLBACK;

\echo ''
\echo '========================================='
\echo 'Audit Trail Tests Complete'
\echo '========================================='
\echo ''
