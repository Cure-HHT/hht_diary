-- =====================================================
-- Migration: Add resend_activation action type to portal_user_audit_log
-- Number: 012
-- Date: 2026-05-18
-- Description: REQ-CAL-p00033 (Resend Activation Email) requires every
--   resend to be logged in the audit trail. The portal_user_audit_log
--   CHECK constraint on `action` (auto-named portal_user_audit_log_action_check
--   from the inline column-level CHECK in schema.sql:811) currently allows:
--     update_name, update_email, update_roles, update_sites,
--     update_status, revoke_sessions
--   It does NOT include 'resend_activation'. Without this migration the
--   backend handler's audit INSERT (portal_user.dart _logAudit call) would
--   raise 23514 check_violation and the audit row would be silently
--   dropped — defeating the FDA 21 CFR Part 11 traceability requirement.
--
--   This migration adds 'resend_activation' to the allowed list using the
--   same NOT VALID + VALIDATE pattern as migration 010 so the change is
--   non-blocking for live tables.
--
--   (Linear: CUR-1125)
-- Dependencies: Requires the base portal_user_audit_log CHECK constraint
--   defined inline in schema.sql (CREATE TABLE portal_user_audit_log).
-- Reference: database/schema.sql:811-814, REQ-CAL-p00033 (Callisto spec)
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-CAL-p00033: Resend Activation Email
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--   REQ-p00004: Immutable Audit Trail via Event Sourcing
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
-- Implements: REQ-CAL-p00033/<audit-trail assertion>
ALTER TABLE portal_user_audit_log
  ADD CONSTRAINT portal_user_audit_log_action_check_v2
  CHECK (action IN (
    'update_name', 'update_email', 'update_roles',
    'update_sites', 'update_status', 'revoke_sessions',
    'resend_activation'
  )) NOT VALID;

-- Step 2: Drop the auto-generated inline constraint from schema.sql
ALTER TABLE portal_user_audit_log
  DROP CONSTRAINT IF EXISTS portal_user_audit_log_action_check;

COMMIT;

-- Step 3: Validate new constraint (SHARE UPDATE EXCLUSIVE — non-blocking)
-- Must run outside the transaction that added it.
ALTER TABLE portal_user_audit_log
  VALIDATE CONSTRAINT portal_user_audit_log_action_check_v2;

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    -- Verify the new constraint exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'portal_user_audit_log'
          AND constraint_name = 'portal_user_audit_log_action_check_v2'
          AND constraint_type = 'CHECK'
    ) THEN
        RAISE EXCEPTION 'portal_user_audit_log_action_check_v2 constraint was not created';
    END IF;

    -- Verify the original auto-named constraint is gone
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'portal_user_audit_log'
          AND constraint_name = 'portal_user_audit_log_action_check'
          AND constraint_type = 'CHECK'
    ) THEN
        RAISE EXCEPTION 'Old portal_user_audit_log_action_check constraint was not dropped';
    END IF;

    RAISE NOTICE 'Migration 012 verified successfully: resend_activation action type added to portal_user_audit_log';
END $$;
