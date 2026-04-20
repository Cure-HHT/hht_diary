-- =====================================================
-- Rollback: Add description to sponsor_role_mapping
-- Number: 006
-- Description: Removes description column added in migration 006
-- =====================================================

BEGIN;

SET lock_timeout = '1s';
SET statement_timeout = '5s';

-- squawk-ignore ban-drop-column
ALTER TABLE sponsor_role_mapping DROP COLUMN IF EXISTS description;

-- Verification
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'sponsor_role_mapping'
        AND column_name = 'description'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: description column still exists';
    END IF;

    RAISE NOTICE 'Rollback 006 completed successfully';
END $$;

COMMIT;
