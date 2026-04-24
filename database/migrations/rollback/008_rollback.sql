-- =====================================================
-- Rollback: Remove app_users_app_uuid_unique index
-- Number: 008
-- Description: Drops the partial unique index on app_users(app_uuid) added
--   in migration 008 (CUR-1055). After rollback, the server-side upsert in
--   diary_functions still works correctly but the DB-level race-condition
--   guard is removed.
-- =====================================================

DROP INDEX CONCURRENTLY IF EXISTS app_users_app_uuid_unique;

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'app_users_app_uuid_unique'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: app_users_app_uuid_unique still exists';
    END IF;

    RAISE NOTICE 'Rollback 008 complete: app_users_app_uuid_unique index removed';
END $$;
