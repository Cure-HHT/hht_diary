-- =====================================================
-- Migration: 001_add_audit_metadata
-- Description: Add missing ALCOA+ compliance fields to record_audit table
-- Ticket: TICKET-001
-- Date: 2025-10-14
-- =====================================================

-- Add device_info column for device and platform tracking
ALTER TABLE record_audit ADD COLUMN IF NOT EXISTS device_info JSONB;
COMMENT ON COLUMN record_audit.device_info IS 'Device and platform information for ALCOA+ compliance (device_type, os, browser, app_version)';

-- Add ip_address column for source IP tracking
ALTER TABLE record_audit ADD COLUMN IF NOT EXISTS ip_address INET;
COMMENT ON COLUMN record_audit.ip_address IS 'Source IP address for compliance tracking and security monitoring';

-- Add session_id column for session tracking
ALTER TABLE record_audit ADD COLUMN IF NOT EXISTS session_id TEXT;
COMMENT ON COLUMN record_audit.session_id IS 'Session identifier for audit correlation and security tracking';

-- Verify columns were added
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'record_audit'
        AND column_name = 'device_info'
    ) THEN
        RAISE EXCEPTION 'Migration failed: device_info column not added';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'record_audit'
        AND column_name = 'ip_address'
    ) THEN
        RAISE EXCEPTION 'Migration failed: ip_address column not added';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'record_audit'
        AND column_name = 'session_id'
    ) THEN
        RAISE EXCEPTION 'Migration failed: session_id column not added';
    END IF;

    RAISE NOTICE 'Migration 001_add_audit_metadata completed successfully';
END $$;
