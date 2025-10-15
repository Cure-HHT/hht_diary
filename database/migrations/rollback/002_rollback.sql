-- =====================================================
-- Rollback: 002_add_tamper_detection
-- Description: Remove tamper detection functions and triggers
-- Ticket: TICKET-002
-- Date: 2025-10-14
-- =====================================================

-- WARNING: This removes tamper detection capabilities
-- Ensure this is necessary before proceeding

-- Drop the view
DROP VIEW IF EXISTS tamper_detection_dashboard;

-- Drop the trigger
DROP TRIGGER IF EXISTS compute_audit_hash_trigger ON record_audit;

-- Drop the functions
DROP FUNCTION IF EXISTS generate_integrity_report;
DROP FUNCTION IF EXISTS check_audit_sequence_gaps();
DROP FUNCTION IF EXISTS detect_tampered_records;
DROP FUNCTION IF EXISTS verify_audit_hashes_batch;
DROP FUNCTION IF EXISTS validate_audit_chain;
DROP FUNCTION IF EXISTS verify_audit_hash;
DROP FUNCTION IF EXISTS compute_audit_hash();

-- Verify rollback
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'compute_audit_hash_trigger'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: Trigger still exists';
    END IF;

    RAISE NOTICE 'Rollback 002_add_tamper_detection completed successfully';
END $$;
