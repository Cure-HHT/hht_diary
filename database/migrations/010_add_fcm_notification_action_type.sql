-- =====================================================
-- Migration: Add FCM_NOTIFICATION action type to admin_action_log
-- Number: 010
-- Date: 2026-05-07
-- Description: notification_service.dart writes admin_action_log rows with
--   action_type='FCM_NOTIFICATION' after every FCM send
--   (apps/sponsor-portal/portal_functions/lib/src/notification_service.dart:417),
--   but the constraint admin_action_log_action_type_check_v2 introduced in
--   migration 007 does not include 'FCM_NOTIFICATION' in its allowed list.
--   Effect: every FCM send → audit insert → CHECK constraint violation →
--   exception caught and swallowed inside _logNotificationAudit. The send
--   succeeds but the audit row is silently dropped.
--
--   Confirmed live in callisto4-qa (2026-05-06): the log entry
--   "FCM failed to log notification audit" accompanies every successful
--   "FCM sent" log, with error
--   23514: ... violates check constraint "admin_action_log_action_type_check_v2".
--
--   FDA / 21 CFR Part 11 implication: there is no audit trail for FCM
--   notification sends in any environment running migration 007. The
--   QUESTIONNAIRE_SENT (etc.) audit row exists and references
--   fcm_message_id, so the admin's action is recorded, but the FCM
--   delivery attempt is not.
--
--   This migration adds 'FCM_NOTIFICATION' to the allowed list using the
--   same NOT VALID + VALIDATE pattern as migration 007.
--
--   (Linear: CUR-826)
-- Dependencies: Requires migration 007 (admin_action_log_action_type_check_v2)
-- Reference: database/schema.sql, docs/fcm-notification-redesign-plan.md (Issue #26)
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--   REQ-p00011: ALCOA+ Data Integrity Principles
--   REQ-CAL-p00082: Patient Alert Delivery
--   REQ-p00049: Ancillary Platform Services (push notifications)
-- =====================================================

-- =====================================================
-- SAFE MIGRATION STRATEGY
-- =====================================================
-- We cannot ALTER an existing CHECK constraint in-place. The safe approach:
--
--   1. ADD new constraint with NOT VALID — registers the constraint without
--      scanning existing rows; zero table lock.
--   2. DROP old constraint — removes the restricting constraint.
--   3. VALIDATE new constraint — scans existing rows under a
--      SHARE UPDATE EXCLUSIVE lock, which does NOT block reads or writes.
--
-- This ordering ensures there is never a window without a constraint.
-- =====================================================

set lock_timeout = '2s';
set statement_timeout = '10s';

BEGIN;

-- Step 1: Add updated constraint (NOT VALID — no row scan, no lock)
ALTER TABLE admin_action_log
  ADD CONSTRAINT admin_action_log_action_type_check_v3
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
    'QUESTIONNAIRE_SUBMITTED',
    'FCM_NOTIFICATION'
  )) NOT VALID;

-- Step 2: Drop the migration-007 constraint
ALTER TABLE admin_action_log
  DROP CONSTRAINT IF EXISTS admin_action_log_action_type_check_v2;

COMMIT;

-- Step 3: Validate new constraint (SHARE UPDATE EXCLUSIVE — non-blocking)
-- Must run outside the transaction that added it.
ALTER TABLE admin_action_log
  VALIDATE CONSTRAINT admin_action_log_action_type_check_v3;

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    -- Verify the new constraint exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'admin_action_log'
          AND constraint_name = 'admin_action_log_action_type_check_v3'
          AND constraint_type = 'CHECK'
    ) THEN
        RAISE EXCEPTION 'admin_action_log_action_type_check_v3 constraint was not created';
    END IF;

    -- Verify the v2 constraint is gone
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'admin_action_log'
          AND constraint_name = 'admin_action_log_action_type_check_v2'
          AND constraint_type = 'CHECK'
    ) THEN
        RAISE EXCEPTION 'Old admin_action_log_action_type_check_v2 constraint was not dropped';
    END IF;

    RAISE NOTICE 'Migration 010 verified successfully: FCM_NOTIFICATION action type added to admin_action_log';
END $$;
