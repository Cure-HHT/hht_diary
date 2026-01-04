-- =====================================================
-- Rollback: Remove Mobile App User Tables
-- Number: 010
-- Description: Removes app_users and study_enrollments tables
-- =====================================================

-- Revoke permissions
REVOKE SELECT, INSERT, UPDATE ON app_users FROM service_role;
REVOKE SELECT, INSERT, UPDATE ON study_enrollments FROM service_role;
REVOKE USAGE, SELECT ON SEQUENCE study_enrollments_enrollment_id_seq FROM service_role;

-- Drop policies
DROP POLICY IF EXISTS app_users_service ON app_users;
DROP POLICY IF EXISTS study_enrollments_service ON study_enrollments;

-- Drop tables (CASCADE handles foreign keys and indexes)
DROP TABLE IF EXISTS study_enrollments CASCADE;
DROP TABLE IF EXISTS app_users CASCADE;

-- Drop trigger function
DROP FUNCTION IF EXISTS update_app_users_updated_at();
