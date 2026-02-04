-- =====================================================
-- One-Time Migration Script for callisto4-dev
-- Date: 2026-02-04
-- Covers: All schema changes since Jan 28, 2026
-- =====================================================
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-CAL-p00073: Patient Status Definitions
--   REQ-CAL-p00079: Start Trial Workflow
--   REQ-CAL-p00064: Mark Patient as Not Participating
--   REQ-CAL-p00020: Patient Disconnection Workflow
--   REQ-CAL-p00021: Patient Reconnection Workflow
--   REQ-p70007: Linking Code Lifecycle Management
--   REQ-d00078: Linking Code Validation
--   REQ-d00079: Linking Code Pattern Matching
--   REQ-CAL-p00049: Mobile Linking Codes
--
-- Run this script ONCE on callisto4-dev to bring schema up to date
-- with main branch as of 2026-02-04.
--
-- Usage:
--   psql -h <host> -U <user> -d <database> -f callisto4-dev-2026-02-04.sql
--
-- Or via Supabase:
--   Run in SQL Editor

BEGIN;

-- =====================================================
-- 1. Add 'not_participating' to mobile_linking_status enum
-- =====================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumlabel = 'not_participating'
        AND enumtypid = 'mobile_linking_status'::regtype
    ) THEN
        ALTER TYPE mobile_linking_status ADD VALUE 'not_participating';
    END IF;
END $$;

-- =====================================================
-- 2. Add trial_started columns to patients table
-- =====================================================
-- Add trial_started boolean
ALTER TABLE patients ADD COLUMN IF NOT EXISTS trial_started BOOLEAN NOT NULL DEFAULT false;

-- Add trial_started_at timestamp
ALTER TABLE patients ADD COLUMN IF NOT EXISTS trial_started_at TIMESTAMPTZ;

-- Add trial_started_by text
ALTER TABLE patients ADD COLUMN IF NOT EXISTS trial_started_by TEXT;

-- Add comments for new columns
COMMENT ON COLUMN patients.trial_started IS 'Whether Start Trial workflow completed - enables EQ questionnaire and data sync (REQ-CAL-p00079)';
COMMENT ON COLUMN patients.trial_started_at IS 'Timestamp when trial was started';
COMMENT ON COLUMN patients.trial_started_by IS 'Portal user ID who started the trial';

-- =====================================================
-- 3. Add partial index for trial_started
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_patients_trial_started ON patients(trial_started)
  WHERE mobile_linking_status = 'connected' AND trial_started = false;

-- =====================================================
-- 4. Update admin_action_log action_type constraint
-- =====================================================
-- Drop existing constraint and add updated version with all action types
ALTER TABLE admin_action_log DROP CONSTRAINT IF EXISTS admin_action_log_action_type_check;
ALTER TABLE admin_action_log ADD CONSTRAINT admin_action_log_action_type_check
  CHECK (action_type IN (
    'ASSIGN_USER', 'ASSIGN_INVESTIGATOR', 'ASSIGN_ANALYST',
    'DATA_CORRECTION', 'ROLE_CHANGE', 'SYSTEM_CONFIG',
    'EMERGENCY_ACCESS', 'BULK_OPERATION',
    'GENERATE_LINKING_CODE', 'REVOKE_LINKING_CODE', 'DISCONNECT_PATIENT', 'RECONNECT_PATIENT',
    'MARK_NOT_PARTICIPATING', 'REACTIVATE_PATIENT', 'START_TRIAL'
  ));

-- =====================================================
-- 5. Create patient_linking_codes table (if not exists)
-- =====================================================
CREATE TABLE IF NOT EXISTS patient_linking_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id TEXT NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
    code TEXT NOT NULL UNIQUE,              -- Full 10-char code (2-char prefix + 8 random)
    code_hash TEXT NOT NULL,                -- SHA-256 hash for secure validation lookup
    generated_by UUID NOT NULL REFERENCES portal_users(id),
    generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,        -- 72-hour expiration
    used_at TIMESTAMPTZ,                    -- NULL until code is validated by mobile app
    used_by_user_id TEXT REFERENCES app_users(user_id), -- App user who validated the code
    used_by_app_uuid TEXT,                  -- App/device UUID that validated the code
    revoked_at TIMESTAMPTZ,                 -- If manually revoked before use
    revoked_by UUID REFERENCES portal_users(id),
    revoke_reason TEXT,
    ip_address INET,                        -- IP address of generator (audit)
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Create indexes (IF NOT EXISTS not supported for indexes, use DO block)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_patient_linking_patient') THEN
        CREATE INDEX idx_patient_linking_patient ON patient_linking_codes(patient_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_patient_linking_code_hash') THEN
        CREATE INDEX idx_patient_linking_code_hash ON patient_linking_codes(code_hash);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_patient_linking_user') THEN
        CREATE INDEX idx_patient_linking_user ON patient_linking_codes(used_by_user_id)
            WHERE used_by_user_id IS NOT NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_patient_linking_expires') THEN
        CREATE INDEX idx_patient_linking_expires ON patient_linking_codes(expires_at)
            WHERE used_at IS NULL AND revoked_at IS NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_patient_linking_cleanup') THEN
        CREATE INDEX idx_patient_linking_cleanup ON patient_linking_codes(generated_at)
            WHERE used_at IS NOT NULL OR revoked_at IS NOT NULL;
    END IF;
END $$;

-- Enable RLS
ALTER TABLE patient_linking_codes ENABLE ROW LEVEL SECURITY;

-- Add comments
COMMENT ON TABLE patient_linking_codes IS 'Time-limited linking codes for patient mobile app enrollment (REQ-p70007)';
COMMENT ON COLUMN patient_linking_codes.code IS '10-character code: 2-char sponsor prefix + 8-char random (REQ-d00079)';
COMMENT ON COLUMN patient_linking_codes.code_hash IS 'SHA-256 hash for secure validation from mobile app';
COMMENT ON COLUMN patient_linking_codes.expires_at IS '72-hour expiration from generation';
COMMENT ON COLUMN patient_linking_codes.used_at IS 'Timestamp when code was validated - codes are single-use';
COMMENT ON COLUMN patient_linking_codes.used_by_user_id IS 'App user (patient) who validated the code - establishes patient-app link';
COMMENT ON COLUMN patient_linking_codes.used_by_app_uuid IS 'Mobile app/device UUID that validated the code';
COMMENT ON COLUMN patient_linking_codes.revoked_at IS 'Manual revocation timestamp (e.g., patient disconnect)';

-- =====================================================
-- 6. Drop study_enrollments table if it exists
--    (replaced by patient_linking_codes)
-- =====================================================
DROP TABLE IF EXISTS study_enrollments CASCADE;

-- =====================================================
-- 7. Ensure updated_at trigger exists for patients
-- =====================================================
-- Create trigger if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'update_patients_updated_at'
    ) THEN
        CREATE TRIGGER update_patients_updated_at
        BEFORE UPDATE ON patients
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

COMMIT;

-- =====================================================
-- Verification Queries (run manually after migration)
-- =====================================================
-- Check enum values:
--   SELECT enumlabel FROM pg_enum WHERE enumtypid = 'mobile_linking_status'::regtype;
--
-- Check patients columns:
--   SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'patients';
--
-- Check admin_action_log constraint:
--   SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid = 'admin_action_log'::regclass;
--
-- Check patient_linking_codes exists:
--   SELECT COUNT(*) FROM patient_linking_codes;
