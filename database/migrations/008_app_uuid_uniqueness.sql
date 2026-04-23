-- =====================================================
-- Migration: Add unique constraint on app_users.app_uuid
-- Number: 008
-- Date: 2026-04-23
-- Description: Enforces one app_user record per device by adding a partial
--   unique index on app_users(app_uuid). Partial index (WHERE app_uuid IS NOT
--   NULL) preserves support for anonymous users who enroll without a device UUID.
--   Combined with the atomic upsert in diary_functions/src/user.dart, this
--   closes the race-condition window that allowed two concurrent enrollment
--   requests from the same device to each create a new app_user.
--   (Linear: CUR-1055)
-- Dependencies: Requires migration 001 (app_users table)
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00008: User Account Management
-- =====================================================

-- =====================================================
-- 1. DROP INVALID INDEX IF IT EXISTS FROM A FAILED RUN
-- =====================================================
-- CREATE INDEX CONCURRENTLY leaves behind an invalid index entry when it fails
-- (e.g. due to pre-existing duplicates). Drop it before proceeding so the
-- index creation below starts clean.

DROP INDEX CONCURRENTLY IF EXISTS app_users_app_uuid_unique;

-- =====================================================
-- 2. DEDUPLICATE EXISTING app_uuid VALUES
-- =====================================================
-- Before enforcing uniqueness, null out any duplicate app_uuid entries that
-- exist in the table. Only the newest row (by ctid) per uuid is kept; all
-- others have their app_uuid set to NULL so they become anonymous users.
--
-- This handles legacy rows inserted before the constraint existed (e.g. test
-- data seeded with 'test-app-uuid'). In production, duplicates should not
-- exist — this step is a no-op if the table is already clean.

UPDATE app_users
SET app_uuid = NULL
WHERE ctid NOT IN (
  SELECT MAX(ctid)
  FROM app_users
  WHERE app_uuid IS NOT NULL
  GROUP BY app_uuid
)
AND app_uuid IS NOT NULL;

-- =====================================================
-- 3. PARTIAL UNIQUE INDEX ON app_uuid (CUR-1055)
-- =====================================================
-- Ensures at most one app_user record per device UUID.
-- Anonymous users (app_uuid IS NULL) are excluded from the constraint.
--
-- Uses CONCURRENTLY to avoid locking the table in production (required by Squawk).
-- NOTE: CONCURRENTLY cannot run inside a transaction block — do not wrap in BEGIN/COMMIT.

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS app_users_app_uuid_unique
  ON app_users (app_uuid)
  WHERE app_uuid IS NOT NULL;

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    -- Check index exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'app_users_app_uuid_unique'
    ) THEN
        RAISE EXCEPTION 'app_users_app_uuid_unique index was not created';
    END IF;

    -- Check index is valid (not left in invalid state by a failed CONCURRENTLY run)
    IF NOT EXISTS (
        SELECT 1
        FROM pg_class c
        JOIN pg_index ix ON ix.indexrelid = c.oid
        WHERE c.relname = 'app_users_app_uuid_unique'
          AND ix.indisvalid = true
    ) THEN
        RAISE EXCEPTION 'app_users_app_uuid_unique index exists but is invalid';
    END IF;

    RAISE NOTICE 'Migration 008 complete: app_users_app_uuid_unique index added and verified valid';
END $$;
