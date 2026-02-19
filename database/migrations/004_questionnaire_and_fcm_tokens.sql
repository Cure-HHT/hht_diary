-- =====================================================
-- Migration: Add questionnaire_instances and patient_fcm_tokens tables
-- Number: 004
-- Date: 2026-02-15
-- Description: Creates questionnaire lifecycle tracking and FCM push
--   notification token storage. Adds PostgreSQL enums for questionnaire
--   type and status. Includes RLS policies, indexes, and triggers.
--   Idempotent — safe to run on a database where schema.sql already
--   deployed these objects.
--   (Linear: CUR-825)
-- Dependencies: Requires base schema (001), patients table, portal_users
--   table, update_updated_at_column() trigger function
-- Reference: database/schema.sql, database/rls_policies.sql,
--   spec/prd-questionnaires.md
-- =====================================================

-- =====================================================
-- ENUMS (conditional — pg has no CREATE TYPE IF NOT EXISTS)
-- =====================================================

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'questionnaire_type') THEN
        CREATE TYPE questionnaire_type AS ENUM ('nose_hht', 'qol', 'eq');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'questionnaire_status') THEN
        CREATE TYPE questionnaire_status AS ENUM ('not_sent', 'sent', 'in_progress', 'ready_to_review', 'finalized');
    END IF;
END $$;

-- =====================================================
-- QUESTIONNAIRE INSTANCES
-- =====================================================

CREATE TABLE IF NOT EXISTS questionnaire_instances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id TEXT NOT NULL REFERENCES patients(patient_id),
    questionnaire_type questionnaire_type NOT NULL,
    status questionnaire_status NOT NULL DEFAULT 'not_sent',
    study_event TEXT CHECK (char_length(study_event) <= 32),
    version TEXT NOT NULL,
    sent_by UUID REFERENCES portal_users(id),
    sent_at TIMESTAMPTZ,
    submitted_at TIMESTAMPTZ,
    finalized_by UUID REFERENCES portal_users(id),
    finalized_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    delete_reason TEXT CHECK (char_length(delete_reason) <= 25),
    deleted_by UUID REFERENCES portal_users(id),
    score INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_qi_patient_id ON questionnaire_instances(patient_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_qi_patient_type ON questionnaire_instances(patient_id, questionnaire_type)
    WHERE deleted_at IS NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_qi_status ON questionnaire_instances(status)
    WHERE deleted_at IS NULL;

ALTER TABLE questionnaire_instances ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_questionnaire_instances_updated_at') THEN
        CREATE TRIGGER update_questionnaire_instances_updated_at BEFORE UPDATE ON questionnaire_instances
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- RLS: service_role full access (both portal and diary servers)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'qi_service_all' AND tablename = 'questionnaire_instances') THEN
        CREATE POLICY qi_service_all ON questionnaire_instances
            FOR ALL TO service_role
            USING (true) WITH CHECK (true);
    END IF;
END $$;

-- RLS: Investigators can view questionnaires at their assigned sites
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'qi_investigator_select' AND tablename = 'questionnaire_instances') THEN
        CREATE POLICY qi_investigator_select ON questionnaire_instances
            FOR SELECT TO authenticated
            USING (
                current_user_role() = 'Investigator'
                AND patient_id IN (
                    SELECT p.patient_id FROM patients p
                    WHERE p.site_id IN (
                        SELECT pusa.site_id FROM portal_user_site_access pusa
                        WHERE pusa.user_id = current_user_id()::uuid
                    )
                )
            );
    END IF;
END $$;

GRANT ALL ON questionnaire_instances TO service_role;
GRANT SELECT ON questionnaire_instances TO authenticated;

COMMENT ON TABLE questionnaire_instances IS 'Questionnaire lifecycle tracking per REQ-CAL-p00023';

-- =====================================================
-- PATIENT FCM TOKENS
-- =====================================================

CREATE TABLE IF NOT EXISTS patient_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id TEXT NOT NULL REFERENCES patients(patient_id),
    fcm_token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
    app_version TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_active BOOLEAN NOT NULL DEFAULT true
);

-- One active token per patient per platform (upsert pattern)
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_fcm_patient_platform_active
    ON patient_fcm_tokens(patient_id, platform)
    WHERE is_active = true;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fcm_patient_active ON patient_fcm_tokens(patient_id)
    WHERE is_active = true;

ALTER TABLE patient_fcm_tokens ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_patient_fcm_tokens_updated_at') THEN
        CREATE TRIGGER update_patient_fcm_tokens_updated_at BEFORE UPDATE ON patient_fcm_tokens
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- RLS: service_role full access
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'fcm_tokens_service_all' AND tablename = 'patient_fcm_tokens') THEN
        CREATE POLICY fcm_tokens_service_all ON patient_fcm_tokens
            FOR ALL TO service_role
            USING (true) WITH CHECK (true);
    END IF;
END $$;

GRANT ALL ON patient_fcm_tokens TO service_role;

COMMENT ON TABLE patient_fcm_tokens IS 'FCM registration tokens for push notifications. Written by diary server, read by portal server.';

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'questionnaire_instances') THEN
        RAISE EXCEPTION 'questionnaire_instances table was not created';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patient_fcm_tokens') THEN
        RAISE EXCEPTION 'patient_fcm_tokens table was not created';
    END IF;
    RAISE NOTICE 'Migration 004 complete: questionnaire_instances and patient_fcm_tokens created';
END $$;
