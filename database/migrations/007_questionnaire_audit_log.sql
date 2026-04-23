-- =====================================================
-- Migration: Add questionnaire action types to admin_action_log
-- Number: 007
-- Date: 2026-04-21
-- Description: The questionnaire handlers (send, delete, unlock, finalize)
--   in the portal server, and the submit handler in the diary server, all log
--   to admin_action_log. However, the five corresponding action type values
--   were never included in the admin_action_log_action_type_check constraint,
--   causing every questionnaire operation to fail at the audit-log INSERT with
--   a CHECK constraint violation.
--
--   Fixes:
--     CUR-1111 — Send Questionnaire Fails (Audit Log Constraint Violation)
--     CUR-1117 — Questionnaire Submission Blocked by Internal Server Error
--
--   (Linear: CUR-1111, CUR-1117)
-- Dependencies: Requires base schema (001)
-- Reference: database/schema.sql
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--   REQ-p00011: ALCOA+ Data Integrity Principles
--   REQ-CAL-p00023: Questionnaire Lifecycle Audit Trail
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

-- Step 2: Drop the old restrictive constraint
ALTER TABLE admin_action_log
  DROP CONSTRAINT IF EXISTS admin_action_log_action_type_check;

COMMIT;

-- Step 3: Validate new constraint (SHARE UPDATE EXCLUSIVE — non-blocking)
-- Must run outside the transaction that added it.
ALTER TABLE admin_action_log
  VALIDATE CONSTRAINT admin_action_log_action_type_check_v2;

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    -- Verify the new constraint exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'admin_action_log'
          AND constraint_name = 'admin_action_log_action_type_check_v2'
          AND constraint_type = 'CHECK'
    ) THEN
        RAISE EXCEPTION 'admin_action_log_action_type_check_v2 constraint was not created';
    END IF;

    -- Verify the old constraint is gone
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'admin_action_log'
          AND constraint_name = 'admin_action_log_action_type_check'
          AND constraint_type = 'CHECK'
    ) THEN
        RAISE EXCEPTION 'Old admin_action_log_action_type_check constraint was not dropped';
    END IF;

    RAISE NOTICE 'Migration 007 verified successfully: questionnaire action types added to admin_action_log';
END $$;
