-- IMPLEMENTS REQUIREMENTS:
--   REQ-d00005: Sponsor Configuration Detection Implementation
--   REQ-p00008: User Account Management
--
-- Test fixtures for integration tests
-- Run after init.sql to set up test data
--
-- Usage:
--   psql -h localhost -U postgres -d sponsor_portal -f init_test.sql

\echo 'Setting up test fixtures...'

-- =====================================================
-- Test Site
-- =====================================================

INSERT INTO sites (site_id, site_name, site_number, is_active)
VALUES ('DEFAULT', 'Default Test Site', 'TEST-000', true)
ON CONFLICT (site_id) DO UPDATE SET is_active = true;

INSERT INTO sites (site_id, site_name, site_number, is_active)
VALUES ('TEST-SITE-001', 'Test Site 001', 'TEST-001', true)
ON CONFLICT (site_id) DO UPDATE SET is_active = true;

-- =====================================================
-- Test App User for sync tests
-- Uses a well-known auth_code that tests can reference
-- =====================================================

-- Clean up any existing test user first
DELETE FROM record_audit WHERE created_by IN (
    SELECT user_id FROM app_users WHERE auth_code LIKE 'test-sync-%'
);
DELETE FROM study_enrollments WHERE user_id IN (
    SELECT user_id FROM app_users WHERE auth_code LIKE 'test-sync-%'
);
DELETE FROM user_site_assignments WHERE patient_id IN (
    SELECT user_id FROM app_users WHERE auth_code LIKE 'test-sync-%'
);
DELETE FROM app_users WHERE auth_code LIKE 'test-sync-%';

-- Create test app user with predictable IDs
INSERT INTO app_users (user_id, auth_code, created_at, last_active_at)
VALUES (
    '11111111-1111-1111-1111-111111111111',
    'test-sync-user-auth-code',
    now(),
    now()
);

-- Enroll test user at DEFAULT site
INSERT INTO user_site_assignments (
    patient_id,
    site_id,
    study_patient_id,
    enrollment_status
) VALUES (
    '11111111-1111-1111-1111-111111111111',
    'DEFAULT',
    'TEST-PATIENT-001',
    'ACTIVE'
);

-- Also create study_enrollment for the user
INSERT INTO study_enrollments (
    user_id,
    patient_id,
    site_id,
    sponsor_id,
    enrollment_code,
    status
) VALUES (
    '11111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    'DEFAULT',
    'TEST',
    'CUREHHT9',
    'ACTIVE'
) ON CONFLICT DO NOTHING;

-- =====================================================
-- Sponsor Role Mappings for testing
-- =====================================================

-- Test role mappings for callisto sponsor
INSERT INTO sponsor_role_mapping (sponsor_id, sponsor_role_name, mapped_role)
VALUES
    ('callisto', 'Principal Investigator', 'Investigator'),
    ('callisto', 'Sub-Investigator', 'Investigator'),
    ('callisto', 'Sponsor Admin', 'Administrator'),
    ('callisto', 'Site Coordinator', 'Auditor')
ON CONFLICT (sponsor_id, sponsor_role_name) DO NOTHING;

-- Test role mappings for curehht sponsor
INSERT INTO sponsor_role_mapping (sponsor_id, sponsor_role_name, mapped_role)
VALUES
    ('curehht', 'Lead Physician', 'Investigator'),
    ('curehht', 'Research Nurse', 'Auditor'),
    ('curehht', 'Study Admin', 'Administrator')
ON CONFLICT (sponsor_id, sponsor_role_name) DO NOTHING;

\echo 'Test fixtures created successfully!'
\echo ''
\echo 'Test users available:'
\echo '  - App User: 11111111-1111-1111-1111-111111111111 (auth_code: test-sync-user-auth-code)'
\echo '  - Site: DEFAULT (Test Site)'
\echo 'Role mappings: callisto (4 roles), curehht (3 roles)'
\echo ''
