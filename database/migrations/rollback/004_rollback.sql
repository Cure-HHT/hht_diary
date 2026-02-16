-- =====================================================
-- Rollback: Add questionnaire_instances and patient_fcm_tokens tables
-- Number: 004
-- Description: Removes questionnaire_instances and patient_fcm_tokens
--   tables, their enums, RLS policies, indexes, triggers, and grants.
-- =====================================================

BEGIN;

-- =====================================================
-- DROP RLS POLICIES
-- =====================================================

DROP POLICY IF EXISTS qi_service_all ON questionnaire_instances;
DROP POLICY IF EXISTS qi_investigator_select ON questionnaire_instances;
DROP POLICY IF EXISTS fcm_tokens_service_all ON patient_fcm_tokens;

-- =====================================================
-- REVOKE GRANTS
-- =====================================================

REVOKE ALL ON questionnaire_instances FROM service_role;
REVOKE ALL ON questionnaire_instances FROM authenticated;
REVOKE ALL ON patient_fcm_tokens FROM service_role;

-- =====================================================
-- DROP TRIGGERS
-- =====================================================

DROP TRIGGER IF EXISTS update_questionnaire_instances_updated_at ON questionnaire_instances;
DROP TRIGGER IF EXISTS update_patient_fcm_tokens_updated_at ON patient_fcm_tokens;

-- =====================================================
-- DROP TABLES (cascades indexes)
-- =====================================================

DROP TABLE IF EXISTS patient_fcm_tokens;
DROP TABLE IF EXISTS questionnaire_instances;

-- =====================================================
-- DROP ENUMS
-- =====================================================

DROP TYPE IF EXISTS questionnaire_status;
DROP TYPE IF EXISTS questionnaire_type;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'questionnaire_instances') THEN
        RAISE EXCEPTION 'Rollback failed: questionnaire_instances still exists';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patient_fcm_tokens') THEN
        RAISE EXCEPTION 'Rollback failed: patient_fcm_tokens still exists';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'questionnaire_type') THEN
        RAISE EXCEPTION 'Rollback failed: questionnaire_type enum still exists';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'questionnaire_status') THEN
        RAISE EXCEPTION 'Rollback failed: questionnaire_status enum still exists';
    END IF;
    RAISE NOTICE 'Rollback 004 completed successfully';
END $$;

COMMIT;
