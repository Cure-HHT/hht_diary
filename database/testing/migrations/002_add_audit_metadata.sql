-- =====================================================
-- Migration: 002 - Add Audit Metadata Fields
-- Ticket: TICKET-001
-- Author: Database Team
-- Date: 2025-10-14
-- =====================================================

-- Purpose:
-- Add missing ALCOA+ compliance fields to record_event store for
-- FDA 21 CFR Part 11.10(e) compliance. These fields capture device
-- information, IP addresses, and session identifiers for complete
-- audit trail attribution.

-- Dependencies:
-- - Migration 001 (initial schema)

-- Compliance Reference:
-- - spec/compliance-practices.md:120-137
-- - FDA 21 CFR Part 11.10(e) - Audit Trail Requirements

BEGIN;

-- Log migration start
DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Starting migration 002: Add Audit Metadata Fields';
    RAISE NOTICE 'Ticket: TICKET-001';
    RAISE NOTICE 'Timestamp: %', now();
    RAISE NOTICE '================================================';
END $$;

-- Add device_info column
ALTER TABLE record_audit
ADD COLUMN IF NOT EXISTS device_info JSONB;

COMMENT ON COLUMN record_audit.device_info IS
'Device and platform information for audit trail attribution. Required for FDA 21 CFR Part 11 compliance. Contains: device type, OS, browser/app version, screen resolution.';

-- Add ip_address column
ALTER TABLE record_audit
ADD COLUMN IF NOT EXISTS ip_address INET;

COMMENT ON COLUMN record_audit.ip_address IS
'Source IP address for security tracking and audit trail. Required for FDA 21 CFR Part 11 compliance. Used to detect suspicious access patterns.';

-- Add session_id column
ALTER TABLE record_audit
ADD COLUMN IF NOT EXISTS session_id TEXT;

COMMENT ON COLUMN record_audit.session_id IS
'Session identifier for audit correlation. Required for FDA 21 CFR Part 11 compliance. Links related audit events within a user session.';

-- Add indexes for new fields
CREATE INDEX IF NOT EXISTS idx_audit_session_id
ON record_audit(session_id)
WHERE session_id IS NOT NULL;

COMMENT ON INDEX idx_audit_session_id IS
'Index for querying audit entries by session ID. Supports compliance reporting and forensic investigation.';

CREATE INDEX IF NOT EXISTS idx_audit_ip_address
ON record_audit(ip_address)
WHERE ip_address IS NOT NULL;

COMMENT ON INDEX idx_audit_ip_address IS
'Index for querying audit entries by IP address. Supports security monitoring and anomaly detection.';

-- Verify migration success
DO $$
BEGIN
    -- Check device_info column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'record_audit'
        AND column_name = 'device_info'
    ) THEN
        RAISE EXCEPTION 'Migration failed: device_info column not created';
    END IF;

    -- Check ip_address column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'record_audit'
        AND column_name = 'ip_address'
    ) THEN
        RAISE EXCEPTION 'Migration failed: ip_address column not created';
    END IF;

    -- Check session_id column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'record_audit'
        AND column_name = 'session_id'
    ) THEN
        RAISE EXCEPTION 'Migration failed: session_id column not created';
    END IF;

    -- Check indexes
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_audit_session_id'
    ) THEN
        RAISE EXCEPTION 'Migration failed: idx_audit_session_id index not created';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_audit_ip_address'
    ) THEN
        RAISE EXCEPTION 'Migration failed: idx_audit_ip_address index not created';
    END IF;

    RAISE NOTICE 'All verification checks passed';
END $$;

COMMIT;

-- Post-migration notes
DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Migration 002: Add Audit Metadata Fields - COMPLETED';
    RAISE NOTICE 'Timestamp: %', now();
    RAISE NOTICE '';
    RAISE NOTICE 'Changes applied:';
    RAISE NOTICE '  - Added column: device_info (JSONB)';
    RAISE NOTICE '  - Added column: ip_address (INET)';
    RAISE NOTICE '  - Added column: session_id (TEXT)';
    RAISE NOTICE '  - Added index: idx_audit_session_id';
    RAISE NOTICE '  - Added index: idx_audit_ip_address';
    RAISE NOTICE '';
    RAISE NOTICE 'Application layer must now populate these fields on every audit entry.';
    RAISE NOTICE 'See TICKET-001 for application implementation requirements.';
    RAISE NOTICE '';
    RAISE NOTICE 'Next migration: 003_add_tamper_detection.sql';
    RAISE NOTICE '================================================';
END $$;
