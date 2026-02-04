-- =====================================================
-- Migration: Add trial_started columns to patients table
-- Number: 001
-- Description: Adds trial_started flag, timestamp, and user tracking
--              for the Start Trial workflow (CUR-813)
-- Dependencies: Requires patients table (base schema)
-- Reference: spec/prd-callisto-patient-journey.md
-- =====================================================
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-CAL-p00073: Patient Status Definitions
--   REQ-CAL-p00079: Start Trial Workflow
--   REQ-CAL-p00022: Analyst Read-Only Site-Scoped Access
--
-- This migration adds:
-- 1. trial_started boolean column to track if Start Trial completed
-- 2. trial_started_at timestamp for audit trail
-- 3. trial_started_by text for user tracking
-- 4. START_TRIAL action type to admin_action_log constraint

-- Add trial_started columns to patients table
ALTER TABLE patients ADD COLUMN IF NOT EXISTS trial_started BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS trial_started_at TIMESTAMPTZ;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS trial_started_by TEXT;

-- Add column comments
COMMENT ON COLUMN patients.trial_started IS 'Whether Start Trial workflow completed - enables EQ questionnaire and data sync (REQ-CAL-p00079)';
COMMENT ON COLUMN patients.trial_started_at IS 'Timestamp when trial was started';
COMMENT ON COLUMN patients.trial_started_by IS 'Portal user ID who started the trial';

-- Update admin_action_log constraint to include START_TRIAL
-- First drop the existing constraint, then add updated version
ALTER TABLE admin_action_log DROP CONSTRAINT IF EXISTS admin_action_log_action_type_check;
ALTER TABLE admin_action_log ADD CONSTRAINT admin_action_log_action_type_check
  CHECK (action_type IN (
    'ASSIGN_USER', 'ASSIGN_INVESTIGATOR', 'ASSIGN_ANALYST',
    'DATA_CORRECTION', 'ROLE_CHANGE', 'SYSTEM_CONFIG',
    'EMERGENCY_ACCESS', 'BULK_OPERATION',
    'GENERATE_LINKING_CODE', 'REVOKE_LINKING_CODE', 'DISCONNECT_PATIENT', 'RECONNECT_PATIENT',
    'MARK_NOT_PARTICIPATING', 'REACTIVATE_PATIENT', 'START_TRIAL'
  ));

-- Add index for filtering connected patients awaiting trial start
CREATE INDEX IF NOT EXISTS idx_patients_trial_started ON patients(trial_started)
  WHERE mobile_linking_status = 'connected' AND trial_started = false;
