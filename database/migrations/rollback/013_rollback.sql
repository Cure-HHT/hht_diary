-- =====================================================
-- Rollback: Drop rave_sync_lockout state table
-- Number: 013
-- Description: Reverses migration 013 (CUR-1361). Drops the
--   rave_sync_lockout singleton table.
--
-- ⚠️  DATA-DEPENDENT WARNING: this rollback DROPs the rave_sync_lockout
-- table. Any lockout state present (consecutive_auth_failures, locked_at,
-- last_unwedged_by_user_id, etc.) is unrecoverable. The table holds live
-- decision state, not audit history — operator-facing audit of unwedge
-- actions is in admin_action_log, which is unaffected by this rollback.
-- In environments where the Rave sync lockout feature has been live,
-- archive the row before running this rollback:
--
--   ARCHIVE BEFORE DROP (suggested):
--   COPY rave_sync_lockout TO '/tmp/rave_sync_lockout_pre_rollback.csv' CSV HEADER;
--
-- The foreign key from rave_sync_lockout.last_unwedged_by_user_id →
-- portal_users(id) is dropped implicitly by the table drop. No other
-- tables reference rave_sync_lockout, so no cascade is needed beyond
-- the table itself.
-- =====================================================

BEGIN;

-- Drop the singleton state table. The seed row (id=1) is dropped
-- implicitly as part of the table drop.
-- squawk-ignore ban-drop-table
DROP TABLE IF EXISTS rave_sync_lockout;

COMMIT;

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'rave_sync_lockout'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: rave_sync_lockout table still exists';
    END IF;

    RAISE NOTICE 'Rollback 013 completed successfully';
END $$;
