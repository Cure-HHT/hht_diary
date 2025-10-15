-- =====================================================
-- Rollback: 002 - Add Audit Metadata Fields
-- =====================================================

-- This rollback removes the audit metadata fields added in migration 002.
-- This is safe to run as these fields are additive only.

BEGIN;

-- Log rollback start
DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Starting rollback 002: Remove Audit Metadata Fields';
    RAISE NOTICE 'Timestamp: %', now();
    RAISE NOTICE '================================================';
END $$;

-- Drop indexes first
DROP INDEX IF EXISTS idx_audit_ip_address;
DROP INDEX IF EXISTS idx_audit_session_id;

RAISE NOTICE 'Indexes dropped successfully';

-- Drop columns
ALTER TABLE record_audit DROP COLUMN IF EXISTS device_info;
ALTER TABLE record_audit DROP COLUMN IF EXISTS ip_address;
ALTER TABLE record_audit DROP COLUMN IF EXISTS session_id;

RAISE NOTICE 'Columns dropped successfully';

-- Verify rollback success
DO $$
BEGIN
    -- Check device_info removed
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'record_audit'
        AND column_name = 'device_info'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: device_info column still exists';
    END IF;

    -- Check ip_address removed
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'record_audit'
        AND column_name = 'ip_address'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: ip_address column still exists';
    END IF;

    -- Check session_id removed
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'record_audit'
        AND column_name = 'session_id'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: session_id column still exists';
    END IF;

    -- Check indexes removed
    IF EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_audit_session_id'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: idx_audit_session_id index still exists';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_audit_ip_address'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: idx_audit_ip_address index still exists';
    END IF;

    RAISE NOTICE 'All verification checks passed';
END $$;

COMMIT;

-- Post-rollback notes
DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Rollback 002: Remove Audit Metadata Fields - COMPLETED';
    RAISE NOTICE 'Timestamp: %', now();
    RAISE NOTICE '';
    RAISE NOTICE 'Changes reverted:';
    RAISE NOTICE '  - Removed column: device_info';
    RAISE NOTICE '  - Removed column: ip_address';
    RAISE NOTICE '  - Removed column: session_id';
    RAISE NOTICE '  - Removed index: idx_audit_session_id';
    RAISE NOTICE '  - Removed index: idx_audit_ip_address';
    RAISE NOTICE '';
    RAISE NOTICE 'Database is now in state after migration 001';
    RAISE NOTICE '================================================';
END $$;
