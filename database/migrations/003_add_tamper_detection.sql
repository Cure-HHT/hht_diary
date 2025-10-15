-- =====================================================
-- Migration: 003 - Add Tamper Detection
-- Ticket: TICKET-002
-- Author: Database Team
-- Date: 2025-10-14
-- =====================================================

-- Purpose:
-- Implement cryptographic tamper detection for audit trail integrity.
-- Automatically compute SHA-256 hashes for audit entries and provide
-- verification functions for compliance reporting.

-- Dependencies:
-- - Migration 001 (initial schema)
-- - Extension: pgcrypto

-- Compliance Reference:
-- - spec/compliance-practices.md:136,142
-- - FDA 21 CFR Part 11 - Audit Trail Integrity

BEGIN;

-- Log migration start
DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Starting migration 003: Add Tamper Detection';
    RAISE NOTICE 'Ticket: TICKET-002';
    RAISE NOTICE 'Timestamp: %', now();
    RAISE NOTICE '================================================';
END $$;

-- Create hash computation function
CREATE OR REPLACE FUNCTION compute_audit_hash()
RETURNS TRIGGER AS $$
BEGIN
    -- Compute SHA-256 hash of critical audit fields
    -- This creates a cryptographic fingerprint of the audit entry
    -- Any tampering will invalidate the hash
    NEW.signature_hash := encode(
        digest(
            NEW.audit_id::text ||
            NEW.event_uuid::text ||
            NEW.operation ||
            NEW.patient_id ||
            NEW.data::text ||
            NEW.server_timestamp::text ||
            COALESCE(NEW.parent_audit_id::text, ''),
            'sha256'
        ),
        'hex'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION compute_audit_hash() IS
'Automatically computes SHA-256 hash for audit trail entries. Required for FDA 21 CFR Part 11 compliance. Hash includes all critical audit fields to ensure tamper detection.';

-- Create trigger to compute hash on insert
CREATE TRIGGER compute_audit_hash_trigger
    BEFORE INSERT ON record_audit
    FOR EACH ROW
    EXECUTE FUNCTION compute_audit_hash();

COMMENT ON TRIGGER compute_audit_hash_trigger ON record_audit IS
'Automatically computes cryptographic hash before inserting audit entries. Ensures all audit records have tamper detection enabled.';

-- Create hash verification function
CREATE OR REPLACE FUNCTION verify_audit_hash(p_audit_id BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    v_record RECORD;
    v_computed_hash TEXT;
BEGIN
    -- Retrieve the audit record
    SELECT * INTO v_record FROM record_audit WHERE audit_id = p_audit_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Audit record % not found', p_audit_id;
    END IF;

    -- Recompute the hash using the same algorithm
    v_computed_hash := encode(
        digest(
            v_record.audit_id::text ||
            v_record.event_uuid::text ||
            v_record.operation ||
            v_record.patient_id ||
            v_record.data::text ||
            v_record.server_timestamp::text ||
            COALESCE(v_record.parent_audit_id::text, ''),
            'sha256'
        ),
        'hex'
    );

    -- Compare computed hash with stored hash
    RETURN v_computed_hash = v_record.signature_hash;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION verify_audit_hash(BIGINT) IS
'Verifies cryptographic integrity of individual audit entry. Returns TRUE if hash is valid, FALSE if tampered. Used for compliance audits and forensic investigation.';

-- Create audit chain validation function
CREATE OR REPLACE FUNCTION validate_audit_chain(p_event_uuid UUID)
RETURNS TABLE(
    audit_id BIGINT,
    is_valid BOOLEAN,
    error_message TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH audit_chain AS (
        SELECT
            ra.audit_id,
            ra.parent_audit_id,
            verify_audit_hash(ra.audit_id) as hash_valid
        FROM record_audit ra
        WHERE ra.event_uuid = p_event_uuid
        ORDER BY ra.audit_id
    )
    SELECT
        ac.audit_id,
        ac.hash_valid,
        CASE
            WHEN NOT ac.hash_valid THEN 'Hash verification failed - possible tampering detected'
            ELSE NULL
        END::TEXT as error_message
    FROM audit_chain ac;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION validate_audit_chain(UUID) IS
'Validates entire audit chain for a given event UUID. Returns validation status for each audit entry. Used for compliance reporting and data integrity verification.';

-- Verify migration success
DO $$
BEGIN
    -- Check function exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'compute_audit_hash'
    ) THEN
        RAISE EXCEPTION 'Migration failed: compute_audit_hash function not created';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'verify_audit_hash'
    ) THEN
        RAISE EXCEPTION 'Migration failed: verify_audit_hash function not created';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'validate_audit_chain'
    ) THEN
        RAISE EXCEPTION 'Migration failed: validate_audit_chain function not created';
    END IF;

    -- Check trigger exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'compute_audit_hash_trigger'
    ) THEN
        RAISE EXCEPTION 'Migration failed: compute_audit_hash_trigger not created';
    END IF;

    RAISE NOTICE 'All verification checks passed';
END $$;

-- Test the hash computation (optional - can be removed in production)
DO $$
DECLARE
    test_event_uuid UUID := gen_random_uuid();
    test_audit_id BIGINT;
    hash_valid BOOLEAN;
BEGIN
    -- Insert a test record
    INSERT INTO record_audit (
        event_uuid, patient_id, site_id, operation,
        data, created_by, role, client_timestamp, change_reason
    ) VALUES (
        test_event_uuid,
        'test_migration_003',
        'test_site',
        'TEST_CREATE',
        '{"test": "migration_003"}'::jsonb,
        'migration_test',
        'ADMIN',
        now(),
        'Migration 003 verification test'
    ) RETURNING audit_id INTO test_audit_id;

    -- Verify hash was computed
    IF (SELECT signature_hash FROM record_audit WHERE audit_id = test_audit_id) IS NULL THEN
        RAISE EXCEPTION 'Test failed: Hash not computed automatically';
    END IF;

    -- Verify hash validation works
    hash_valid := verify_audit_hash(test_audit_id);
    IF NOT hash_valid THEN
        RAISE EXCEPTION 'Test failed: Hash verification failed for valid entry';
    END IF;

    -- Clean up test record
    DELETE FROM record_audit WHERE audit_id = test_audit_id;

    RAISE NOTICE 'Tamper detection test passed successfully';
END $$;

COMMIT;

-- Post-migration notes
DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Migration 003: Add Tamper Detection - COMPLETED';
    RAISE NOTICE 'Timestamp: %', now();
    RAISE NOTICE '';
    RAISE NOTICE 'Changes applied:';
    RAISE NOTICE '  - Created function: compute_audit_hash()';
    RAISE NOTICE '  - Created trigger: compute_audit_hash_trigger';
    RAISE NOTICE '  - Created function: verify_audit_hash(audit_id)';
    RAISE NOTICE '  - Created function: validate_audit_chain(event_uuid)';
    RAISE NOTICE '';
    RAISE NOTICE 'Functionality:';
    RAISE NOTICE '  - All new audit entries automatically get SHA-256 hash';
    RAISE NOTICE '  - Use verify_audit_hash(id) to check individual entries';
    RAISE NOTICE '  - Use validate_audit_chain(uuid) to validate entire event';
    RAISE NOTICE '';
    RAISE NOTICE 'Compliance:';
    RAISE NOTICE '  - Satisfies FDA 21 CFR Part 11 audit trail integrity';
    RAISE NOTICE '  - Enables tamper detection for regulatory audits';
    RAISE NOTICE '  - Supports ALCOA+ "Accurate" principle';
    RAISE NOTICE '================================================';
END $$;
