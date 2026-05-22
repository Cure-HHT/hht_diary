-- =====================================================
-- Rollback: Add 'UNWEDGE' to edc_sync_log.operation CHECK constraint
-- Number: 014
-- Description: Restores the original inline CHECK constraint on
--   edc_sync_log.operation (auto-named edc_sync_log_operation_check) that
--   excludes 'UNWEDGE'.
--
-- WARNING: The VALIDATE step (step 3) will FAIL if any rows with
-- operation='UNWEDGE' already exist in edc_sync_log. edc_sync_log has
-- DO INSTEAD NOTHING rules on UPDATE/DELETE (schema.sql:235-236), so cleanup
-- requires temporarily disabling those rules. In practice rollback should
-- only occur in environments where 014 has not yet logged any UNWEDGE rows.
-- =====================================================

set lock_timeout = '2s';
set statement_timeout = '10s';

BEGIN;

-- Step 1: Re-add the pre-014 constraint (NOT VALID — no row scan, no lock).
ALTER TABLE edc_sync_log
  ADD CONSTRAINT edc_sync_log_operation_check
  CHECK (operation IN (
    'SITES_SYNC', 'PATIENTS_SYNC', 'METADATA_SYNC', 'FULL_SYNC'
  )) NOT VALID;

-- Step 2: Drop the v2 constraint added by 014.
ALTER TABLE edc_sync_log
  DROP CONSTRAINT IF EXISTS edc_sync_log_operation_check_v2;

COMMIT;

-- Step 3: Validate the restored constraint. Fails if UNWEDGE rows exist.
ALTER TABLE edc_sync_log
  VALIDATE CONSTRAINT edc_sync_log_operation_check;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'edc_sync_log'
          AND constraint_name = 'edc_sync_log_operation_check'
          AND constraint_type = 'CHECK'
    ) THEN
        RAISE EXCEPTION 'edc_sync_log_operation_check constraint was not restored';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'edc_sync_log'
          AND constraint_name = 'edc_sync_log_operation_check_v2'
          AND constraint_type = 'CHECK'
    ) THEN
        RAISE EXCEPTION 'edc_sync_log_operation_check_v2 constraint was not dropped';
    END IF;

    RAISE NOTICE 'Rollback 014 verified successfully: UNWEDGE operation removed from edc_sync_log';
END $$;
