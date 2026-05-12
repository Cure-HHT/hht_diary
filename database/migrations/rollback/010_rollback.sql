-- =====================================================
-- Rollback: Add FCM_NOTIFICATION action type to admin_action_log
-- Number: 010
-- Description: Restores the migration 007 constraint
--   (admin_action_log_action_type_check_v2), removing 'FCM_NOTIFICATION'
--   from the allowed list.
--
-- ⚠️  DATA-DEPENDENT WARNING: The VALIDATE step (step 3) will FAIL if
-- any rows with action_type='FCM_NOTIFICATION' already exist in
-- admin_action_log. Delete or archive those rows before running this
-- rollback. Note: prior to migration 010, _logNotificationAudit failed
-- silently, so existing environments may have ZERO such rows. After
-- migration 010 lands, every FCM send produces one — so rollback
-- requires cleanup in environments where 010 has been live.
-- =====================================================

BEGIN;

-- Step 1: Re-add migration-007 constraint (NOT VALID — no row scan, no lock)
ALTER TABLE admin_action_log
  ADD CONSTRAINT admin_action_log_action_type_check_v2
  CHECK (action_type IN (
    'ASSIGN_USER', 'ASSIGN_INVESTIGATOR', 'ASSIGN_ANALYST',
    'DATA_CORRECTION', 'ROLE_CHANGE', 'SYSTEM_CONFIG',
    'EMERGENCY_ACCESS', 'BULK_OPERATION',
    'GENERATE_LINKING_CODE', 'REVOKE_LINKING_CODE',
    'DISCONNECT_PATIENT', 'RECONNECT_PATIENT',
    'MARK_NOT_PARTICIPATING', 'REACTIVATE_PATIENT',
    'START_TRIAL',
    'QUESTIONNAIRE_SENT', 'QUESTIONNAIRE_DELETED',
    'QUESTIONNAIRE_UNLOCKED', 'QUESTIONNAIRE_FINALIZED',
    'QUESTIONNAIRE_SUBMITTED'
  )) NOT VALID;

-- Step 2: Drop the migration-010 constraint
ALTER TABLE admin_action_log
  DROP CONSTRAINT IF EXISTS admin_action_log_action_type_check_v3;

COMMIT;

-- Step 3: Validate restored constraint (SHARE UPDATE EXCLUSIVE — non-blocking)
-- Will fail if FCM_NOTIFICATION rows exist in admin_action_log.
ALTER TABLE admin_action_log
  VALIDATE CONSTRAINT admin_action_log_action_type_check_v2;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'admin_action_log'
          AND constraint_name = 'admin_action_log_action_type_check_v2'
          AND constraint_type = 'CHECK'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: admin_action_log_action_type_check_v2 was not restored';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'admin_action_log'
          AND constraint_name = 'admin_action_log_action_type_check_v3'
          AND constraint_type = 'CHECK'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: admin_action_log_action_type_check_v3 still exists';
    END IF;

    RAISE NOTICE 'Rollback 010 completed successfully';
END $$;
