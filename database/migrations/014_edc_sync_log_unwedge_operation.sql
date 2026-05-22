-- =====================================================
-- Migration: Add 'UNWEDGE' to edc_sync_log.operation CHECK constraint
-- Number: 014
-- Date: 2026-05-20
-- Description: CUR-1361 introduces a dedicated 'UNWEDGE' operation row in
--   edc_sync_log (written by portal_rave_admin.dart's unwedgeRaveHandler
--   after the clear UPDATE) to track Dev Admin Rave-sync recoveries with
--   per-click metadata (user_id, probe outcome). The original CHECK
--   constraint (defined inline in schema.sql:218) allows only:
--     SITES_SYNC, PATIENTS_SYNC, METADATA_SYNC, FULL_SYNC
--
--   Without this migration the unwedge handler's INSERT raises 23514
--   check_violation and the audit row is silently dropped (the handler
--   wraps the INSERT in try/catch to keep the response path alive, but
--   the history record is lost — defeating FDA 21 CFR Part 11 traceability
--   for the Unwedge action).
--
--   This migration adds 'UNWEDGE' using the same NOT VALID + VALIDATE
--   pattern as migration 012 so the change is non-blocking for live
--   tables.
--
--   (Linear: CUR-1361)
-- Dependencies: Requires the base edc_sync_log table from schema.sql
--   (CREATE TABLE edc_sync_log) and the inline CHECK constraint defined
--   there (auto-named edc_sync_log_operation_check).
-- Reference: database/schema.sql:218, DIARY-OPS-rave-unwedge-authz
-- =====================================================

set lock_timeout = '2s';
set statement_timeout = '10s';

BEGIN;

-- Step 1: Add updated constraint (NOT VALID — no row scan, no lock).
-- Implements: DIARY-OPS-rave-unwedge-authz/B
ALTER TABLE edc_sync_log
  ADD CONSTRAINT edc_sync_log_operation_check_v2
  CHECK (operation IN (
    'SITES_SYNC', 'PATIENTS_SYNC', 'METADATA_SYNC', 'FULL_SYNC', 'UNWEDGE'
  )) NOT VALID;

-- Step 2: Drop the auto-generated inline constraint from schema.sql.
ALTER TABLE edc_sync_log
  DROP CONSTRAINT IF EXISTS edc_sync_log_operation_check;

COMMIT;

-- Step 3: Validate the new constraint (SHARE UPDATE EXCLUSIVE — non-blocking).
-- Must run outside the transaction that added it.
ALTER TABLE edc_sync_log
  VALIDATE CONSTRAINT edc_sync_log_operation_check_v2;

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'edc_sync_log'
          AND constraint_name = 'edc_sync_log_operation_check_v2'
          AND constraint_type = 'CHECK'
    ) THEN
        RAISE EXCEPTION 'edc_sync_log_operation_check_v2 constraint was not created';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'edc_sync_log'
          AND constraint_name = 'edc_sync_log_operation_check'
          AND constraint_type = 'CHECK'
    ) THEN
        RAISE EXCEPTION 'Old edc_sync_log_operation_check constraint was not dropped';
    END IF;

    RAISE NOTICE 'Migration 014 verified successfully: UNWEDGE operation added to edc_sync_log';
END $$;
