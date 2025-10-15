-- =====================================================
-- Migration: 002_add_tamper_detection
-- Description: Implement cryptographic tamper detection for FDA 21 CFR Part 11
-- Ticket: TICKET-002
-- Date: 2025-10-14
-- =====================================================

-- Load the tamper detection functions
\i database/tamper_detection.sql

-- Backfill existing records with hashes (if any exist)
DO $$
DECLARE
    v_count INTEGER;
    v_record RECORD;
BEGIN
    -- Count records without hashes
    SELECT COUNT(*) INTO v_count
    FROM record_audit
    WHERE signature_hash IS NULL OR signature_hash = '';

    IF v_count > 0 THEN
        RAISE NOTICE 'Backfilling hashes for % existing records...', v_count;

        -- Update existing records with computed hashes
        FOR v_record IN
            SELECT audit_id FROM record_audit
            WHERE signature_hash IS NULL OR signature_hash = ''
            ORDER BY audit_id
        LOOP
            UPDATE record_audit
            SET signature_hash = encode(
                digest(
                    audit_id::text ||
                    event_uuid::text ||
                    operation ||
                    patient_id ||
                    site_id ||
                    data::text ||
                    created_by ||
                    role ||
                    client_timestamp::text ||
                    server_timestamp::text ||
                    COALESCE(parent_audit_id::text, '') ||
                    change_reason ||
                    COALESCE(device_info::text, '') ||
                    COALESCE(ip_address::text, '') ||
                    COALESCE(session_id, ''),
                    'sha256'
                ),
                'hex'
            )
            WHERE audit_id = v_record.audit_id;
        END LOOP;

        RAISE NOTICE 'Backfill completed for % records', v_count;
    ELSE
        RAISE NOTICE 'No records require backfilling';
    END IF;
END $$;

-- Verify migration success
DO $$
DECLARE
    v_trigger_exists BOOLEAN;
    v_function_exists BOOLEAN;
BEGIN
    -- Check trigger exists
    SELECT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'compute_audit_hash_trigger'
    ) INTO v_trigger_exists;

    IF NOT v_trigger_exists THEN
        RAISE EXCEPTION 'Migration failed: compute_audit_hash_trigger not created';
    END IF;

    -- Check function exists
    SELECT EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'verify_audit_hash'
    ) INTO v_function_exists;

    IF NOT v_function_exists THEN
        RAISE EXCEPTION 'Migration failed: verify_audit_hash function not created';
    END IF;

    RAISE NOTICE 'Migration 002_add_tamper_detection completed successfully';
END $$;
