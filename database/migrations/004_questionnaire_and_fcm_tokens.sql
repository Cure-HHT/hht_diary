-- IMPLEMENTS REQUIREMENTS:
--   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
--   REQ-CAL-p00047: Hard-Coded Questionnaires
--   REQ-CAL-p00066: Status Change Reason Field
--   REQ-CAL-p00080: Questionnaire Study Event Association
--   REQ-CAL-p00082: Patient Alert Delivery
--   REQ-p00049: Ancillary Platform Services (push notifications)
--
-- Migration: Add questionnaire_instances and patient_fcm_tokens tables
-- Date: 2026-02-15
-- Ticket: CUR-825

-- =====================================================
-- ENUMS
-- =====================================================

CREATE TYPE questionnaire_type AS ENUM ('nose_hht', 'qol', 'eq');
CREATE TYPE questionnaire_status AS ENUM ('not_sent', 'sent', 'in_progress', 'ready_to_review', 'finalized');

-- =====================================================
-- QUESTIONNAIRE INSTANCES
-- =====================================================

CREATE TABLE questionnaire_instances (
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

CREATE INDEX CONCURRENTLY idx_qi_patient_id ON questionnaire_instances(patient_id);
CREATE INDEX CONCURRENTLY idx_qi_patient_type ON questionnaire_instances(patient_id, questionnaire_type)
    WHERE deleted_at IS NULL;
CREATE INDEX CONCURRENTLY idx_qi_status ON questionnaire_instances(status)
    WHERE deleted_at IS NULL;

ALTER TABLE questionnaire_instances ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER update_questionnaire_instances_updated_at BEFORE UPDATE ON questionnaire_instances
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS: service_role full access (both portal and diary servers)
CREATE POLICY qi_service_all ON questionnaire_instances
    FOR ALL TO service_role
    USING (true) WITH CHECK (true);

-- RLS: Investigators can view questionnaires at their assigned sites
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

GRANT ALL ON questionnaire_instances TO service_role;
GRANT SELECT ON questionnaire_instances TO authenticated;

COMMENT ON TABLE questionnaire_instances IS 'Questionnaire lifecycle tracking per REQ-CAL-p00023';

-- =====================================================
-- PATIENT FCM TOKENS
-- =====================================================

CREATE TABLE patient_fcm_tokens (
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
CREATE UNIQUE INDEX CONCURRENTLY idx_fcm_patient_platform_active
    ON patient_fcm_tokens(patient_id, platform)
    WHERE is_active = true;

CREATE INDEX CONCURRENTLY idx_fcm_patient_active ON patient_fcm_tokens(patient_id)
    WHERE is_active = true;

ALTER TABLE patient_fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER update_patient_fcm_tokens_updated_at BEFORE UPDATE ON patient_fcm_tokens
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS: service_role full access
CREATE POLICY fcm_tokens_service_all ON patient_fcm_tokens
    FOR ALL TO service_role
    USING (true) WITH CHECK (true);

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
