-- =====================================================
-- Rollback: 003 - Add Tamper Detection
-- =====================================================

-- This rollback removes the tamper detection functionality added in migration 003.
-- This includes triggers, functions, but preserves any existing signature_hash data.

BEGIN;

-- Log rollback start
DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Starting rollback 003: Remove Tamper Detection';
    RAISE NOTICE 'Timestamp: %', now();
    RAISE NOTICE '================================================';
END $$;

-- Drop trigger first (depends on function)
DROP TRIGGER IF EXISTS compute_audit_hash_trigger ON record_audit;

RAISE NOTICE 'Trigger compute_audit_hash_trigger dropped';

-- Drop functions
DROP FUNCTION IF EXISTS validate_audit_chain(UUID);
DROP FUNCTION IF EXISTS verify_audit_hash(BIGINT);
DROP FUNCTION IF EXISTS compute_audit_hash();

RAISE NOTICE 'Functions dropped successfully';

-- Note: We do NOT drop the signature_hash column itself, as it's part of
-- the original schema. We only remove the automated computation functionality.

-- Verify rollback success
DO $$
BEGIN
    -- Check trigger removed
    IF EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'compute_audit_hash_trigger'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: compute_audit_hash_trigger still exists';
    END IF;

    -- Check functions removed
    IF EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'compute_audit_hash'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: compute_audit_hash function still exists';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'verify_audit_hash'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: verify_audit_hash function still exists';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'validate_audit_chain'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: validate_audit_chain function still exists';
    END IF;

    RAISE NOTICE 'All verification checks passed';
END $$;

COMMIT;

-- Post-rollback notes
DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Rollback 003: Remove Tamper Detection - COMPLETED';
    RAISE NOTICE 'Timestamp: %', now();
    RAISE NOTICE '';
    RAISE NOTICE 'Changes reverted:';
    RAISE NOTICE '  - Removed trigger: compute_audit_hash_trigger';
    RAISE NOTICE '  - Removed function: compute_audit_hash()';
    RAISE NOTICE '  - Removed function: verify_audit_hash(audit_id)';
    RAISE NOTICE '  - Removed function: validate_audit_chain(event_uuid)';
    RAISE NOTICE '';
    RAISE NOTICE 'Note: signature_hash column preserved (part of original schema)';
    RAISE NOTICE 'Note: Existing hash values retained but no longer auto-computed';
    RAISE NOTICE '';
    RAISE NOTICE 'Database is now in state after migration 002';
    RAISE NOTICE '================================================';
END $$;
