-- =====================================================
-- Rollback: Add questionnaire action types to admin_action_log
-- Number: 007
-- Description: Restores the original admin_action_log_action_type_check
--   constraint, removing the questionnaire action types added in
--   migration 007 (CUR-1111, CUR-1117).
--
-- ⚠️  DATA-DEPENDENT WARNING: The VALIDATE step (step 3) will FAIL if
-- any rows with questionnaire action types already exist in
-- admin_action_log (QUESTIONNAIRE_SENT, QUESTIONNAIRE_DELETED,
-- QUESTIONNAIRE_UNLOCKED, QUESTIONNAIRE_FINALIZED, QUESTIONNAIRE_SUBMITTED).
-- Delete or archive those rows before running this rollback.
-- =====================================================

BEGIN;

-- Step 1: Re-add original constraint (NOT VALID — no row scan, no lock)
ALTER TABLE admin_action_log
  ADD CONSTRAINT admin_action_log_action_type_check
  CHECK (action_type IN (
    'ASSIGN_USER', 'ASSIGN_INVESTIGATOR', 'ASSIGN_ANALYST',
    'DATA_CORRECTION', 'ROLE_CHANGE', 'SYSTEM_CONFIG',
    'EMERGENCY_ACCESS', 'BULK_OPERATION',
    'GENERATE_LINKING_CODE', 'REVOKE_LINKING_CODE',
    'DISCONNECT_PATIENT', 'RECONNECT_PATIENT',
    'MARK_NOT_PARTICIPATING', 'REACTIVATE_PATIENT',
    'START_TRIAL'
  )) NOT VALID;

-- Step 2: Drop the migration-007 constraint
ALTER TABLE admin_action_log
  DROP CONSTRAINT IF EXISTS admin_action_log_action_type_check_v2;

COMMIT;

-- Step 3: Validate restored constraint (SHARE UPDATE EXCLUSIVE — non-blocking)
-- Will fail if questionnaire action types exist in admin_action_log.
ALTER TABLE admin_action_log
  VALIDATE CONSTRAINT admin_action_log_action_type_check;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'admin_action_log'
          AND constraint_name = 'admin_action_log_action_type_check'
          AND constraint_type = 'CHECK'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: admin_action_log_action_type_check was not restored';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'admin_action_log'
          AND constraint_name = 'admin_action_log_action_type_check_v2'
          AND constraint_type = 'CHECK'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: admin_action_log_action_type_check_v2 still exists';
    END IF;

    RAISE NOTICE 'Rollback 007 completed successfully';
END $$;
