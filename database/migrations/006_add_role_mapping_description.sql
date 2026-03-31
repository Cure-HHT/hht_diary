-- =====================================================
-- Migration: Add description to sponsor_role_mapping
-- Number: 006
-- Date: 2026-03-24
-- Description: Adds optional description column to sponsor_role_mapping table
--   so sponsors can define custom role descriptions shown in the portal UI.
--   (Linear: CUR-1070)
-- Dependencies: Requires base schema (001) with sponsor_role_mapping table
-- Reference: database/schema.sql, spec/dev-portal-roles.md
-- =====================================================

BEGIN;

SET lock_timeout = '1s';
SET statement_timeout = '5s';

ALTER TABLE sponsor_role_mapping ADD COLUMN IF NOT EXISTS description TEXT;

COMMENT ON COLUMN sponsor_role_mapping.description IS 'Optional sponsor-specific description for the role';

-- Verification
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'sponsor_role_mapping'
        AND column_name = 'description'
    ) THEN
        RAISE EXCEPTION 'Migration failed: description column not created';
    END IF;

    RAISE NOTICE 'Migration 006 completed successfully';
END $$;

COMMIT;
