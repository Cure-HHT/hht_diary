-- =====================================================
-- Mobile App User Tables
-- =====================================================
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00008: User Account Management
--   REQ-d00005: Sponsor Configuration Detection Implementation
--
-- Tables for mobile app authentication (separate from portal users)
-- Used by diary server for app user management
--

-- =====================================================
-- APP USERS TABLE
-- =====================================================
-- Mobile app user accounts (username/password or enrollment code)

CREATE TABLE IF NOT EXISTS app_users (
    user_id TEXT PRIMARY KEY,
    username TEXT UNIQUE,
    password_hash TEXT,
    auth_code TEXT NOT NULL UNIQUE,
    enrollment_code TEXT UNIQUE,
    app_uuid TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    last_active_at TIMESTAMPTZ DEFAULT now(),
    is_active BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{}'::jsonb,
    -- Require either username+password or enrollment code
    CONSTRAINT valid_auth CHECK (
        (username IS NOT NULL AND password_hash IS NOT NULL) OR
        enrollment_code IS NOT NULL
    )
);

COMMENT ON TABLE app_users IS 'Mobile app user accounts for diary app';
COMMENT ON COLUMN app_users.auth_code IS 'Random code used in JWT for user lookup';
COMMENT ON COLUMN app_users.enrollment_code IS 'One-time enrollment code (e.g., CUREHHT1)';
COMMENT ON COLUMN app_users.app_uuid IS 'Device/app instance identifier';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_app_users_username ON app_users(username);
CREATE INDEX IF NOT EXISTS idx_app_users_auth_code ON app_users(auth_code);
CREATE INDEX IF NOT EXISTS idx_app_users_enrollment_code ON app_users(enrollment_code);

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
-- USER RECORDS TABLE
-- =====================================================
-- Append-only diary records for mobile app users

CREATE TABLE IF NOT EXISTS user_records (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    record_id TEXT NOT NULL,
    data JSONB NOT NULL,
    synced_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, record_id)
);

COMMENT ON TABLE user_records IS 'Append-only diary records from mobile app';
COMMENT ON COLUMN user_records.record_id IS 'Client-generated record ID';
COMMENT ON COLUMN user_records.data IS 'Full record data as JSON';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_records_user_id ON user_records(user_id);
CREATE INDEX IF NOT EXISTS idx_user_records_synced_at ON user_records(synced_at DESC);

-- =====================================================
-- ROW LEVEL SECURITY
-- =====================================================

ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_records ENABLE ROW LEVEL SECURITY;

-- Service role has full access (for backend server)
CREATE POLICY app_users_service ON app_users
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY user_records_service ON user_records
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON app_users TO service_role;
GRANT SELECT, INSERT ON user_records TO service_role;
GRANT USAGE, SELECT ON SEQUENCE user_records_id_seq TO service_role;
