-- One-time dev fix: restore admin_action_log_action_type_check_v2
-- with QUESTIONNAIRE_SUBMITTED included.
-- Run with: psql -U muhammadumair -d postgres -f database/tool/fix_action_type_constraint.sql

ALTER TABLE admin_action_log
  DROP CONSTRAINT IF EXISTS admin_action_log_action_type_check_v2;

ALTER TABLE admin_action_log
  DROP CONSTRAINT IF EXISTS admin_action_log_action_type_check;

ALTER TABLE admin_action_log
  ADD CONSTRAINT admin_action_log_action_type_check_v2
  CHECK (action_type IN (
    'ASSIGN_USER',
    'ASSIGN_INVESTIGATOR',
    'ASSIGN_ANALYST',
    'DATA_CORRECTION',
    'ROLE_CHANGE',
    'SYSTEM_CONFIG',
    'EMERGENCY_ACCESS',
    'BULK_OPERATION',
    'GENERATE_LINKING_CODE',
    'REVOKE_LINKING_CODE',
    'DISCONNECT_PATIENT',
    'RECONNECT_PATIENT',
    'MARK_NOT_PARTICIPATING',
    'REACTIVATE_PATIENT',
    'START_TRIAL',
    'QUESTIONNAIRE_SENT',
    'QUESTIONNAIRE_DELETED',
    'QUESTIONNAIRE_UNLOCKED',
    'QUESTIONNAIRE_FINALIZED',
    'QUESTIONNAIRE_SUBMITTED'
  )) NOT VALID;

-- Verify
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'admin_action_log_action_type_check_v2'
      AND conrelid = 'admin_action_log'::regclass
  ) THEN
    RAISE EXCEPTION 'Constraint was not created';
  END IF;
  RAISE NOTICE 'Fix applied: admin_action_log_action_type_check_v2 now includes QUESTIONNAIRE_SUBMITTED';
END $$;
