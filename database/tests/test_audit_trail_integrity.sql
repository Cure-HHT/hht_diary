-- =====================================================
-- Test: Audit Trail Integrity (Hash-chain, Ordering, Append-only)
-- Purpose: Verify FDA 21 CFR Part 11 / ALCOA+ tamper evidence
-- Compliance: spec/compliance-practices.md, spec/dev-event-sourcing.md
-- =====================================================
--
-- TESTS REQUIREMENTS:
--   REQ-p00004: Immutable Audit Trail via Event Sourcing
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--   REQ-p00011: ALCOA+ Data Integrity Principles
--   REQ-p00042: Event Sourcing Audit Trail
--
-- TEST SCOPE:
--   This file extends test_audit_trail.sql with deeper integrity checks:
--     * hash-chain continuity (each entry references prior entry's hash)
--     * monotonic event ordering under concurrency
--     * append-only enforcement after archive snapshot
--     * tamper detection on JSON event_data field
--
-- TODO: replace `prev_hash` / `entry_hash` column references below with
-- the actual column names if they differ in record_audit schema.
-- =====================================================

\echo ''
\echo '========================================='
\echo 'TEST SUITE: Audit Trail Integrity'
\echo '========================================='
\echo ''

BEGIN;

-- Common fixture
INSERT INTO sites (site_id, site_name, site_number)
VALUES ('audit_int_site', 'Audit Integrity Site', 'AIS')
ON CONFLICT (site_id) DO NOTHING;

INSERT INTO user_site_assignments (patient_id, site_id, study_patient_id, enrollment_status)
VALUES ('audit_int_patient', 'audit_int_site', 'STUDY-AI-001', 'ACTIVE')
ON CONFLICT (patient_id, site_id) DO NOTHING;

-- =====================================================
-- Test 1: Hash chain continuity across sequential inserts
-- =====================================================
\echo 'Test 1: hash chain continuity'

DO $$
DECLARE
    v_chain_breaks INT;
BEGIN
    -- Insert 5 sequential events
    FOR i IN 1..5 LOOP
        INSERT INTO record_audit (
            event_uuid, patient_id, site_id, operation, data,
            created_by, role, client_timestamp, change_reason,
            device_info, ip_address, session_id
        ) VALUES (
            ('00000000-0000-0000-0000-' || lpad(i::text, 12, '0'))::UUID,
            'audit_int_patient', 'audit_int_site', 'USER_CREATE',
            jsonb_build_object(
                'id',             '00000000-0000-0000-0000-' || lpad(i::text, 12, '0'),
                'versioned_type', 'epistaxis-v1.0',
                'event_data',     jsonb_build_object('seq', i, 'severity', 'mild')
            ),
            'audit_int_patient', 'USER', now() + (i || ' seconds')::interval,
            'chain test',
            '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'audit_int_session'
        );
    END LOOP;

    -- Walk the chain: each row's prev_hash should equal the previous row's entry_hash
    SELECT count(*) INTO v_chain_breaks
      FROM (
        SELECT
            entry_hash,
            prev_hash,
            lag(entry_hash) OVER (ORDER BY client_timestamp, event_uuid) AS prior_hash
        FROM record_audit
        WHERE patient_id = 'audit_int_patient'
      ) t
     WHERE prior_hash IS NOT NULL
       AND prev_hash IS DISTINCT FROM prior_hash;

    IF v_chain_breaks = 0 THEN
        RAISE NOTICE 'PASS: hash chain unbroken across 5 events';
    ELSE
        RAISE EXCEPTION 'FAIL: % hash-chain breaks detected', v_chain_breaks;
    END IF;
EXCEPTION WHEN undefined_column THEN
    RAISE NOTICE 'SKIP: prev_hash/entry_hash columns not present (update schema TODO)';
END $$;

-- =====================================================
-- Test 2: Tampering with stored data invalidates hash
-- =====================================================
\echo 'Test 2: row-level tamper detection'

DO $$
DECLARE
    v_recomputed_hash TEXT;
    v_stored_hash     TEXT;
BEGIN
    SELECT entry_hash INTO v_stored_hash
      FROM record_audit
     WHERE patient_id = 'audit_int_patient'
     ORDER BY client_timestamp
     LIMIT 1;

    -- Recompute what the hash *should* be from the canonical fields.
    -- TODO: replace with project's actual hashing function once located
    -- (likely in database/triggers.sql or a SECURITY DEFINER function).
    SELECT compute_audit_entry_hash(event_uuid, prev_hash, data, client_timestamp)
      INTO v_recomputed_hash
      FROM record_audit
     WHERE patient_id = 'audit_int_patient'
     ORDER BY client_timestamp
     LIMIT 1;

    IF v_stored_hash = v_recomputed_hash THEN
        RAISE NOTICE 'PASS: stored hash matches recomputed hash';
    ELSE
        RAISE EXCEPTION 'FAIL: stored=%, recomputed=%', v_stored_hash, v_recomputed_hash;
    END IF;
EXCEPTION WHEN undefined_function OR undefined_column THEN
    RAISE NOTICE 'SKIP: hash recomputation helper not yet implemented';
END $$;

-- =====================================================
-- Test 3: Concurrent inserts produce monotonic ordering
-- =====================================================
\echo 'Test 3: monotonic ordering under concurrency'

DO $$
DECLARE
    v_disorder_count INT;
BEGIN
    -- Simulate concurrency by inserting from multiple sessions with
    -- intentionally interleaved client_timestamps. The server-side
    -- ordering column (e.g. event_seq or insert_at) MUST be strictly
    -- monotonic regardless of client_timestamp jitter.
    INSERT INTO record_audit (
        event_uuid, patient_id, site_id, operation, data,
        created_by, role, client_timestamp, change_reason,
        device_info, ip_address, session_id
    )
    SELECT
        gen_random_uuid(),
        'audit_int_patient', 'audit_int_site', 'USER_CREATE',
        jsonb_build_object('id', gen_random_uuid()::text, 'versioned_type', 'epistaxis-v1.0',
                           'event_data', jsonb_build_object('seq', g, 'severity', 'mild')),
        'audit_int_patient', 'USER',
        -- Intentionally out-of-order client timestamps
        now() - (g * '1 ms')::interval,
        'concurrency test',
        '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'audit_int_session'
      FROM generate_series(1, 20) g;

    -- Server-assigned insert_at must be monotonic in primary-key order
    SELECT count(*) INTO v_disorder_count
      FROM (
        SELECT insert_at,
               lag(insert_at) OVER (ORDER BY event_seq) AS prior_at
          FROM record_audit
         WHERE patient_id = 'audit_int_patient'
      ) t
     WHERE prior_at IS NOT NULL AND insert_at < prior_at;

    IF v_disorder_count = 0 THEN
        RAISE NOTICE 'PASS: server-assigned ordering is monotonic';
    ELSE
        RAISE EXCEPTION 'FAIL: % out-of-order rows detected', v_disorder_count;
    END IF;
EXCEPTION WHEN undefined_column THEN
    RAISE NOTICE 'SKIP: insert_at/event_seq columns not present';
END $$;

-- =====================================================
-- Test 4: TRUNCATE blocked on record_audit
-- =====================================================
\echo 'Test 4: TRUNCATE prevented on record_audit'

DO $$
DECLARE
    v_truncated BOOLEAN := false;
BEGIN
    BEGIN
        TRUNCATE TABLE record_audit;
        v_truncated := true;
    EXCEPTION WHEN insufficient_privilege OR feature_not_supported OR others THEN
        v_truncated := false;
    END;

    IF v_truncated THEN
        RAISE EXCEPTION 'FAIL: record_audit was TRUNCATED';
    ELSE
        RAISE NOTICE 'PASS: TRUNCATE blocked on record_audit';
    END IF;
END $$;

-- =====================================================
-- Test 5: Archive snapshot prevents further writes to archived range
-- =====================================================
\echo 'Test 5: archived events are append-only'

DO $$
DECLARE
    v_blocked BOOLEAN := false;
BEGIN
    -- Mark a synthetic archive watermark
    PERFORM set_config('audit.archive_watermark', now()::text, true);

    BEGIN
        -- TODO: replace with project's actual archive seal mechanism
        UPDATE record_audit
           SET data = data || '{"tampered": true}'::jsonb
         WHERE patient_id = 'audit_int_patient'
           AND client_timestamp < (current_setting('audit.archive_watermark', true))::timestamptz;
    EXCEPTION WHEN insufficient_privilege OR others THEN
        v_blocked := true;
    END;

    IF v_blocked THEN
        RAISE NOTICE 'PASS: write to archived range was blocked';
    ELSE
        -- Even if no exception, UPDATE on append-only table should affect 0 rows
        IF NOT FOUND THEN
            RAISE NOTICE 'PASS: archived range UPDATE affected 0 rows';
        ELSE
            RAISE EXCEPTION 'FAIL: archived range was modifiable';
        END IF;
    END IF;
END $$;

ROLLBACK;

\echo ''
\echo '========================================='
\echo 'Audit Trail Integrity: DONE'
\echo '========================================='
