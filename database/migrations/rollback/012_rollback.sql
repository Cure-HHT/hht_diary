-- =====================================================
-- Rollback: Add resend_activation action type to portal_user_audit_log
-- Number: 012
-- Description: Restores the original inline CHECK constraint on
--   portal_user_audit_log.action (auto-named portal_user_audit_log_action_check)
--   that excludes 'resend_activation'.
--
-- ⚠️  DATA-DEPENDENT WARNING: The VALIDATE step (step 3) will FAIL if any
-- rows with action='resend_activation' already exist in portal_user_audit_log.
-- The audit log has DO INSTEAD NOTHING rules on UPDATE/DELETE (schema.sql:823),
-- so cleanup requires temporarily disabling those rules or recreating the
-- table. In practice rollback should only occur in environments where 012
-- has not yet logged any resend_activation rows.
-- =====================================================

BEGIN;

-- Step 1: Re-add the pre-012 constraint (NOT VALID — no row scan, no lock)
ALTER TABLE portal_user_audit_log
  ADD CONSTRAINT portal_user_audit_log_action_check
  CHECK (action IN (
    'update_name', 'update_email', 'update_roles',
    'update_sites', 'update_status', 'revoke_sessions'
  )) NOT VALID;

-- Step 2: Drop the migration-012 constraint
ALTER TABLE portal_user_audit_log
  DROP CONSTRAINT IF EXISTS portal_user_audit_log_action_check_v2;

COMMIT;

-- Step 3: Validate restored constraint (SHARE UPDATE EXCLUSIVE — non-blocking)
-- Will fail if resend_activation rows exist in portal_user_audit_log.
ALTER TABLE portal_user_audit_log
  VALIDATE CONSTRAINT portal_user_audit_log_action_check;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'portal_user_audit_log'
          AND constraint_name = 'portal_user_audit_log_action_check'
          AND constraint_type = 'CHECK'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: portal_user_audit_log_action_check was not restored';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'portal_user_audit_log'
          AND constraint_name = 'portal_user_audit_log_action_check_v2'
          AND constraint_type = 'CHECK'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: portal_user_audit_log_action_check_v2 still exists';
    END IF;

    RAISE NOTICE 'Rollback 012 completed successfully';
END $$;
