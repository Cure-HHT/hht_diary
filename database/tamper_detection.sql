-- =====================================================
-- Cryptographic Tamper Detection
-- Implements FDA 21 CFR Part 11 tamper-evident audit trail
-- Ticket: TICKET-002
-- =====================================================
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00004: Immutable Audit Trail via Event Sourcing
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--   REQ-p00011: ALCOA+ Data Integrity Principles
--
-- TAMPER DETECTION:
--   SHA-256 cryptographic hashing provides tamper-evident audit trail
--   per FDA 21 CFR Part 11 § 11.10(e). Any modification to audit records
--   results in hash mismatch, detecting tampering attempts.
--
-- =====================================================

-- =====================================================
-- FUNCTION: Compute Audit Hash
-- =====================================================

CREATE OR REPLACE FUNCTION compute_audit_hash()
RETURNS TRIGGER AS $$
BEGIN
    -- Compute SHA-256 hash of critical audit fields
    -- This creates a tamper-evident signature for each audit entry
    NEW.signature_hash := encode(
        digest(
            NEW.audit_id::text ||
            NEW.event_uuid::text ||
            NEW.operation ||
            NEW.patient_id ||
            NEW.site_id ||
            NEW.data::text ||
            NEW.created_by ||
            NEW.role ||
            NEW.client_timestamp::text ||
            NEW.server_timestamp::text ||
            COALESCE(NEW.parent_audit_id::text, '') ||
            NEW.change_reason ||
            COALESCE(NEW.device_info::text, '') ||
            COALESCE(NEW.ip_address::text, '') ||
            COALESCE(NEW.session_id, ''),
            'sha256'
        ),
        'hex'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION compute_audit_hash() IS 'Event Sourcing: Automatically compute SHA-256 hash for event store tamper detection (audit trail integrity)';

-- Apply trigger to event store (record_audit)
CREATE TRIGGER compute_audit_hash_trigger
    BEFORE INSERT ON record_audit
    FOR EACH ROW
    EXECUTE FUNCTION compute_audit_hash();

COMMENT ON TRIGGER compute_audit_hash_trigger ON record_audit IS 'Event Sourcing: Ensures every event in event store has cryptographic signature';

-- =====================================================
-- FUNCTION: Verify Audit Hash
-- =====================================================

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
            v_record.site_id ||
            v_record.data::text ||
            v_record.created_by ||
            v_record.role ||
            v_record.client_timestamp::text ||
            v_record.server_timestamp::text ||
            COALESCE(v_record.parent_audit_id::text, '') ||
            v_record.change_reason ||
            COALESCE(v_record.device_info::text, '') ||
            COALESCE(v_record.ip_address::text, '') ||
            COALESCE(v_record.session_id, ''),
            'sha256'
        ),
        'hex'
    );

    -- Compare computed hash with stored hash
    RETURN v_computed_hash = v_record.signature_hash;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION verify_audit_hash(BIGINT) IS 'Event Sourcing: Verify cryptographic integrity of an event in event store';

-- =====================================================
-- FUNCTION: Validate Audit Chain
-- =====================================================

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
            ra.signature_hash,
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
            WHEN ac.parent_audit_id IS NOT NULL AND NOT EXISTS(
                SELECT 1 FROM record_audit ra2 WHERE ra2.audit_id = ac.parent_audit_id
            ) THEN 'Invalid parent reference - audit chain broken'
            ELSE NULL
        END as error_message
    FROM audit_chain ac;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION validate_audit_chain(UUID) IS 'Event Sourcing: Validate cryptographic integrity of entire event history in event store';

-- =====================================================
-- FUNCTION: Batch Verify Audit Hashes
-- =====================================================

CREATE OR REPLACE FUNCTION verify_audit_hashes_batch(
    p_start_date TIMESTAMPTZ DEFAULT now() - interval '7 days',
    p_end_date TIMESTAMPTZ DEFAULT now(),
    p_limit INTEGER DEFAULT 1000
)
RETURNS TABLE(
    audit_id BIGINT,
    event_uuid UUID,
    patient_id TEXT,
    server_timestamp TIMESTAMPTZ,
    is_valid BOOLEAN,
    error_message TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ra.audit_id,
        ra.event_uuid,
        ra.patient_id,
        ra.server_timestamp,
        verify_audit_hash(ra.audit_id) as is_valid,
        CASE
            WHEN NOT verify_audit_hash(ra.audit_id) THEN 'Hash verification failed'
            ELSE NULL
        END as error_message
    FROM record_audit ra
    WHERE ra.server_timestamp BETWEEN p_start_date AND p_end_date
    ORDER BY ra.audit_id
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION verify_audit_hashes_batch IS 'Event Sourcing: Batch verify event store integrity for compliance reporting (audit trail verification)';

-- =====================================================
-- FUNCTION: Detect Tampered Records
-- =====================================================

CREATE OR REPLACE FUNCTION detect_tampered_records(
    p_start_date TIMESTAMPTZ DEFAULT now() - interval '30 days',
    p_end_date TIMESTAMPTZ DEFAULT now()
)
RETURNS TABLE(
    audit_id BIGINT,
    event_uuid UUID,
    patient_id TEXT,
    site_id TEXT,
    operation TEXT,
    server_timestamp TIMESTAMPTZ,
    created_by TEXT,
    stored_hash TEXT,
    severity TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ra.audit_id,
        ra.event_uuid,
        ra.patient_id,
        ra.site_id,
        ra.operation,
        ra.server_timestamp,
        ra.created_by,
        ra.signature_hash,
        'CRITICAL'::TEXT as severity
    FROM record_audit ra
    WHERE ra.server_timestamp BETWEEN p_start_date AND p_end_date
    AND NOT verify_audit_hash(ra.audit_id)
    ORDER BY ra.server_timestamp DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION detect_tampered_records IS 'Event Sourcing: Detect events in event store that have been tampered with';

-- =====================================================
-- FUNCTION: Check Audit Sequence Integrity
-- =====================================================

CREATE OR REPLACE FUNCTION check_audit_sequence_gaps()
RETURNS TABLE(
    gap_start BIGINT,
    gap_end BIGINT,
    missing_count BIGINT,
    detected_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    WITH audit_gaps AS (
        SELECT
            audit_id,
            lead(audit_id) OVER (ORDER BY audit_id) as next_id
        FROM record_audit
    )
    SELECT
        ag.audit_id as gap_start,
        ag.next_id as gap_end,
        (ag.next_id - ag.audit_id - 1) as missing_count,
        now() as detected_at
    FROM audit_gaps ag
    WHERE ag.next_id - ag.audit_id > 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION check_audit_sequence_gaps IS 'Event Sourcing: Detect gaps in event store sequence (potential tampering or deletion)';

-- =====================================================
-- FUNCTION: Generate Integrity Report
-- =====================================================

CREATE OR REPLACE FUNCTION generate_integrity_report(
    p_start_date TIMESTAMPTZ DEFAULT now() - interval '30 days',
    p_end_date TIMESTAMPTZ DEFAULT now()
)
RETURNS TABLE(
    check_name TEXT,
    status TEXT,
    count BIGINT,
    details TEXT
) AS $$
DECLARE
    v_total_records BIGINT;
    v_failed_hashes BIGINT;
    v_sequence_gaps BIGINT;
    v_missing_hashes BIGINT;
BEGIN
    -- Count total records in period
    SELECT COUNT(*) INTO v_total_records
    FROM record_audit
    WHERE server_timestamp BETWEEN p_start_date AND p_end_date;

    RETURN QUERY SELECT
        'Total Audit Records'::TEXT,
        'INFO'::TEXT,
        v_total_records,
        format('Checked records from %s to %s', p_start_date, p_end_date);

    -- Check for missing hashes
    SELECT COUNT(*) INTO v_missing_hashes
    FROM record_audit
    WHERE server_timestamp BETWEEN p_start_date AND p_end_date
    AND (signature_hash IS NULL OR signature_hash = '');

    RETURN QUERY SELECT
        'Missing Signature Hashes'::TEXT,
        CASE WHEN v_missing_hashes > 0 THEN 'FAIL' ELSE 'PASS' END,
        v_missing_hashes,
        CASE WHEN v_missing_hashes > 0
            THEN 'Records without cryptographic signatures detected'
            ELSE 'All records have signature hashes'
        END;

    -- Check for hash verification failures
    SELECT COUNT(*) INTO v_failed_hashes
    FROM record_audit ra
    WHERE ra.server_timestamp BETWEEN p_start_date AND p_end_date
    AND ra.signature_hash IS NOT NULL
    AND NOT verify_audit_hash(ra.audit_id);

    RETURN QUERY SELECT
        'Hash Verification Failures'::TEXT,
        CASE WHEN v_failed_hashes > 0 THEN 'CRITICAL' ELSE 'PASS' END,
        v_failed_hashes,
        CASE WHEN v_failed_hashes > 0
            THEN 'TAMPERING DETECTED - Investigate immediately'
            ELSE 'All hash verifications passed'
        END;

    -- Check for sequence gaps
    SELECT COUNT(*) INTO v_sequence_gaps
    FROM check_audit_sequence_gaps();

    RETURN QUERY SELECT
        'Audit Sequence Gaps'::TEXT,
        CASE WHEN v_sequence_gaps > 0 THEN 'WARN' ELSE 'PASS' END,
        v_sequence_gaps,
        CASE WHEN v_sequence_gaps > 0
            THEN 'Gaps detected in audit sequence - may indicate deleted records'
            ELSE 'Audit sequence is continuous'
        END;

    -- Return summary
    RETURN QUERY SELECT
        'Overall Status'::TEXT,
        CASE
            WHEN v_failed_hashes > 0 THEN 'CRITICAL - TAMPERING DETECTED'
            WHEN v_missing_hashes > 0 THEN 'FAIL - INCOMPLETE SIGNATURES'
            WHEN v_sequence_gaps > 0 THEN 'WARN - SEQUENCE GAPS'
            ELSE 'PASS - AUDIT TRAIL INTACT'
        END,
        NULL::BIGINT,
        'Compliance check completed';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION generate_integrity_report IS 'Event Sourcing: Generate comprehensive event store integrity report for compliance (audit trail verification)';

-- =====================================================
-- VIEW: Tamper Detection Dashboard
-- =====================================================

CREATE OR REPLACE VIEW tamper_detection_dashboard AS
SELECT
    DATE(ra.server_timestamp) as audit_date,
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE ra.signature_hash IS NULL) as missing_hashes,
    COUNT(*) FILTER (WHERE ra.signature_hash IS NOT NULL AND NOT verify_audit_hash(ra.audit_id)) as failed_verifications,
    MAX(ra.server_timestamp) as last_audit_time
FROM record_audit ra
WHERE ra.server_timestamp > now() - interval '30 days'
GROUP BY DATE(ra.server_timestamp)
ORDER BY audit_date DESC;

COMMENT ON VIEW tamper_detection_dashboard IS 'Daily tamper detection metrics for monitoring';

-- =====================================================
-- GRANTS
-- =====================================================

-- Admins can run all verification functions
GRANT EXECUTE ON FUNCTION verify_audit_hash(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION validate_audit_chain(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_audit_hashes_batch TO authenticated;
GRANT EXECUTE ON FUNCTION detect_tampered_records TO authenticated;
GRANT EXECUTE ON FUNCTION check_audit_sequence_gaps() TO authenticated;
GRANT EXECUTE ON FUNCTION generate_integrity_report TO authenticated;

-- Grant view access
GRANT SELECT ON tamper_detection_dashboard TO authenticated;

-- =====================================================
-- EDC SYNC LOG CHAINED HASHING
-- =====================================================
-- Implements blockchain-style chained hashing for non-repudiation
-- Each sync log entry's chain_hash depends on the previous entry,
-- creating a tamper-evident audit trail where any modification
-- breaks the chain.

-- FUNCTION: Compute Chained Hash for EDC Sync Log
CREATE OR REPLACE FUNCTION compute_edc_sync_chain_hash()
RETURNS TRIGGER AS $$
DECLARE
    v_previous_chain_hash TEXT;
BEGIN
    -- Get the chain_hash from the most recent previous record
    SELECT chain_hash INTO v_previous_chain_hash
    FROM edc_sync_log
    ORDER BY sync_id DESC
    LIMIT 1;

    -- For the first record, use a genesis hash
    IF v_previous_chain_hash IS NULL THEN
        v_previous_chain_hash := 'GENESIS_EDC_SYNC_LOG_2024';
    END IF;

    -- Compute chained hash: SHA256(previous_hash || content_hash || timestamp || sync_id)
    -- This creates a blockchain-style chain where each record depends on all previous records
    NEW.chain_hash := encode(
        digest(
            v_previous_chain_hash ||
            NEW.content_hash ||
            NEW.sync_timestamp::text ||
            NEW.source_system ||
            NEW.operation ||
            NEW.sites_created::text ||
            NEW.sites_updated::text ||
            NEW.sites_deactivated::text ||
            COALESCE(NEW.error_message, '') ||
            NEW.success::text,
            'sha256'
        ),
        'hex'
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION compute_edc_sync_chain_hash() IS 'Computes blockchain-style chained hash for EDC sync log entries, ensuring tamper-evident non-repudiation';

-- Apply trigger to edc_sync_log
CREATE TRIGGER compute_edc_sync_chain_hash_trigger
    BEFORE INSERT ON edc_sync_log
    FOR EACH ROW
    EXECUTE FUNCTION compute_edc_sync_chain_hash();

COMMENT ON TRIGGER compute_edc_sync_chain_hash_trigger ON edc_sync_log IS 'Ensures every sync log entry has a chained cryptographic hash for non-repudiation';

-- =====================================================
-- FUNCTION: Verify EDC Sync Log Chain Integrity
-- =====================================================
-- Validates that the entire sync log chain is intact

CREATE OR REPLACE FUNCTION verify_edc_sync_chain()
RETURNS TABLE (
    sync_id BIGINT,
    sync_timestamp TIMESTAMPTZ,
    is_valid BOOLEAN,
    expected_hash TEXT,
    actual_hash TEXT,
    error_detail TEXT
) AS $$
DECLARE
    v_record RECORD;
    v_previous_chain_hash TEXT := 'GENESIS_EDC_SYNC_LOG_2024';
    v_computed_hash TEXT;
BEGIN
    FOR v_record IN
        SELECT * FROM edc_sync_log ORDER BY sync_id ASC
    LOOP
        -- Recompute the chain hash
        v_computed_hash := encode(
            digest(
                v_previous_chain_hash ||
                v_record.content_hash ||
                v_record.sync_timestamp::text ||
                v_record.source_system ||
                v_record.operation ||
                v_record.sites_created::text ||
                v_record.sites_updated::text ||
                v_record.sites_deactivated::text ||
                COALESCE(v_record.error_message, '') ||
                v_record.success::text,
                'sha256'
            ),
            'hex'
        );

        -- Check if it matches the stored hash
        IF v_computed_hash = v_record.chain_hash THEN
            sync_id := v_record.sync_id;
            sync_timestamp := v_record.sync_timestamp;
            is_valid := TRUE;
            expected_hash := v_computed_hash;
            actual_hash := v_record.chain_hash;
            error_detail := NULL;
        ELSE
            sync_id := v_record.sync_id;
            sync_timestamp := v_record.sync_timestamp;
            is_valid := FALSE;
            expected_hash := v_computed_hash;
            actual_hash := v_record.chain_hash;
            error_detail := 'Chain hash mismatch - possible tampering detected';
        END IF;

        RETURN NEXT;

        -- Update previous hash for next iteration
        v_previous_chain_hash := v_record.chain_hash;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION verify_edc_sync_chain() IS 'Verifies integrity of entire EDC sync log chain - detects any tampering or modifications';

-- =====================================================
-- FUNCTION: Check EDC Sync Log Chain Status
-- =====================================================
-- Quick check if chain is intact, returns summary

CREATE OR REPLACE FUNCTION check_edc_sync_chain_status()
RETURNS TABLE (
    total_records BIGINT,
    valid_records BIGINT,
    invalid_records BIGINT,
    chain_intact BOOLEAN,
    first_invalid_sync_id BIGINT,
    checked_at TIMESTAMPTZ
) AS $$
DECLARE
    v_total BIGINT;
    v_valid BIGINT;
    v_invalid BIGINT;
    v_first_invalid BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_total FROM edc_sync_log;

    SELECT
        COUNT(*) FILTER (WHERE is_valid),
        COUNT(*) FILTER (WHERE NOT is_valid),
        MIN(v.sync_id) FILTER (WHERE NOT is_valid)
    INTO v_valid, v_invalid, v_first_invalid
    FROM verify_edc_sync_chain() v;

    total_records := v_total;
    valid_records := v_valid;
    invalid_records := v_invalid;
    chain_intact := (v_invalid = 0);
    first_invalid_sync_id := v_first_invalid;
    checked_at := now();

    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION check_edc_sync_chain_status() IS 'Quick summary check of EDC sync log chain integrity';

-- =====================================================
-- EXAMPLE USAGE
-- =====================================================

/*
-- Verify a specific audit entry
SELECT verify_audit_hash(12345);

-- Validate entire chain for an event
SELECT * FROM validate_audit_chain('550e8400-e29b-41d4-a716-446655440000');

-- Check for tampered records in last 7 days
SELECT * FROM detect_tampered_records(now() - interval '7 days', now());

-- Generate integrity report for last month
SELECT * FROM generate_integrity_report(now() - interval '30 days', now());

-- Check for sequence gaps
SELECT * FROM check_audit_sequence_gaps();

-- View tamper detection dashboard
SELECT * FROM tamper_detection_dashboard;

-- Batch verify recent records
SELECT * FROM verify_audit_hashes_batch(now() - interval '1 day', now(), 100);
*/
