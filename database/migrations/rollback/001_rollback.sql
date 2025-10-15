-- =====================================================
-- Rollback: 001_add_audit_metadata
-- Description: Remove audit metadata fields
-- Ticket: TICKET-001
-- Date: 2025-10-14
-- =====================================================

-- WARNING: This rollback will drop columns containing audit data
-- Ensure you have a backup before proceeding

-- Remove session_id column
ALTER TABLE record_audit DROP COLUMN IF EXISTS session_id;

-- Remove ip_address column
ALTER TABLE record_audit DROP COLUMN IF EXISTS ip_address;

-- Remove device_info column
ALTER TABLE record_audit DROP COLUMN IF EXISTS device_info;

-- Verify columns were removed
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'record_audit'
        AND column_name IN ('device_info', 'ip_address', 'session_id')
    ) THEN
        RAISE EXCEPTION 'Rollback failed: columns still exist';
    END IF;

    RAISE NOTICE 'Rollback 001_add_audit_metadata completed successfully';
END $$;
