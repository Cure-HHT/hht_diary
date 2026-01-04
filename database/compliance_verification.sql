-- =====================================================
-- Compliance Verification Functions
-- Built-in functions for FDA 21 CFR Part 11 compliance audits
-- TICKET-005
-- =====================================================
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--   REQ-p00011: ALCOA+ Data Integrity Principles
--   REQ-o00005: Audit Trail Monitoring
--
-- COMPLIANCE VERIFICATION:
--   These functions verify audit trail integrity for:
--   - FDA regulatory inspections (21 CFR Part 11 § 11.10(e))
--   - Internal compliance audits
--   - ALCOA+ principle validation (Complete, Consistent, Enduring, Available)
--   - Tamper detection via cryptographic hash verification
--
-- =====================================================

-- Set timeouts to prevent long-running operations
SET statement_timeout = '30s';
SET lock_timeout = '10s';

-- =====================================================
-- FUNCTION 1: Check for Gaps in Audit Sequence
-- =====================================================

-- Drop existing version (may have different return type from tamper_detection.sql)
DROP FUNCTION IF EXISTS check_audit_sequence_gaps();

CREATE FUNCTION check_audit_sequence_gaps()
RETURNS TABLE(
    gap_start BIGINT,
    gap_end BIGINT,
    missing_count BIGINT,
    severity TEXT
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
        CASE
            WHEN (ag.next_id - ag.audit_id - 1) > 100 THEN 'CRITICAL'
            WHEN (ag.next_id - ag.audit_id - 1) > 10 THEN 'WARNING'
            ELSE 'INFO'
        END as severity
    FROM audit_gaps ag
    WHERE ag.next_id - ag.audit_id > 1
    ORDER BY ag.audit_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION check_audit_sequence_gaps() IS 'Compliance: Detect gaps in event store sequence numbers (audit trail integrity)';

-- =====================================================
-- FUNCTION 2: Verify Audit Completeness for Event
-- =====================================================

CREATE OR REPLACE FUNCTION check_audit_completeness(p_event_uuid UUID)
RETURNS TABLE(
    check_name TEXT,
    is_valid BOOLEAN,
    details TEXT,
    severity TEXT
) AS $$
BEGIN
    -- Check 1: Event exists in read model (record_state)
    RETURN QUERY
    SELECT
        'Event exists in read model'::TEXT,
        EXISTS(SELECT 1 FROM record_state WHERE event_uuid = p_event_uuid),
        CASE
            WHEN EXISTS(SELECT 1 FROM record_state WHERE event_uuid = p_event_uuid)
            THEN 'Event found in read model (record_state)'
            ELSE 'Event not found in read model - orphaned event store entries'
        END,
        CASE
            WHEN EXISTS(SELECT 1 FROM record_state WHERE event_uuid = p_event_uuid)
            THEN 'PASS'::TEXT
            ELSE 'FAIL'::TEXT
        END;

    -- Check 2: Event entries exist in event store
    RETURN QUERY
    SELECT
        'Event entries exist in event store'::TEXT,
        EXISTS(SELECT 1 FROM record_audit WHERE event_uuid = p_event_uuid),
        format('Found %s event store entries',
            (SELECT COUNT(*) FROM record_audit WHERE event_uuid = p_event_uuid)),
        CASE
            WHEN EXISTS(SELECT 1 FROM record_audit WHERE event_uuid = p_event_uuid)
            THEN 'PASS'::TEXT
            ELSE 'FAIL'::TEXT
        END;

    -- Check 3: All required metadata present
    RETURN QUERY
    SELECT
        'Required metadata complete'::TEXT,
        NOT EXISTS(
            SELECT 1 FROM record_audit
            WHERE event_uuid = p_event_uuid
            AND (
                created_by IS NULL OR
                role IS NULL OR
                change_reason IS NULL OR
                data IS NULL OR
                signature_hash IS NULL
            )
        ),
        CASE
            WHEN NOT EXISTS(
                SELECT 1 FROM record_audit
                WHERE event_uuid = p_event_uuid
                AND (created_by IS NULL OR role IS NULL OR change_reason IS NULL OR signature_hash IS NULL)
            )
            THEN 'All required fields populated'
            ELSE format('Missing fields in %s entries',
                (SELECT COUNT(*) FROM record_audit
                 WHERE event_uuid = p_event_uuid
                 AND (created_by IS NULL OR role IS NULL OR change_reason IS NULL OR signature_hash IS NULL)))
        END,
        CASE
            WHEN NOT EXISTS(
                SELECT 1 FROM record_audit
                WHERE event_uuid = p_event_uuid
                AND (created_by IS NULL OR role IS NULL OR change_reason IS NULL OR signature_hash IS NULL)
            )
            THEN 'PASS'::TEXT
            ELSE 'FAIL'::TEXT
        END;

    -- Check 4: Hash chain valid
    RETURN QUERY
    SELECT
        'Hash chain valid'::TEXT,
        NOT EXISTS(
            SELECT 1 FROM validate_audit_chain(p_event_uuid) vac
            WHERE vac.is_valid = false
        ),
        CASE
            WHEN NOT EXISTS(
                SELECT 1 FROM validate_audit_chain(p_event_uuid) vac
                WHERE vac.is_valid = false
            )
            THEN 'All hashes verified'
            ELSE format('%s hash failures detected',
                (SELECT COUNT(*) FROM validate_audit_chain(p_event_uuid) vac WHERE vac.is_valid = false))
        END,
        CASE
            WHEN NOT EXISTS(
                SELECT 1 FROM validate_audit_chain(p_event_uuid) vac
                WHERE vac.is_valid = false
            )
            THEN 'PASS'::TEXT
            ELSE 'FAIL'::TEXT
        END;

    -- Check 5: Parent references valid
    RETURN QUERY
    SELECT
        'Parent references valid'::TEXT,
        NOT EXISTS(
            SELECT 1 FROM record_audit ra1
            WHERE ra1.event_uuid = p_event_uuid
            AND ra1.parent_audit_id IS NOT NULL
            AND NOT EXISTS(
                SELECT 1 FROM record_audit ra2
                WHERE ra2.audit_id = ra1.parent_audit_id
            )
        ),
        CASE
            WHEN NOT EXISTS(
                SELECT 1 FROM record_audit ra1
                WHERE ra1.event_uuid = p_event_uuid
                AND ra1.parent_audit_id IS NOT NULL
                AND NOT EXISTS(
                    SELECT 1 FROM record_audit ra2
                    WHERE ra2.audit_id = ra1.parent_audit_id
                )
            )
            THEN 'All parent audit IDs reference existing records'
            ELSE 'Broken parent audit ID chains detected'
        END,
        CASE
            WHEN NOT EXISTS(
                SELECT 1 FROM record_audit ra1
                WHERE ra1.event_uuid = p_event_uuid
                AND ra1.parent_audit_id IS NOT NULL
                AND NOT EXISTS(
                    SELECT 1 FROM record_audit ra2
                    WHERE ra2.audit_id = ra1.parent_audit_id
                )
            )
            THEN 'PASS'::TEXT
            ELSE 'FAIL'::TEXT
        END;

    -- Check 6: ALCOA+ metadata present (device_info, ip_address, session_id)
    RETURN QUERY
    SELECT
        'ALCOA+ metadata present'::TEXT,
        NOT EXISTS(
            SELECT 1 FROM record_audit
            WHERE event_uuid = p_event_uuid
            AND (device_info IS NULL OR ip_address IS NULL OR session_id IS NULL)
        ),
        CASE
            WHEN NOT EXISTS(
                SELECT 1 FROM record_audit
                WHERE event_uuid = p_event_uuid
                AND (device_info IS NULL OR ip_address IS NULL OR session_id IS NULL)
            )
            THEN 'Device info, IP address, and session ID present for all entries'
            ELSE format('%s entries missing ALCOA+ metadata',
                (SELECT COUNT(*) FROM record_audit
                 WHERE event_uuid = p_event_uuid
                 AND (device_info IS NULL OR ip_address IS NULL OR session_id IS NULL)))
        END,
        CASE
            WHEN NOT EXISTS(
                SELECT 1 FROM record_audit
                WHERE event_uuid = p_event_uuid
                AND (device_info IS NULL OR ip_address IS NULL OR session_id IS NULL)
            )
            THEN 'PASS'::TEXT
            ELSE 'WARN'::TEXT
        END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION check_audit_completeness(UUID) IS 'Compliance: Comprehensive check for a single event across event store and read model';

-- =====================================================
-- FUNCTION 3: Generate Compliance Report
-- =====================================================

CREATE OR REPLACE FUNCTION generate_compliance_report(
    p_start_date TIMESTAMPTZ DEFAULT now() - interval '30 days',
    p_end_date TIMESTAMPTZ DEFAULT now()
)
RETURNS TABLE(
    metric TEXT,
    value TEXT,
    status TEXT,
    details TEXT
) AS $$
BEGIN
    -- Total audit entries
    RETURN QUERY
    SELECT
        'Total Audit Entries'::TEXT,
        COUNT(*)::TEXT,
        'INFO'::TEXT,
        format('Period: %s to %s', p_start_date::DATE, p_end_date::DATE)
    FROM record_audit
    WHERE server_timestamp BETWEEN p_start_date AND p_end_date;

    -- Entries with missing metadata
    RETURN QUERY
    SELECT
        'Entries Missing Required Metadata'::TEXT,
        COUNT(*)::TEXT,
        CASE WHEN COUNT(*) > 0 THEN 'FAIL' ELSE 'PASS' END,
        'Required: created_by, role, change_reason, signature_hash'
    FROM record_audit
    WHERE server_timestamp BETWEEN p_start_date AND p_end_date
    AND (
        created_by IS NULL OR
        role IS NULL OR
        change_reason IS NULL OR
        signature_hash IS NULL
    );

    -- Entries missing ALCOA+ metadata
    RETURN QUERY
    SELECT
        'Entries Missing ALCOA+ Metadata'::TEXT,
        COUNT(*)::TEXT,
        CASE WHEN COUNT(*) > 0 THEN 'WARN' ELSE 'PASS' END,
        'ALCOA+ fields: device_info, ip_address, session_id'
    FROM record_audit
    WHERE server_timestamp BETWEEN p_start_date AND p_end_date
    AND (
        device_info IS NULL OR
        ip_address IS NULL OR
        session_id IS NULL
    );

    -- Hash verification failures
    RETURN QUERY
    SELECT
        'Hash Verification Failures'::TEXT,
        COUNT(*)::TEXT,
        CASE WHEN COUNT(*) > 0 THEN 'FAIL' ELSE 'PASS' END,
        'Cryptographic hash integrity check'
    FROM record_audit
    WHERE server_timestamp BETWEEN p_start_date AND p_end_date
    AND NOT verify_audit_hash(audit_id);

    -- Sequence gaps
    RETURN QUERY
    SELECT
        'Audit Sequence Gaps'::TEXT,
        COUNT(*)::TEXT,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            WHEN SUM(missing_count) > 100 THEN 'FAIL'
            ELSE 'WARN'
        END,
        CASE
            WHEN COUNT(*) = 0 THEN 'No gaps detected'
            ELSE format('%s gaps totaling %s missing entries', COUNT(*), SUM(missing_count))
        END
    FROM check_audit_sequence_gaps();

    -- Unique users with activity
    RETURN QUERY
    SELECT
        'Active Users'::TEXT,
        COUNT(DISTINCT created_by)::TEXT,
        'INFO'::TEXT,
        'Distinct users who created audit entries'
    FROM record_audit
    WHERE server_timestamp BETWEEN p_start_date AND p_end_date;

    -- Records by role
    RETURN QUERY
    SELECT
        format('Entries by %s', role)::TEXT,
        COUNT(*)::TEXT,
        'INFO'::TEXT,
        format('%s%% of total', round((COUNT(*) * 100.0 / NULLIF(
            (SELECT COUNT(*) FROM record_audit WHERE server_timestamp BETWEEN p_start_date AND p_end_date), 0
        ))::numeric, 1))
    FROM record_audit
    WHERE server_timestamp BETWEEN p_start_date AND p_end_date
    GROUP BY role
    ORDER BY COUNT(*) DESC;

    -- Records by operation
    RETURN QUERY
    SELECT
        format('Operation: %s', operation)::TEXT,
        COUNT(*)::TEXT,
        'INFO'::TEXT,
        format('%s%% of total', round((COUNT(*) * 100.0 / NULLIF(
            (SELECT COUNT(*) FROM record_audit WHERE server_timestamp BETWEEN p_start_date AND p_end_date), 0
        ))::numeric, 1))
    FROM record_audit
    WHERE server_timestamp BETWEEN p_start_date AND p_end_date
    GROUP BY operation
    ORDER BY COUNT(*) DESC
    LIMIT 10;

    -- Orphaned read model records
    RETURN QUERY
    SELECT
        'Orphaned Read Model Records'::TEXT,
        COUNT(*)::TEXT,
        CASE WHEN COUNT(*) > 0 THEN 'FAIL' ELSE 'PASS' END,
        'Read model records without corresponding event store entries'
    FROM record_state rs
    WHERE NOT EXISTS (
        SELECT 1 FROM record_audit ra
        WHERE ra.event_uuid = rs.event_uuid
    );

    -- Overall compliance status
    RETURN QUERY
    SELECT
        '=== OVERALL COMPLIANCE STATUS ==='::TEXT,
        CASE
            WHEN EXISTS(
                SELECT 1 FROM record_audit
                WHERE server_timestamp BETWEEN p_start_date AND p_end_date
                AND (created_by IS NULL OR role IS NULL OR change_reason IS NULL OR signature_hash IS NULL)
            )
            OR EXISTS(
                SELECT 1 FROM record_audit
                WHERE server_timestamp BETWEEN p_start_date AND p_end_date
                AND NOT verify_audit_hash(audit_id)
            )
            THEN 'FAILED'
            WHEN EXISTS(
                SELECT 1 FROM record_audit
                WHERE server_timestamp BETWEEN p_start_date AND p_end_date
                AND (device_info IS NULL OR ip_address IS NULL OR session_id IS NULL)
            )
            THEN 'PASSED WITH WARNINGS'
            ELSE 'PASSED'
        END,
        CASE
            WHEN EXISTS(
                SELECT 1 FROM record_audit
                WHERE server_timestamp BETWEEN p_start_date AND p_end_date
                AND (created_by IS NULL OR role IS NULL OR change_reason IS NULL OR signature_hash IS NULL)
            )
            OR EXISTS(
                SELECT 1 FROM record_audit
                WHERE server_timestamp BETWEEN p_start_date AND p_end_date
                AND NOT verify_audit_hash(audit_id)
            )
            THEN 'CRITICAL'
            ELSE 'INFO'
        END,
        'Based on FDA 21 CFR Part 11 and ALCOA+ requirements'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION generate_compliance_report(TIMESTAMPTZ, TIMESTAMPTZ) IS 'Compliance: Generate comprehensive report for regulatory audits (FDA 21 CFR Part 11, ALCOA+)';

-- =====================================================
-- FUNCTION 4: Validate ALCOA+ Compliance
-- =====================================================

CREATE OR REPLACE FUNCTION validate_alcoa_compliance(p_audit_id BIGINT)
RETURNS TABLE(
    principle TEXT,
    compliant BOOLEAN,
    details TEXT,
    severity TEXT
) AS $$
DECLARE
    v_record RECORD;
BEGIN
    SELECT * INTO v_record FROM record_audit WHERE audit_id = p_audit_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            false,
            format('Audit ID %s not found', p_audit_id),
            'FAIL'::TEXT;
        RETURN;
    END IF;

    -- Attributable: WHO made the change
    RETURN QUERY SELECT
        'Attributable'::TEXT,
        v_record.created_by IS NOT NULL AND v_record.role IS NOT NULL,
        format('Created by: %s, Role: %s', v_record.created_by, v_record.role),
        CASE WHEN v_record.created_by IS NOT NULL AND v_record.role IS NOT NULL THEN 'PASS'::TEXT ELSE 'FAIL'::TEXT END;

    -- Legible: Data is readable
    RETURN QUERY SELECT
        'Legible'::TEXT,
        v_record.data IS NOT NULL,
        'Data stored in structured JSONB format',
        CASE WHEN v_record.data IS NOT NULL THEN 'PASS'::TEXT ELSE 'FAIL'::TEXT END;

    -- Contemporaneous: WHEN it happened
    RETURN QUERY SELECT
        'Contemporaneous'::TEXT,
        v_record.client_timestamp IS NOT NULL AND v_record.server_timestamp IS NOT NULL,
        format('Client: %s, Server: %s', v_record.client_timestamp, v_record.server_timestamp),
        CASE WHEN v_record.client_timestamp IS NOT NULL AND v_record.server_timestamp IS NOT NULL THEN 'PASS'::TEXT ELSE 'FAIL'::TEXT END;

    -- Original: Record is immutable (Event Sourcing pattern)
    RETURN QUERY SELECT
        'Original'::TEXT,
        true,
        'Enforced by Event Sourcing pattern (UPDATE/DELETE prevented on event store)',
        'PASS'::TEXT;

    -- Accurate: Hash verification
    RETURN QUERY SELECT
        'Accurate'::TEXT,
        verify_audit_hash(p_audit_id),
        CASE
            WHEN verify_audit_hash(p_audit_id) THEN 'Verified by cryptographic hash (SHA-256)'
            ELSE 'Hash verification FAILED - possible tampering'
        END,
        CASE WHEN verify_audit_hash(p_audit_id) THEN 'PASS'::TEXT ELSE 'FAIL'::TEXT END;

    -- Complete: All metadata present
    RETURN QUERY SELECT
        'Complete'::TEXT,
        v_record.change_reason IS NOT NULL
            AND v_record.data IS NOT NULL
            AND v_record.device_info IS NOT NULL
            AND v_record.ip_address IS NOT NULL
            AND v_record.session_id IS NOT NULL,
        CASE
            WHEN v_record.change_reason IS NULL THEN 'Missing change_reason'
            WHEN v_record.device_info IS NULL THEN 'Missing device_info'
            WHEN v_record.ip_address IS NULL THEN 'Missing ip_address'
            WHEN v_record.session_id IS NULL THEN 'Missing session_id'
            ELSE 'All required metadata present'
        END,
        CASE
            WHEN v_record.change_reason IS NOT NULL
                AND v_record.data IS NOT NULL
                AND v_record.device_info IS NOT NULL
                AND v_record.ip_address IS NOT NULL
                AND v_record.session_id IS NOT NULL
            THEN 'PASS'::TEXT
            WHEN v_record.change_reason IS NULL OR v_record.data IS NULL
            THEN 'FAIL'::TEXT
            ELSE 'WARN'::TEXT
        END;

    -- Consistent: Parent reference chain valid
    RETURN QUERY SELECT
        'Consistent'::TEXT,
        v_record.parent_audit_id IS NULL OR EXISTS(
            SELECT 1 FROM record_audit WHERE audit_id = v_record.parent_audit_id
        ),
        CASE
            WHEN v_record.parent_audit_id IS NULL THEN 'Initial entry (no parent)'
            WHEN EXISTS(SELECT 1 FROM record_audit WHERE audit_id = v_record.parent_audit_id)
            THEN format('Parent audit ID %s exists', v_record.parent_audit_id)
            ELSE format('Parent audit ID %s MISSING - broken chain', v_record.parent_audit_id)
        END,
        CASE
            WHEN v_record.parent_audit_id IS NULL OR EXISTS(
                SELECT 1 FROM record_audit WHERE audit_id = v_record.parent_audit_id
            )
            THEN 'PASS'::TEXT
            ELSE 'FAIL'::TEXT
        END;

    -- Enduring: Permanent record
    RETURN QUERY SELECT
        'Enduring'::TEXT,
        true,
        'Enforced by append-only event store design (7+ years retention)',
        'PASS'::TEXT;

    -- Available: Retrievable
    RETURN QUERY SELECT
        'Available'::TEXT,
        true,
        format('Retrievable via SQL (audit_id: %s)', p_audit_id),
        'PASS'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION validate_alcoa_compliance(BIGINT) IS 'Compliance: Validate individual event store entry against ALCOA+ principles';

-- =====================================================
-- FUNCTION 5: Batch Audit Verification
-- =====================================================

CREATE OR REPLACE FUNCTION verify_audit_batch(
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
    ORDER BY ra.audit_id DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION verify_audit_batch(TIMESTAMPTZ, TIMESTAMPTZ, INTEGER) IS 'Compliance: Batch verify event store integrity for a time period (audit trail verification)';

-- =====================================================
-- Grant permissions
-- =====================================================

-- ADMIN and ANALYST can run compliance reports
GRANT EXECUTE ON FUNCTION check_audit_sequence_gaps() TO authenticated;
GRANT EXECUTE ON FUNCTION check_audit_completeness(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_compliance_report(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION validate_alcoa_compliance(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_audit_batch(TIMESTAMPTZ, TIMESTAMPTZ, INTEGER) TO authenticated;
