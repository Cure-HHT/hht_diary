-- =====================================================
-- Test: Migration Rollback Safety
-- Purpose: Verify each migration's rollback returns the
--          schema to the pre-migration baseline.
-- Compliance: spec/dev-database-migrations.md
-- =====================================================
--
-- TESTS REQUIREMENTS:
--   REQ-d00043: Safe Migrations
--   REQ-p00010: FDA 21 CFR Part 11 Compliance (recoverability)
--
-- TEST SCOPE:
--   For every migration with a paired rollback in
--   database/migrations/rollback/, this test:
--     1. snapshots schema (information_schema.columns +
--        pg_indexes + pg_constraint) before forward migration
--     2. applies the forward migration
--     3. applies the rollback
--     4. snapshots again
--     5. asserts the two snapshots are equivalent
--
-- HARNESS NOTE: this file is invoked via run_all_tests.sh
-- against an init.sql baseline DB. It intentionally does NOT
-- cover migrations 005 and 009, which currently lack rollback
-- files — those are tracked as separate gaps.
-- =====================================================

\echo ''
\echo '========================================='
\echo 'TEST SUITE: Migration Rollback'
\echo '========================================='
\echo ''

CREATE TEMP TABLE migration_snapshot (
    label    TEXT NOT NULL,
    kind     TEXT NOT NULL,    -- 'column' | 'index' | 'constraint'
    object   TEXT NOT NULL,
    detail   TEXT NOT NULL
);

CREATE OR REPLACE FUNCTION pg_temp.capture_snapshot(p_label TEXT) RETURNS VOID AS $$
BEGIN
    INSERT INTO migration_snapshot (label, kind, object, detail)
    SELECT p_label, 'column',
           table_schema || '.' || table_name || '.' || column_name,
           data_type || '|' || coalesce(column_default,'') || '|' || is_nullable
      FROM information_schema.columns
     WHERE table_schema = 'public';

    INSERT INTO migration_snapshot (label, kind, object, detail)
    SELECT p_label, 'index', schemaname || '.' || indexname, indexdef
      FROM pg_indexes
     WHERE schemaname = 'public';

    INSERT INTO migration_snapshot (label, kind, object, detail)
    SELECT p_label, 'constraint',
           conrelid::regclass || '.' || conname,
           pg_get_constraintdef(oid)
      FROM pg_constraint
     WHERE connamespace = 'public'::regnamespace;
END $$ LANGUAGE plpgsql;

-- =====================================================
-- Helper: assert snapshot equivalence between two labels
-- =====================================================
CREATE OR REPLACE FUNCTION pg_temp.assert_snapshots_equal(
    p_label_a TEXT, p_label_b TEXT, p_test_name TEXT
) RETURNS VOID AS $$
DECLARE
    v_diff_count INT;
    v_sample TEXT;
BEGIN
    SELECT count(*), string_agg(kind || ':' || object, ', ' ORDER BY kind, object)
      INTO v_diff_count, v_sample
      FROM (
        SELECT kind, object, detail FROM migration_snapshot WHERE label = p_label_a
        EXCEPT
        SELECT kind, object, detail FROM migration_snapshot WHERE label = p_label_b
        UNION
        SELECT kind, object, detail FROM migration_snapshot WHERE label = p_label_b
        EXCEPT
        SELECT kind, object, detail FROM migration_snapshot WHERE label = p_label_a
      ) d;

    IF v_diff_count = 0 THEN
        RAISE NOTICE 'PASS: % — schema equivalent before vs after rollback', p_test_name;
    ELSE
        RAISE EXCEPTION 'FAIL: % — % schema differences (sample: %)',
            p_test_name, v_diff_count, left(v_sample, 200);
    END IF;
END $$ LANGUAGE plpgsql;

-- =====================================================
-- Test 004: questionnaire and fcm_tokens
-- =====================================================
\echo 'Test 004: rollback questionnaire_and_fcm_tokens'

PERFORM pg_temp.capture_snapshot('pre_004');
\i ../migrations/004_questionnaire_and_fcm_tokens.sql
\i ../migrations/rollback/004_rollback.sql
PERFORM pg_temp.capture_snapshot('post_004');
SELECT pg_temp.assert_snapshots_equal('pre_004', 'post_004', 'migration 004');

-- =====================================================
-- Test 006: add_role_mapping_description
-- =====================================================
\echo 'Test 006: rollback add_role_mapping_description'

PERFORM pg_temp.capture_snapshot('pre_006');
\i ../migrations/006_add_role_mapping_description.sql
\i ../migrations/rollback/006_rollback.sql
PERFORM pg_temp.capture_snapshot('post_006');
SELECT pg_temp.assert_snapshots_equal('pre_006', 'post_006', 'migration 006');

-- =====================================================
-- Test 007: questionnaire_audit_log
-- =====================================================
\echo 'Test 007: rollback questionnaire_audit_log'

PERFORM pg_temp.capture_snapshot('pre_007');
\i ../migrations/007_questionnaire_audit_log.sql
\i ../migrations/rollback/007_rollback.sql
PERFORM pg_temp.capture_snapshot('post_007');
SELECT pg_temp.assert_snapshots_equal('pre_007', 'post_007', 'migration 007');

-- =====================================================
-- Test 008: app_uuid_uniqueness
-- =====================================================
\echo 'Test 008: rollback app_uuid_uniqueness'

PERFORM pg_temp.capture_snapshot('pre_008');
\i ../migrations/008_app_uuid_uniqueness.sql
\i ../migrations/rollback/008_rollback.sql
PERFORM pg_temp.capture_snapshot('post_008');
SELECT pg_temp.assert_snapshots_equal('pre_008', 'post_008', 'migration 008');

-- =====================================================
-- Document missing rollbacks (informational, not a failure)
-- =====================================================
\echo 'Note: migrations 005 and 009 have no paired rollback files.'
\echo 'Tracking as gap: see PHASE_4.x_WORKLOG for remediation.'

\echo ''
\echo '========================================='
\echo 'Migration Rollback: DONE'
\echo '========================================='
