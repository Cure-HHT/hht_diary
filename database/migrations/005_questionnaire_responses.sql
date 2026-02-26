-- Migration 005: Questionnaire Responses
-- Date: 2026-02-24
-- Ticket: CUR-847
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p01067: NOSE HHT Questionnaire Content
--   REQ-p01068: HHT Quality of Life Questionnaire Content
--   REQ-p01065: Clinical Questionnaire System
--
-- Stores individual question responses when a patient submits a questionnaire.
-- Written by diary server after mobile app POSTs submission.
-- Read by portal server for investigator review and finalization.

-- =====================================================
-- QUESTIONNAIRE RESPONSES TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS questionnaire_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    questionnaire_instance_id UUID NOT NULL REFERENCES questionnaire_instances(id),
    question_id TEXT NOT NULL,
    value INTEGER NOT NULL CHECK (value >= 0 AND value <= 4),
    display_label TEXT NOT NULL,
    normalized_label TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (questionnaire_instance_id, question_id)
);

-- Index for looking up all responses for a questionnaire instance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_qr_instance_id
    ON questionnaire_responses(questionnaire_instance_id);

-- Enable RLS
ALTER TABLE questionnaire_responses ENABLE ROW LEVEL SECURITY;

-- Service role: full access (both portal and diary servers use service_role)
CREATE POLICY qr_service_all ON questionnaire_responses
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Investigators can view responses for patients at their assigned sites
CREATE POLICY qr_investigator_select ON questionnaire_responses
    FOR SELECT
    TO authenticated
    USING (
        current_user_role() = 'Investigator'
        AND questionnaire_instance_id IN (
            SELECT qi.id FROM questionnaire_instances qi
            WHERE qi.patient_id IN (
                SELECT p.patient_id FROM patients p
                WHERE p.site_id IN (
                    SELECT pusa.site_id FROM portal_user_site_access pusa
                    WHERE pusa.user_id = current_user_id()::uuid
                )
            )
        )
    );

GRANT ALL ON questionnaire_responses TO service_role;
GRANT SELECT ON questionnaire_responses TO authenticated;

-- Comments
COMMENT ON TABLE questionnaire_responses IS 'Individual question responses for submitted questionnaires. One row per question per instance.';
COMMENT ON COLUMN questionnaire_responses.questionnaire_instance_id IS 'FK to questionnaire_instances — the submitted questionnaire';
COMMENT ON COLUMN questionnaire_responses.question_id IS 'Question identifier from questionnaires.json (e.g., nose_physical_1, qol_q1)';
COMMENT ON COLUMN questionnaire_responses.value IS 'Numeric response value (0-4) for scoring';
COMMENT ON COLUMN questionnaire_responses.display_label IS 'Human-readable response label (e.g., "Moderate problem")';
COMMENT ON COLUMN questionnaire_responses.normalized_label IS 'Normalized label for cross-questionnaire comparison';

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    -- Verify table exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_name = 'questionnaire_responses') THEN
        RAISE EXCEPTION 'questionnaire_responses table was not created';
    END IF;

    -- Verify RLS is enabled
    IF NOT EXISTS (SELECT 1 FROM pg_tables
                   WHERE tablename = 'questionnaire_responses'
                   AND rowsecurity = true) THEN
        RAISE EXCEPTION 'RLS not enabled on questionnaire_responses';
    END IF;

    RAISE NOTICE 'Migration 005 verified successfully';
END $$;
