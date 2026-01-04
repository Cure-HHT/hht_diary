-- =====================================================
-- Migration: Add Mobile App User Tables
-- Number: 010
-- Description: Creates app_users and study_enrollments tables for mobile app auth
-- Dependencies: Requires base schema (001), sites table
-- Reference: spec/prd-security-RBAC.md
-- =====================================================
--
-- Tables for mobile app authentication and study enrollment
-- Sync goes to record_audit (event store), not separate tables
--

-- =====================================================
-- APP USERS TABLE
-- =====================================================
-- Mobile app user accounts - any user can use the app
-- Study enrollment is separate (see study_enrollments)

CREATE TABLE IF NOT EXISTS app_users (
    user_id TEXT PRIMARY KEY,
    username TEXT UNIQUE,
    password_hash TEXT,
    auth_code TEXT NOT NULL UNIQUE,
    app_uuid TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    last_active_at TIMESTAMPTZ DEFAULT now(),
    is_active BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE app_users IS 'Mobile app user accounts - any user can use the app to track nosebleeds';
COMMENT ON COLUMN app_users.auth_code IS 'Random code used in JWT for user lookup';
COMMENT ON COLUMN app_users.app_uuid IS 'Device/app instance identifier';
COMMENT ON COLUMN app_users.username IS 'Optional username for registered users';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_app_users_username ON app_users(username);
CREATE INDEX IF NOT EXISTS idx_app_users_auth_code ON app_users(auth_code);

-- Updated at trigger
CREATE OR REPLACE FUNCTION update_app_users_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_app_users_updated_at ON app_users;
CREATE TRIGGER update_app_users_updated_at
    BEFORE UPDATE ON app_users
    FOR EACH ROW
    EXECUTE FUNCTION update_app_users_updated_at();

-- =====================================================
-- STUDY ENROLLMENTS TABLE
-- =====================================================
-- Links app users to clinical studies via enrollment code
-- User can enroll in multiple studies (different sponsors)

CREATE TABLE IF NOT EXISTS study_enrollments (
    enrollment_id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    enrollment_code TEXT NOT NULL UNIQUE,
    site_id TEXT REFERENCES sites(site_id),
    patient_id TEXT,  -- From sponsor's EDC, may be assigned later
    sponsor_id TEXT,  -- Identifies which sponsor/study
    enrolled_at TIMESTAMPTZ DEFAULT now(),
    status TEXT DEFAULT 'ACTIVE' CHECK (status IN ('PENDING', 'ACTIVE', 'COMPLETED', 'WITHDRAWN')),
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE study_enrollments IS 'Links app users to clinical studies via enrollment code';
COMMENT ON COLUMN study_enrollments.enrollment_code IS 'One-time code from study coordinator (e.g., CUREHHT1)';
COMMENT ON COLUMN study_enrollments.patient_id IS 'De-identified patient ID from sponsor EDC (assigned after enrollment)';
COMMENT ON COLUMN study_enrollments.site_id IS 'Clinical trial site where patient is enrolled';
COMMENT ON COLUMN study_enrollments.sponsor_id IS 'Sponsor/study identifier';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_study_enrollments_user_id ON study_enrollments(user_id);
CREATE INDEX IF NOT EXISTS idx_study_enrollments_enrollment_code ON study_enrollments(enrollment_code);
CREATE INDEX IF NOT EXISTS idx_study_enrollments_patient_id ON study_enrollments(patient_id);
CREATE INDEX IF NOT EXISTS idx_study_enrollments_site_id ON study_enrollments(site_id);

-- =====================================================
-- ROW LEVEL SECURITY
-- =====================================================

ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_enrollments ENABLE ROW LEVEL SECURITY;

-- Service role has full access (for backend server)
CREATE POLICY app_users_service ON app_users
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY study_enrollments_service ON study_enrollments
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON app_users TO service_role;
GRANT SELECT, INSERT, UPDATE ON study_enrollments TO service_role;
GRANT USAGE, SELECT ON SEQUENCE study_enrollments_enrollment_id_seq TO service_role;
