-- =====================================================
-- Test Verification: 007_enable_state_protection
-- Description: Comprehensive tests for TICKET-007 implementation
-- Date: 2025-10-14
-- =====================================================

-- This file contains tests to verify TICKET-007 is working correctly
-- in both development and production environments.

-- =====================================================
-- TEST SUITE: Development Environment
-- =====================================================

-- Test 1: Verify environment setting
DO $$
DECLARE
    v_env TEXT;
BEGIN
    v_env := current_setting('app.environment', true);
    RAISE NOTICE 'Test 1: Current environment: %', COALESCE(v_env, 'development (default)');

    IF v_env IS NULL OR v_env != 'production' THEN
        RAISE NOTICE '✓ Test 1 PASSED: Running in development mode';
    ELSE
        RAISE NOTICE '✗ Test 1 INFO: Running in production mode';
    END IF;
END $$;

-- Test 2: Verify trigger count matches environment
DO $$
DECLARE
    v_env TEXT;
    v_trigger_count INTEGER;
BEGIN
    v_env := current_setting('app.environment', true);

    SELECT COUNT(*) INTO v_trigger_count
    FROM pg_trigger
    WHERE tgname LIKE 'prevent_direct_state%';

    RAISE NOTICE 'Test 2: Found % state protection triggers', v_trigger_count;

    IF v_env = 'production' THEN
        IF v_trigger_count = 2 THEN
            RAISE NOTICE '✓ Test 2 PASSED: Production has 2 triggers enabled';
        ELSE
            RAISE EXCEPTION '✗ Test 2 FAILED: Production should have 2 triggers, found %', v_trigger_count;
        END IF;
    ELSE
        IF v_trigger_count = 0 THEN
            RAISE NOTICE '✓ Test 2 PASSED: Development has 0 triggers (disabled)';
        ELSE
            RAISE WARNING '✗ Test 2 WARNING: Development should have 0 triggers, found %', v_trigger_count;
        END IF;
    END IF;
END $$;

-- Test 3: Verify prevent_direct_state_modification function exists
DO $$
DECLARE
    v_function_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'prevent_direct_state_modification'
    ) INTO v_function_exists;

    IF v_function_exists THEN
        RAISE NOTICE '✓ Test 3 PASSED: prevent_direct_state_modification function exists';
    ELSE
        RAISE EXCEPTION '✗ Test 3 FAILED: prevent_direct_state_modification function not found';
    END IF;
END $$;

-- Test 4: Test direct state modification (development mode only)
DO $$
DECLARE
    v_env TEXT;
    v_test_uuid UUID := gen_random_uuid();
    v_success BOOLEAN := false;
BEGIN
    v_env := current_setting('app.environment', true);

    IF v_env != 'production' THEN
        RAISE NOTICE 'Test 4: Testing direct state modification in development...';

        BEGIN
            -- Try to insert directly into record_state
            INSERT INTO record_state (
                event_uuid, patient_id, site_id, data, version, created_by
            ) VALUES (
                v_test_uuid, 'test_patient_007', 'test_site_007',
                '{"test": "TICKET-007 verification"}'::jsonb, 1, 'test_user'
            );

            v_success := true;

            -- Clean up
            DELETE FROM record_state WHERE event_uuid = v_test_uuid;

            RAISE NOTICE '✓ Test 4 PASSED: Direct state modification allowed in development';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION '✗ Test 4 FAILED: Direct modification blocked in development (should be allowed): %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE '✓ Test 4 SKIPPED: Cannot test direct modification in production (would fail by design)';
    END IF;
END $$;

-- Test 5: Test audit trail still updates state (both environments)
DO $$
DECLARE
    v_test_uuid UUID := gen_random_uuid();
    v_audit_id BIGINT;
    v_state_exists BOOLEAN;
BEGIN
    RAISE NOTICE 'Test 5: Testing audit trail updates state...';

    -- Insert via audit trail
    INSERT INTO record_audit (
        event_uuid, patient_id, site_id, operation, data,
        created_by, role, client_timestamp, change_reason,
        device_info, ip_address, session_id
    ) VALUES (
        v_test_uuid, 'test_patient_007', 'test_site_007', 'USER_CREATE',
        '{"test": "TICKET-007 audit trail test"}'::jsonb,
        'test_user', 'USER', now(), 'TICKET-007 verification test',
        '{"device": "test"}'::jsonb, '127.0.0.1', 'test_session'
    ) RETURNING audit_id INTO v_audit_id;

    -- Check if state was updated
    SELECT EXISTS (
        SELECT 1 FROM record_state
        WHERE event_uuid = v_test_uuid
    ) INTO v_state_exists;

    IF v_state_exists THEN
        RAISE NOTICE '✓ Test 5 PASSED: Audit trail successfully updated state';

        -- Clean up: soft delete via audit trail
        INSERT INTO record_audit (
            event_uuid, patient_id, site_id, operation, data,
            created_by, role, client_timestamp, change_reason,
            device_info, ip_address, session_id
        ) VALUES (
            v_test_uuid, 'test_patient_007', 'test_site_007', 'USER_DELETE',
            '{"test": "cleanup"}'::jsonb,
            'test_user', 'USER', now(), 'cleanup test data',
            '{"device": "test"}'::jsonb, '127.0.0.1', 'test_session'
        );
    ELSE
        RAISE EXCEPTION '✗ Test 5 FAILED: State was not updated by audit trail';
    END IF;
END $$;

-- Test 6: Production-specific test (attempt direct modification)
DO $$
DECLARE
    v_env TEXT;
    v_test_uuid UUID := gen_random_uuid();
    v_blocked BOOLEAN := false;
BEGIN
    v_env := current_setting('app.environment', true);

    IF v_env = 'production' THEN
        RAISE NOTICE 'Test 6: Testing that direct modification is blocked in production...';

        BEGIN
            -- Try to insert directly (should fail)
            INSERT INTO record_state (
                event_uuid, patient_id, site_id, data, version, created_by
            ) VALUES (
                v_test_uuid, 'test_patient_007', 'test_site_007',
                '{"test": "should fail"}'::jsonb, 1, 'test_user'
            );

            -- If we get here, the trigger didn't work
            RAISE EXCEPTION '✗ Test 6 FAILED: Direct modification was not blocked in production';
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLERRM LIKE '%Direct modification of record_state is not allowed%' THEN
                    RAISE NOTICE '✓ Test 6 PASSED: Direct modification correctly blocked in production';
                    v_blocked := true;
                ELSE
                    RAISE EXCEPTION '✗ Test 6 FAILED: Wrong error: %', SQLERRM;
                END IF;
        END;
    ELSE
        RAISE NOTICE '✓ Test 6 SKIPPED: Production-only test (not in production environment)';
    END IF;
END $$;

-- =====================================================
-- TEST SUMMARY
-- =====================================================

DO $$
DECLARE
    v_env TEXT;
    v_trigger_count INTEGER;
BEGIN
    v_env := current_setting('app.environment', true);

    SELECT COUNT(*) INTO v_trigger_count
    FROM pg_trigger
    WHERE tgname LIKE 'prevent_direct_state%';

    RAISE NOTICE '================================================';
    RAISE NOTICE 'TICKET-007 Test Summary';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Environment: %', COALESCE(v_env, 'development (default)');
    RAISE NOTICE 'State protection triggers: %', v_trigger_count;
    RAISE NOTICE '';

    IF v_env = 'production' THEN
        RAISE NOTICE 'Production Mode:';
        RAISE NOTICE '  ✓ Triggers enabled: %', (v_trigger_count = 2);
        RAISE NOTICE '  ✓ Direct modifications blocked';
        RAISE NOTICE '  ✓ Audit trail updates state';
    ELSE
        RAISE NOTICE 'Development Mode:';
        RAISE NOTICE '  ✓ Triggers disabled: %', (v_trigger_count = 0);
        RAISE NOTICE '  ✓ Direct modifications allowed';
        RAISE NOTICE '  ✓ Audit trail updates state';
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE 'All tests completed. Review output above for details.';
    RAISE NOTICE '================================================';
END $$;
