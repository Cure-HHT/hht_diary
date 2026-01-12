-- =====================================================
-- Database Roles and Permissions
-- =====================================================
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00005: Role-Based Access Control
--   REQ-p00014: Least Privilege Access
--   REQ-o00007: Role-Based Permission Configuration
--
-- ROLE DESIGN:
--   Users can have MULTIPLE application roles assigned
--   Users select ONE active role at login (carried in JWT)
--   Each transaction validates active role is in user's allowed roles
--
-- =====================================================

-- =====================================================
-- APPLICATION ROLE DEFINITIONS
-- =====================================================
-- These are the valid application roles per prd-security-RBAC.md
-- Note: These are NOT PostgreSQL roles - they are application-level roles
-- stored in user data and JWT claims

-- Role type for validation
CREATE TYPE app_role AS ENUM (
    'PATIENT',       -- Read/write own data only
    'INVESTIGATOR',  -- Site-scoped read/write, enroll/de-enroll patients
    'SPONSOR',       -- De-identified only, user management, oversight
    'AUDITOR',       -- Read-only across study, compliance monitoring
    'ANALYST',       -- Site-scoped read, de-identified datasets
    'ADMIN',         -- User/role/config management, no routine PHI
    'DEV_ADMIN'      -- Infrastructure ops, break-glass management
);

COMMENT ON TYPE app_role IS 'Application roles per prd-security-RBAC.md - users can have multiple, one active at a time';

-- =====================================================
-- RLS (ROW-LEVEL SECURITY) ROLES
-- =====================================================
-- These ARE PostgreSQL roles used by RLS policies to control access levels
-- In managed PostgreSQL (Cloud SQL, Supabase), these may already exist

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN;
        COMMENT ON ROLE anon IS 'Role for unauthenticated access';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN;
        COMMENT ON ROLE authenticated IS 'Role for authenticated users';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN;
        COMMENT ON ROLE service_role IS 'Role for backend services';
    END IF;
END
$$;

-- Grant schema access to RLS roles
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- Grant RLS roles to app_user (for local dev container)
-- This allows app_user to SET ROLE to these roles for testing
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_user') THEN
        GRANT anon, authenticated, service_role TO app_user;
    END IF;
END
$$;

-- =====================================================
-- USER PROFILES
-- =====================================================
-- Core user identity (linked to auth provider)
-- Note: role is NOT stored here - see user_roles table

CREATE TABLE IF NOT EXISTS user_profiles (
    user_id TEXT PRIMARY KEY,  -- References auth provider user ID
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    last_login_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    two_factor_enabled BOOLEAN DEFAULT false,
    must_change_password BOOLEAN DEFAULT false
);

COMMENT ON TABLE user_profiles IS 'User profiles - roles stored in user_roles table';
COMMENT ON COLUMN user_profiles.two_factor_enabled IS '2FA requirement for FDA compliance';

-- =====================================================
-- USER ROLES (Junction Table)
-- =====================================================
-- Users can have MULTIPLE roles assigned
-- The active role is selected at login and carried in JWT

CREATE TABLE IF NOT EXISTS user_roles (
    user_id TEXT NOT NULL REFERENCES user_profiles(user_id) ON DELETE CASCADE,
    role app_role NOT NULL,
    granted_at TIMESTAMPTZ DEFAULT now(),
    granted_by TEXT NOT NULL,  -- User ID of admin who granted the role
    is_active BOOLEAN DEFAULT true,  -- Can be disabled without removing
    notes TEXT,  -- Reason for granting, special conditions, etc.
    PRIMARY KEY (user_id, role)
);

COMMENT ON TABLE user_roles IS 'Junction table for user role assignments - users can have multiple roles';
COMMENT ON COLUMN user_roles.is_active IS 'Role can be temporarily disabled without removing';
COMMENT ON COLUMN user_roles.granted_by IS 'Admin who granted this role - for audit trail';

-- Index for common lookups
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role);

-- =====================================================
-- JWT CLAIM FUNCTIONS
-- =====================================================
-- Functions to access JWT claims set by the application

-- Drop existing functions to ensure clean replacement (signature changes require drop)
-- Use CASCADE in case other functions depend on these
DROP FUNCTION IF EXISTS current_user_id() CASCADE;
DROP FUNCTION IF EXISTS current_user_role() CASCADE;
DROP FUNCTION IF EXISTS current_user_allowed_roles() CASCADE;

-- Get current user ID from JWT claims
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS TEXT AS $$
BEGIN
    RETURN COALESCE(
        current_setting('request.jwt.claims', true)::json->>'sub',
        current_setting('app.user_id', true)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION current_user_id() IS 'Get current user ID from JWT claims or app settings';

-- Get current ACTIVE role from JWT claims
-- This is the role the user selected at login
CREATE OR REPLACE FUNCTION current_user_role()
RETURNS TEXT AS $$
BEGIN
    RETURN COALESCE(
        current_setting('request.jwt.claims', true)::json->>'active_role',
        current_setting('app.role', true)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION current_user_role() IS 'Get active role from JWT - the role user selected at login';

-- Get ALL allowed roles for current user from JWT claims
-- This is used to validate the active role
CREATE OR REPLACE FUNCTION current_user_allowed_roles()
RETURNS TEXT[] AS $$
DECLARE
    roles_json JSON;
BEGIN
    roles_json := current_setting('request.jwt.claims', true)::json->'allowed_roles';
    IF roles_json IS NULL THEN
        -- Fallback to app settings for testing
        RETURN string_to_array(COALESCE(current_setting('app.allowed_roles', true), ''), ',');
    END IF;
    RETURN ARRAY(SELECT json_array_elements_text(roles_json));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION current_user_allowed_roles() IS 'Get all allowed roles from JWT claims';

-- =====================================================
-- ROLE VALIDATION FUNCTIONS
-- =====================================================

-- Validate that active role is in user's allowed roles
-- CRITICAL: This must be called at the start of every transaction
CREATE OR REPLACE FUNCTION validate_active_role()
RETURNS BOOLEAN AS $$
DECLARE
    active_role TEXT;
    allowed_roles TEXT[];
BEGIN
    active_role := current_user_role();
    allowed_roles := current_user_allowed_roles();

    -- No role context means anonymous access
    IF active_role IS NULL OR active_role = '' THEN
        RETURN true;
    END IF;

    -- Validate active role is in allowed roles
    IF active_role = ANY(allowed_roles) THEN
        RETURN true;
    END IF;

    -- Role mismatch - potential security issue
    RAISE EXCEPTION 'Active role % not in allowed roles %', active_role, allowed_roles;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION validate_active_role() IS 'Validate active role is in user allowed roles - call at transaction start';

-- Check if current user has a specific role (from their allowed roles)
CREATE OR REPLACE FUNCTION has_role(required_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN current_user_role() = required_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION has_role(TEXT) IS 'Check if current ACTIVE role matches required role';

-- Check if current user has any of the specified roles
CREATE OR REPLACE FUNCTION has_any_role(required_roles TEXT[])
RETURNS BOOLEAN AS $$
BEGIN
    RETURN current_user_role() = ANY(required_roles);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION has_any_role(TEXT[]) IS 'Check if current active role is any of the required roles';

-- Check if user has a role in their allowed_roles (not necessarily active)
CREATE OR REPLACE FUNCTION user_can_assume_role(check_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN check_role = ANY(current_user_allowed_roles());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION user_can_assume_role(TEXT) IS 'Check if user has the specified role in their allowed roles';

-- =====================================================
-- ROLE ASSIGNMENT FUNCTIONS
-- =====================================================

-- Get all active roles for a specific user (for building JWT claims)
CREATE OR REPLACE FUNCTION get_user_roles(p_user_id TEXT)
RETURNS app_role[] AS $$
BEGIN
    RETURN ARRAY(
        SELECT role FROM user_roles
        WHERE user_id = p_user_id AND is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION get_user_roles(TEXT) IS 'Get all active roles for a user - used when building JWT at login';

-- Grant a role to a user (admin function)
CREATE OR REPLACE FUNCTION grant_user_role(
    p_user_id TEXT,
    p_role app_role,
    p_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Only ADMIN or DEV_ADMIN can grant roles
    IF NOT has_any_role(ARRAY['ADMIN', 'DEV_ADMIN']) THEN
        RAISE EXCEPTION 'Only ADMIN or DEV_ADMIN can grant roles';
    END IF;

    INSERT INTO user_roles (user_id, role, granted_by, notes)
    VALUES (p_user_id, p_role, current_user_id(), p_notes)
    ON CONFLICT (user_id, role) DO UPDATE SET
        is_active = true,
        granted_by = current_user_id(),
        granted_at = now(),
        notes = COALESCE(p_notes, user_roles.notes);

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION grant_user_role(TEXT, app_role, TEXT) IS 'Grant a role to a user - requires ADMIN or DEV_ADMIN';

-- Revoke a role from a user (admin function)
CREATE OR REPLACE FUNCTION revoke_user_role(
    p_user_id TEXT,
    p_role app_role,
    p_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Only ADMIN or DEV_ADMIN can revoke roles
    IF NOT has_any_role(ARRAY['ADMIN', 'DEV_ADMIN']) THEN
        RAISE EXCEPTION 'Only ADMIN or DEV_ADMIN can revoke roles';
    END IF;

    -- Soft delete - set is_active to false
    UPDATE user_roles
    SET is_active = false,
        notes = COALESCE(p_notes, notes) || ' [Revoked by ' || current_user_id() || ' at ' || now()::text || ']'
    WHERE user_id = p_user_id AND role = p_role;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION revoke_user_role(TEXT, app_role, TEXT) IS 'Revoke a role from a user - requires ADMIN or DEV_ADMIN';

-- =====================================================
-- ROLE CHANGE AUDIT LOG
-- =====================================================
-- Track all role changes for compliance

CREATE TABLE IF NOT EXISTS role_change_log (
    change_id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    action TEXT NOT NULL CHECK (action IN ('GRANT', 'REVOKE', 'ENABLE', 'DISABLE')),
    role app_role NOT NULL,
    changed_by TEXT NOT NULL,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE role_change_log IS 'Audit trail for all role changes';

-- Trigger to log role changes
CREATE OR REPLACE FUNCTION log_role_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO role_change_log (user_id, action, role, changed_by, reason)
        VALUES (NEW.user_id, 'GRANT', NEW.role, NEW.granted_by, NEW.notes);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.is_active = true AND NEW.is_active = false THEN
            INSERT INTO role_change_log (user_id, action, role, changed_by, reason)
            VALUES (NEW.user_id, 'DISABLE', NEW.role, current_user_id(), NEW.notes);
        ELSIF OLD.is_active = false AND NEW.is_active = true THEN
            INSERT INTO role_change_log (user_id, action, role, changed_by, reason)
            VALUES (NEW.user_id, 'ENABLE', NEW.role, current_user_id(), NEW.notes);
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO role_change_log (user_id, action, role, changed_by, reason)
        VALUES (OLD.user_id, 'REVOKE', OLD.role, current_user_id(), 'Hard delete');
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_log_role_change ON user_roles;
CREATE TRIGGER trg_log_role_change
    AFTER INSERT OR UPDATE OR DELETE ON user_roles
    FOR EACH ROW
    EXECUTE FUNCTION log_role_change();

-- =====================================================
-- RLS POLICIES FOR ROLE TABLES
-- =====================================================

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_change_log ENABLE ROW LEVEL SECURITY;

-- User Profiles: Users can view their own profile
DROP POLICY IF EXISTS profile_select_own ON user_profiles;
CREATE POLICY profile_select_own ON user_profiles
    FOR SELECT TO authenticated
    USING (user_id = current_user_id());

-- User Profiles: Users can update their own non-sensitive fields
DROP POLICY IF EXISTS profile_update_own ON user_profiles;
CREATE POLICY profile_update_own ON user_profiles
    FOR UPDATE TO authenticated
    USING (user_id = current_user_id())
    WITH CHECK (user_id = current_user_id());

-- User Profiles: Admins can view all profiles
DROP POLICY IF EXISTS profile_admin_select ON user_profiles;
CREATE POLICY profile_admin_select ON user_profiles
    FOR SELECT TO authenticated
    USING (has_any_role(ARRAY['ADMIN', 'DEV_ADMIN', 'SPONSOR']));

-- User Profiles: Admins can manage profiles
DROP POLICY IF EXISTS profile_admin_all ON user_profiles;
CREATE POLICY profile_admin_all ON user_profiles
    FOR ALL TO authenticated
    USING (has_any_role(ARRAY['ADMIN', 'DEV_ADMIN']))
    WITH CHECK (has_any_role(ARRAY['ADMIN', 'DEV_ADMIN']));

-- User Roles: Users can view their own roles
DROP POLICY IF EXISTS roles_select_own ON user_roles;
CREATE POLICY roles_select_own ON user_roles
    FOR SELECT TO authenticated
    USING (user_id = current_user_id());

-- User Roles: Admins can view all roles
DROP POLICY IF EXISTS roles_admin_select ON user_roles;
CREATE POLICY roles_admin_select ON user_roles
    FOR SELECT TO authenticated
    USING (has_any_role(ARRAY['ADMIN', 'DEV_ADMIN', 'SPONSOR']));

-- User Roles: Admins can manage roles
DROP POLICY IF EXISTS roles_admin_all ON user_roles;
CREATE POLICY roles_admin_all ON user_roles
    FOR ALL TO authenticated
    USING (has_any_role(ARRAY['ADMIN', 'DEV_ADMIN']))
    WITH CHECK (has_any_role(ARRAY['ADMIN', 'DEV_ADMIN']));

-- Role Change Log: Admins can view
DROP POLICY IF EXISTS role_log_admin_select ON role_change_log;
CREATE POLICY role_log_admin_select ON role_change_log
    FOR SELECT TO authenticated
    USING (has_any_role(ARRAY['ADMIN', 'DEV_ADMIN', 'AUDITOR']));

-- Service role has full access
DROP POLICY IF EXISTS profile_service ON user_profiles;
CREATE POLICY profile_service ON user_profiles
    FOR ALL TO service_role
    USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS roles_service ON user_roles;
CREATE POLICY roles_service ON user_roles
    FOR ALL TO service_role
    USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS role_log_service ON role_change_log;
CREATE POLICY role_log_service ON role_change_log
    FOR ALL TO service_role
    USING (true) WITH CHECK (true);

-- =====================================================
-- SESSION MANAGEMENT
-- =====================================================

CREATE TABLE IF NOT EXISTS user_sessions (
    session_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES user_profiles(user_id),
    active_role app_role NOT NULL,  -- The role selected for this session
    active_site_id TEXT,  -- For site-scoped roles, the selected site
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    last_activity_at TIMESTAMPTZ DEFAULT now(),
    is_active BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE user_sessions IS 'Active user sessions with role context';
COMMENT ON COLUMN user_sessions.active_role IS 'The role user selected at login - one of their allowed roles';
COMMENT ON COLUMN user_sessions.active_site_id IS 'For site-scoped roles, the site user is working in';

-- RLS for sessions
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sessions_select_own ON user_sessions;
CREATE POLICY sessions_select_own ON user_sessions
    FOR SELECT TO authenticated
    USING (user_id = current_user_id());

DROP POLICY IF EXISTS sessions_admin_select ON user_sessions;
CREATE POLICY sessions_admin_select ON user_sessions
    FOR SELECT TO authenticated
    USING (has_any_role(ARRAY['ADMIN', 'DEV_ADMIN']));

DROP POLICY IF EXISTS sessions_service ON user_sessions;
CREATE POLICY sessions_service ON user_sessions
    FOR ALL TO service_role
    USING (true) WITH CHECK (true);

-- =====================================================
-- PERMISSION HELPER FUNCTIONS
-- =====================================================

-- Check if user can access a specific site
CREATE OR REPLACE FUNCTION can_access_site(check_site_id TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    active_role TEXT;
BEGIN
    active_role := current_user_role();

    -- Global roles can access all sites
    IF active_role IN ('ADMIN', 'DEV_ADMIN', 'SPONSOR', 'AUDITOR') THEN
        RETURN true;
    END IF;

    -- Patients can access sites where they're enrolled
    IF active_role = 'PATIENT' THEN
        RETURN EXISTS (
            SELECT 1 FROM user_site_assignments
            WHERE patient_id = current_user_id()
            AND site_id = check_site_id
            AND enrollment_status = 'ACTIVE'
        );
    END IF;

    -- Investigators can access their assigned sites
    IF active_role = 'INVESTIGATOR' THEN
        RETURN EXISTS (
            SELECT 1 FROM investigator_site_assignments
            WHERE investigator_id = current_user_id()
            AND site_id = check_site_id
            AND is_active = true
        );
    END IF;

    -- Analysts can access their assigned sites
    IF active_role = 'ANALYST' THEN
        RETURN EXISTS (
            SELECT 1 FROM analyst_site_assignments
            WHERE analyst_id = current_user_id()
            AND site_id = check_site_id
            AND is_active = true
        );
    END IF;

    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION can_access_site(TEXT) IS 'Check if current user (in active role) can access the specified site';

-- =====================================================
-- GRANTS
-- =====================================================

GRANT SELECT ON user_profiles TO authenticated;
GRANT UPDATE ON user_profiles TO authenticated;
GRANT SELECT ON user_roles TO authenticated;
GRANT SELECT ON role_change_log TO authenticated;
GRANT SELECT ON user_sessions TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

GRANT ALL ON user_profiles, user_roles, role_change_log, user_sessions TO service_role;

-- =====================================================
-- UPDATED_AT TRIGGER
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
