-- =====================================================
-- Rollback: Drop notifications table + notification_type enum
-- Number: 011
-- Description: Reverses migration 011. Safe in any environment that
--   has the table empty or where data loss is acceptable; warning
--   below applies otherwise.
--
-- ⚠️  DATA-DEPENDENT WARNING: this rollback DROPs the notifications
-- table. Any rows present (envelope history) are unrecoverable. In
-- environments where envelope-on has been live, archive the rows
-- before running this rollback.
--
--   ARCHIVE BEFORE DROP (suggested):
--   COPY notifications TO '/tmp/notifications_pre_rollback.csv' CSV HEADER;
--
-- Reverses everything migration 011 created, in reverse order. The
-- foreign key from notifications → patients is dropped implicitly by
-- the table drop. Other tables do not reference notifications, so no
-- cascade is needed beyond the table itself.
-- =====================================================

BEGIN;

-- Step 1: Drop policies (DROP TABLE would cascade, but explicit is clearer
-- in audit logs and matches the migration's policy declarations).
DROP POLICY IF EXISTS notifications_patient_select ON notifications;
DROP POLICY IF EXISTS notifications_patient_update ON notifications;

-- Step 2: Drop the index (cascades from DROP TABLE but listed for symmetry).
DROP INDEX IF EXISTS notifications_patient_pending_idx;

-- Step 3: Drop the table.
DROP TABLE IF EXISTS notifications;

-- Step 4: Drop the enum type. Must come after the table since the
-- table's column references the type.
DROP TYPE IF EXISTS notification_type;

COMMIT;

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'notifications'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: notifications table still exists';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'notification_type'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: notification_type enum still exists';
    END IF;

    RAISE NOTICE 'Rollback 011 completed successfully';
END $$;
