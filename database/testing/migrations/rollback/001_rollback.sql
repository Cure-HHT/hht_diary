-- =====================================================
-- Rollback: 001 - Initial Schema
-- =====================================================

-- WARNING: This rollback drops the entire database schema!
-- Only use this for development/testing environments.
-- DO NOT run this in production without explicit approval.

BEGIN;

-- Log rollback start
DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'WARNING: Rollback 001 will DROP all database objects!';
    RAISE NOTICE 'This is irreversible and will delete all data!';
    RAISE NOTICE 'Timestamp: %', now();
    RAISE NOTICE '================================================';
END $$;

-- This is a placeholder rollback for the initial schema.
-- In practice, rolling back the initial schema means dropping everything,
-- which should only be done in development/test environments.

-- For production environments, there should be no rollback of migration 001
-- since it represents the initial state.

DO $$
BEGIN
    RAISE EXCEPTION 'Rollback of initial schema (001) is not supported in this environment. Manual intervention required.';
END $$;

ROLLBACK;

-- If you really need to drop everything in a development environment,
-- comment out the RAISE EXCEPTION above and uncomment the following:

/*
-- Drop all tables in correct order to handle foreign keys
DROP TABLE IF EXISTS investigator_annotations CASCADE;
DROP TABLE IF EXISTS sync_metadata CASCADE;
DROP TABLE IF EXISTS record_audit CASCADE;
DROP TABLE IF EXISTS record_state CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;
DROP TABLE IF EXISTS sites CASCADE;

-- Drop all custom functions
DROP FUNCTION IF EXISTS prevent_direct_state_modification() CASCADE;
DROP FUNCTION IF EXISTS update_record_state_from_audit() CASCADE;

COMMIT;

DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Rollback 001 completed - All schema objects dropped';
    RAISE NOTICE 'Timestamp: %', now();
    RAISE NOTICE '================================================';
END $$;
*/
