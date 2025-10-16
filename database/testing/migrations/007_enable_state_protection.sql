-- =====================================================
-- Migration: 007_enable_state_protection
-- Description: Enable environment-aware state modification prevention
-- Ticket: TICKET-007
-- Date: 2025-10-14
-- Compliance: FDA 21 CFR Part 11 - Data Integrity
-- =====================================================

-- Drop any existing triggers (idempotent)
DROP TRIGGER IF EXISTS prevent_direct_state_update ON record_state;
DROP TRIGGER IF EXISTS prevent_direct_state_insert ON record_state;

-- Create environment-aware triggers
DO $$
DECLARE
    v_environment TEXT;
BEGIN
    -- Get current environment setting
    v_environment := current_setting('app.environment', true);

    -- Log the environment we're running in
    RAISE NOTICE 'Running migration 007 in environment: %', COALESCE(v_environment, 'development (default)');

    -- Check if we're in production environment
    IF v_environment = 'production' THEN
        -- Enable state modification prevention in production
        CREATE TRIGGER prevent_direct_state_update
            BEFORE UPDATE ON record_state
            FOR EACH ROW
            EXECUTE FUNCTION prevent_direct_state_modification();

        CREATE TRIGGER prevent_direct_state_insert
            BEFORE INSERT ON record_state
            FOR EACH ROW
            EXECUTE FUNCTION prevent_direct_state_modification();

        RAISE NOTICE 'Production mode: State modification prevention ENABLED';
        RAISE NOTICE 'All changes to record_state must go through record_event store';
    ELSE
        RAISE NOTICE 'Development mode: State modification prevention DISABLED';
        RAISE NOTICE 'Direct state modifications are allowed for testing';
        RAISE NOTICE 'To enable production mode: ALTER DATABASE SET app.environment = ''production''';
    END IF;
END $$;

-- Verify migration success
DO $$
DECLARE
    v_env TEXT;
    v_trigger_count INTEGER;
    v_function_exists BOOLEAN;
BEGIN
    -- Get current environment
    v_env := current_setting('app.environment', true);

    -- Check if prevent_direct_state_modification function exists
    SELECT EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'prevent_direct_state_modification'
    ) INTO v_function_exists;

    IF NOT v_function_exists THEN
        RAISE EXCEPTION 'Migration failed: prevent_direct_state_modification function not found. Run triggers.sql first.';
    END IF;

    -- Count protection triggers
    SELECT COUNT(*) INTO v_trigger_count
    FROM pg_trigger
    WHERE tgname LIKE 'prevent_direct_state%';

    -- Verify trigger count matches environment
    IF v_env = 'production' THEN
        IF v_trigger_count < 2 THEN
            RAISE EXCEPTION 'Migration failed: Expected 2 triggers in production mode, found %', v_trigger_count;
        END IF;
        RAISE NOTICE '✓ Migration verification passed: % triggers enabled for production', v_trigger_count;
    ELSE
        IF v_trigger_count > 0 THEN
            RAISE WARNING 'Unexpected: Found % triggers in development mode (should be 0)', v_trigger_count;
        END IF;
        RAISE NOTICE '✓ Migration verification passed: Development mode confirmed';
    END IF;

    RAISE NOTICE '✓ Migration 007_enable_state_protection completed successfully';
    RAISE NOTICE 'Environment: %', COALESCE(v_env, 'development');
    RAISE NOTICE 'Trigger count: %', v_trigger_count;
END $$;
