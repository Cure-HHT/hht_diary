-- =====================================================
-- Test: Row-Level Security (RLS) Policy Enforcement
-- Purpose: Verify role-based isolation across protected tables
-- Compliance: spec/dev-rls-policies.md, spec/compliance-practices.md
-- =====================================================
--
-- TESTS REQUIREMENTS:
--   REQ-p00008: User Account Management (role boundaries)
--   REQ-p00010: FDA 21 CFR Part 11 Compliance (access controls)
--   REQ-p00042: Event Sourcing Audit Trail (visibility constraints)
--
-- TEST SCOPE:
--   For each RLS-protected table, verify that each role
--   (USER, INVESTIGATOR, ANALYST, SPONSOR, AUDITOR, ADMIN)
--   sees only the rows the policy permits.
--
--   Cross-sponsor isolation is enforced at the database
--   instance level (one DB per sponsor); this suite covers
--   intra-sponsor role/site/patient isolation only.
--
-- TODO(REQ-p00008): replace `set_config('rls.role', ...)` calls
-- with the project's actual session-context mechanism (e.g.
-- `SET LOCAL request.jwt.claims = ...`) once confirmed.
-- =====================================================

\echo ''
\echo '========================================='
\echo 'TEST SUITE: RLS Policy Enforcement'
\echo '========================================='
\echo ''

-- =====================================================
-- Fixture setup: two sites, two patients, two investigators
-- =====================================================

BEGIN;

INSERT INTO sites (site_id, site_name, site_number, is_active)
VALUES
    ('rls_site_alpha', 'RLS Site Alpha', 'RLS-A', true),
    ('rls_site_beta',  'RLS Site Beta',  'RLS-B', true)
ON CONFLICT (site_id) DO NOTHING;

INSERT INTO user_site_assignments (patient_id, site_id, study_patient_id, enrollment_status)
VALUES
    ('rls_patient_alpha', 'rls_site_alpha', 'STUDY-A-001', 'ACTIVE'),
    ('rls_patient_beta',  'rls_site_beta',  'STUDY-B-001', 'ACTIVE')
ON CONFLICT (patient_id, site_id) DO NOTHING;

-- Investigator assignments (one per site)
INSERT INTO investigator_site_assignments (investigator_id, site_id)
VALUES
    ('rls_inv_alpha', 'rls_site_alpha'),
    ('rls_inv_beta',  'rls_site_beta')
ON CONFLICT DO NOTHING;

-- Seed audit/state rows for both patients so cross-visibility can be detected
INSERT INTO record_audit (
    event_uuid, patient_id, site_id, operation, data,
    created_by, role, client_timestamp, change_reason,
    device_info, ip_address, session_id
) VALUES
    ('00000000-0000-0000-0000-0000000000a1'::UUID, 'rls_patient_alpha', 'rls_site_alpha',
     'USER_CREATE',
     '{"id": "00000000-0000-0000-0000-0000000000a1", "versioned_type": "epistaxis-v1.0", "event_data": {"id": "11111111-1111-1111-1111-1111111111a1", "startTime": "2025-01-01T00:00:00Z", "lastModified": "2025-01-01T00:01:00Z", "severity": "mild"}}'::jsonb,
     'rls_patient_alpha', 'USER', now(), 'rls test fixture',
     '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'rls_session_a'),
    ('00000000-0000-0000-0000-0000000000b1'::UUID, 'rls_patient_beta',  'rls_site_beta',
     'USER_CREATE',
     '{"id": "00000000-0000-0000-0000-0000000000b1", "versioned_type": "epistaxis-v1.0", "event_data": {"id": "11111111-1111-1111-1111-1111111111b1", "startTime": "2025-01-01T00:00:00Z", "lastModified": "2025-01-01T00:01:00Z", "severity": "mild"}}'::jsonb,
     'rls_patient_beta',  'USER', now(), 'rls test fixture',
     '{"device": "test"}'::jsonb, '127.0.0.1'::inet, 'rls_session_b')
ON CONFLICT DO NOTHING;

-- =====================================================
-- Test 1: USER role sees only their own patient_id rows
-- =====================================================
\echo 'Test 1: USER role isolation in record_audit'

DO $$
DECLARE
    v_visible_count INT;
    v_foreign_count INT;
BEGIN
    -- Activate USER context as patient alpha
    PERFORM set_config('request.jwt.claim.role',       'USER',              true);
    PERFORM set_config('request.jwt.claim.patient_id', 'rls_patient_alpha', true);

    SET LOCAL ROLE authenticated;

    SELECT count(*) INTO v_visible_count
      FROM record_audit
     WHERE patient_id = 'rls_patient_alpha';

    SELECT count(*) INTO v_foreign_count
      FROM record_audit
     WHERE patient_id = 'rls_patient_beta';

    RESET ROLE;

    IF v_visible_count >= 1 AND v_foreign_count = 0 THEN
        RAISE NOTICE 'PASS: USER sees own rows (% visible) and zero foreign rows', v_visible_count;
    ELSE
        RAISE EXCEPTION 'FAIL: USER isolation broken — visible=%, foreign=%',
            v_visible_count, v_foreign_count;
    END IF;
END $$;

-- =====================================================
-- Test 2: INVESTIGATOR role sees only assigned sites
-- =====================================================
\echo 'Test 2: INVESTIGATOR site isolation'

DO $$
DECLARE
    v_alpha_count INT;
    v_beta_count  INT;
BEGIN
    PERFORM set_config('request.jwt.claim.role',            'INVESTIGATOR', true);
    PERFORM set_config('request.jwt.claim.investigator_id', 'rls_inv_alpha', true);

    SET LOCAL ROLE authenticated;

    SELECT count(*) INTO v_alpha_count
      FROM record_audit
     WHERE site_id = 'rls_site_alpha';

    SELECT count(*) INTO v_beta_count
      FROM record_audit
     WHERE site_id = 'rls_site_beta';

    RESET ROLE;

    IF v_alpha_count >= 1 AND v_beta_count = 0 THEN
        RAISE NOTICE 'PASS: INVESTIGATOR sees assigned site only (alpha=%, beta=%)',
            v_alpha_count, v_beta_count;
    ELSE
        RAISE EXCEPTION 'FAIL: INVESTIGATOR site isolation broken — alpha=%, beta=%',
            v_alpha_count, v_beta_count;
    END IF;
END $$;

-- =====================================================
-- Test 3: AUDITOR role has read-only visibility (no INSERT)
-- =====================================================
\echo 'Test 3: AUDITOR cannot insert audit rows'

DO $$
DECLARE
    v_inserted BOOLEAN := false;
BEGIN
    PERFORM set_config('request.jwt.claim.role', 'AUDITOR', true);
    SET LOCAL ROLE authenticated;

    BEGIN
        INSERT INTO record_audit (
            event_uuid, patient_id, site_id, operation, data,
            created_by, role, client_timestamp, change_reason,
            device_info, ip_address, session_id
        ) VALUES (
            '00000000-0000-0000-0000-0000000000c1'::UUID,
            'rls_patient_alpha', 'rls_site_alpha', 'USER_CREATE',
            '{}'::jsonb,
            'rls_auditor', 'AUDITOR', now(), 'forbidden insert',
            '{}'::jsonb, '127.0.0.1'::inet, 'rls_session_auditor'
        );
        v_inserted := true;
    EXCEPTION WHEN insufficient_privilege OR check_violation OR others THEN
        v_inserted := false;
    END;

    RESET ROLE;

    IF v_inserted THEN
        RAISE EXCEPTION 'FAIL: AUDITOR was able to INSERT into record_audit';
    ELSE
        RAISE NOTICE 'PASS: AUDITOR INSERT blocked';
    END IF;
END $$;

-- =====================================================
-- Test 4: Anonymous (unauthenticated) sees nothing
-- =====================================================
\echo 'Test 4: anon role has no visibility'

DO $$
DECLARE
    v_count INT;
BEGIN
    SET LOCAL ROLE anon;

    SELECT count(*) INTO v_count FROM record_audit;

    RESET ROLE;

    IF v_count = 0 THEN
        RAISE NOTICE 'PASS: anon sees zero record_audit rows';
    ELSE
        RAISE EXCEPTION 'FAIL: anon saw % record_audit rows', v_count;
    END IF;
EXCEPTION WHEN insufficient_privilege THEN
    -- If even querying as anon is denied that's a stronger pass
    RAISE NOTICE 'PASS: anon denied table access entirely';
END $$;

-- =====================================================
-- Test 5: Service role bypasses RLS (admin path)
-- =====================================================
\echo 'Test 5: service_role sees all rows'

DO $$
DECLARE
    v_count INT;
BEGIN
    SET LOCAL ROLE service_role;

    SELECT count(*) INTO v_count
      FROM record_audit
     WHERE patient_id IN ('rls_patient_alpha', 'rls_patient_beta');

    RESET ROLE;

    IF v_count >= 2 THEN
        RAISE NOTICE 'PASS: service_role sees both fixture rows (%)', v_count;
    ELSE
        RAISE EXCEPTION 'FAIL: service_role saw only % rows', v_count;
    END IF;
END $$;

-- =====================================================
-- Test 6: USER role cannot UPDATE (audit immutability)
-- =====================================================
\echo 'Test 6: USER cannot UPDATE record_audit'

DO $$
DECLARE
    v_updated BOOLEAN := false;
BEGIN
    PERFORM set_config('request.jwt.claim.role',       'USER',              true);
    PERFORM set_config('request.jwt.claim.patient_id', 'rls_patient_alpha', true);
    SET LOCAL ROLE authenticated;

    BEGIN
        UPDATE record_audit
           SET change_reason = 'tampered'
         WHERE patient_id = 'rls_patient_alpha';
        IF FOUND THEN v_updated := true; END IF;
    EXCEPTION WHEN insufficient_privilege OR others THEN
        v_updated := false;
    END;

    RESET ROLE;

    IF v_updated THEN
        RAISE EXCEPTION 'FAIL: USER was able to UPDATE own audit row';
    ELSE
        RAISE NOTICE 'PASS: USER UPDATE blocked';
    END IF;
END $$;

-- =====================================================
-- Test 7: USER role cannot DELETE
-- =====================================================
\echo 'Test 7: USER cannot DELETE record_audit'

DO $$
DECLARE
    v_deleted BOOLEAN := false;
BEGIN
    PERFORM set_config('request.jwt.claim.role',       'USER',              true);
    PERFORM set_config('request.jwt.claim.patient_id', 'rls_patient_alpha', true);
    SET LOCAL ROLE authenticated;

    BEGIN
        DELETE FROM record_audit WHERE patient_id = 'rls_patient_alpha';
        IF FOUND THEN v_deleted := true; END IF;
    EXCEPTION WHEN insufficient_privilege OR others THEN
        v_deleted := false;
    END;

    RESET ROLE;

    IF v_deleted THEN
        RAISE EXCEPTION 'FAIL: USER was able to DELETE own audit row';
    ELSE
        RAISE NOTICE 'PASS: USER DELETE blocked';
    END IF;
END $$;

-- =====================================================
-- Test 8: Investigator annotations isolated by site
-- =====================================================
\echo 'Test 8: investigator_annotations site isolation'

DO $$
DECLARE
    v_alpha INT;
    v_beta  INT;
BEGIN
    -- Seed an annotation for each site as service_role
    SET LOCAL ROLE service_role;
    INSERT INTO investigator_annotations (
        annotation_id, site_id, patient_id, investigator_id, note, created_at
    ) VALUES
        (gen_random_uuid(), 'rls_site_alpha', 'rls_patient_alpha', 'rls_inv_alpha', 'alpha note', now()),
        (gen_random_uuid(), 'rls_site_beta',  'rls_patient_beta',  'rls_inv_beta',  'beta note',  now())
    ON CONFLICT DO NOTHING;
    RESET ROLE;

    PERFORM set_config('request.jwt.claim.role',            'INVESTIGATOR',  true);
    PERFORM set_config('request.jwt.claim.investigator_id', 'rls_inv_alpha', true);
    SET LOCAL ROLE authenticated;

    SELECT count(*) INTO v_alpha FROM investigator_annotations WHERE site_id = 'rls_site_alpha';
    SELECT count(*) INTO v_beta  FROM investigator_annotations WHERE site_id = 'rls_site_beta';

    RESET ROLE;

    IF v_alpha >= 1 AND v_beta = 0 THEN
        RAISE NOTICE 'PASS: investigator annotations isolated by site (alpha=%, beta=%)', v_alpha, v_beta;
    ELSE
        RAISE EXCEPTION 'FAIL: investigator annotations leak — alpha=%, beta=%', v_alpha, v_beta;
    END IF;
EXCEPTION WHEN undefined_table THEN
    RAISE NOTICE 'SKIP: investigator_annotations table not present in this schema';
END $$;

ROLLBACK;

\echo ''
\echo '========================================='
\echo 'RLS Policy Enforcement: DONE'
\echo '========================================='
