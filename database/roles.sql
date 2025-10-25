-- =====================================================
-- Database Roles and Permissions
-- For Supabase, roles are managed via JWT claims
-- This file documents the role structure and provides setup
-- =====================================================
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00005: Role-Based Access Control
--   REQ-p00014: Least Privilege Access
--   REQ-o00007: Role-Based Permission Configuration
--
-- ROLE DEFINITIONS:
--   Defines user_profiles table storing role assignments and helper
--   functions for role verification used by RLS policies.
--
-- =====================================================

-- =====================================================
-- SUPABASE ROLE NOTES
-- =====================================================

-- Supabase uses three built-in PostgreSQL roles:
-- 1. anon - Unauthenticated users (public access)
-- 2. authenticated - Authenticated users (all logged-in users)
-- 3. service_role - Backend services (full access, bypasses RLS)

-- User roles (USER, INVESTIGATOR, ANALYST, ADMIN) are stored in JWT claims
-- and accessed via current_user_role() function

-- =====================================================
-- ROLE VERIFICATION FUNCTIONS
-- =====================================================

-- Function to check if current user has a specific role
CREATE OR REPLACE FUNCTION has_role(required_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN current_user_role() = required_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION has_role(TEXT) IS 'Check if current user has the specified role';

-- Function to check if current user has any of the specified roles
CREATE OR REPLACE FUNCTION has_any_role(required_roles TEXT[])
RETURNS BOOLEAN AS $$
BEGIN
    RETURN current_user_role() = ANY(required_roles);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION has_any_role(TEXT[]) IS 'Check if current user has any of the specified roles';

-- =====================================================
-- USER METADATA AND PROFILES
-- =====================================================

-- Table to store user profiles and role assignments
-- This integrates with Supabase auth.users table
CREATE TABLE user_profiles (
    user_id TEXT PRIMARY KEY,  -- References auth.users.id in Supabase
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    role TEXT NOT NULL CHECK (role IN ('USER', 'INVESTIGATOR', 'ANALYST', 'ADMIN')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    last_login_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    two_factor_enabled BOOLEAN DEFAULT false,
    must_change_password BOOLEAN DEFAULT false
);

COMMENT ON TABLE user_profiles IS 'User profiles linked to Supabase auth.users';
COMMENT ON COLUMN user_profiles.role IS 'Primary role - used in JWT claims';
COMMENT ON COLUMN user_profiles.two_factor_enabled IS '2FA requirement for FDA compliance';

-- Enable RLS on user_profiles
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Users can view their own profile
CREATE POLICY profile_select_own ON user_profiles
    FOR SELECT
    TO authenticated
    USING (user_id = current_user_id());

-- Users can update their own non-role fields
CREATE POLICY profile_update_own ON user_profiles
    FOR UPDATE
    TO authenticated
    USING (user_id = current_user_id())
    WITH CHECK (
        user_id = current_user_id()
        AND role = OLD.role  -- Cannot change own role
    );

-- Investigators can view profiles at their sites
CREATE POLICY profile_investigator_select ON user_profiles
    FOR SELECT
    TO authenticated
    USING (
        current_user_role() = 'INVESTIGATOR'
        AND user_id IN (
            SELECT patient_id
            FROM user_site_assignments
            WHERE site_id IN (
                SELECT site_id
                FROM investigator_site_assignments
                WHERE investigator_id = current_user_id()
                AND is_active = true
            )
        )
    );

-- Admins have full access
CREATE POLICY profile_admin_all ON user_profiles
    FOR ALL
    TO authenticated
    USING (current_user_role() = 'ADMIN')
    WITH CHECK (current_user_role() = 'ADMIN');

-- =====================================================
-- ROLE ASSIGNMENT AUDIT
-- =====================================================

-- Track all role changes for compliance
CREATE TABLE role_change_log (
    change_id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    old_role TEXT,
    new_role TEXT NOT NULL CHECK (new_role IN ('USER', 'INVESTIGATOR', 'ANALYST', 'ADMIN')),
    changed_by TEXT NOT NULL,
    reason TEXT NOT NULL,
    approved_by TEXT,
    approval_required BOOLEAN DEFAULT true,
    approval_status TEXT DEFAULT 'PENDING' CHECK (approval_status IN ('PENDING', 'APPROVED', 'REJECTED')),
    created_at TIMESTAMPTZ DEFAULT now(),
    approved_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE role_change_log IS 'Audit trail for all role changes';

-- Enable RLS
ALTER TABLE role_change_log ENABLE ROW LEVEL SECURITY;

-- Admins can view all role changes
CREATE POLICY role_changes_admin_select ON role_change_log
    FOR SELECT
    TO authenticated
    USING (current_user_role() = 'ADMIN');

-- Admins can create role change requests
CREATE POLICY role_changes_admin_insert ON role_change_log
    FOR INSERT
    TO authenticated
    WITH CHECK (
        current_user_role() = 'ADMIN'
        AND changed_by = current_user_id()
    );

-- Admins can approve role changes (different admin than requester)
CREATE POLICY role_changes_admin_update ON role_change_log
    FOR UPDATE
    TO authenticated
    USING (
        current_user_role() = 'ADMIN'
        AND approved_by = current_user_id()
        AND changed_by != current_user_id()  -- Different admin must approve
    )
    WITH CHECK (
        current_user_role() = 'ADMIN'
        AND approved_by = current_user_id()
    );

-- =====================================================
-- ROLE CHANGE TRIGGER
-- =====================================================

-- Automatically log role changes
CREATE OR REPLACE FUNCTION log_role_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.role IS DISTINCT FROM NEW.role THEN
        INSERT INTO role_change_log (
            user_id,
            old_role,
            new_role,
            changed_by,
            reason,
            approval_status
        ) VALUES (
            NEW.user_id,
            OLD.role,
            NEW.role,
            current_user_id(),
            'Role changed via user_profiles update',
            'PENDING'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER log_role_change_trigger
    AFTER UPDATE ON user_profiles
    FOR EACH ROW
    WHEN (OLD.role IS DISTINCT FROM NEW.role)
    EXECUTE FUNCTION log_role_change();

-- =====================================================
-- AUTHENTICATION HELPERS
-- =====================================================

-- Function to record login
CREATE OR REPLACE FUNCTION record_login()
RETURNS void AS $$
BEGIN
    UPDATE user_profiles
    SET last_login_at = now()
    WHERE user_id = current_user_id();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION record_login() IS 'Call this function after successful authentication';

-- Function to check if user requires 2FA
CREATE OR REPLACE FUNCTION requires_two_factor()
RETURNS BOOLEAN AS $$
DECLARE
    user_role TEXT;
    two_fa_enabled BOOLEAN;
BEGIN
    SELECT role, two_factor_enabled
    INTO user_role, two_fa_enabled
    FROM user_profiles
    WHERE user_id = current_user_id();

    -- Admins and Investigators must have 2FA
    IF user_role IN ('ADMIN', 'INVESTIGATOR') THEN
        RETURN true;
    END IF;

    -- Otherwise return user preference
    RETURN COALESCE(two_fa_enabled, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION requires_two_factor() IS 'Check if current user requires two-factor authentication';

-- =====================================================
-- SESSION MANAGEMENT
-- =====================================================

-- Track active sessions for security monitoring
CREATE TABLE user_sessions (
    session_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    last_activity_at TIMESTAMPTZ DEFAULT now(),
    is_active BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{}'::jsonb
);

COMMENT ON TABLE user_sessions IS 'Active user sessions for security monitoring';

-- Enable RLS
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- Users can view their own sessions
CREATE POLICY sessions_select_own ON user_sessions
    FOR SELECT
    TO authenticated
    USING (user_id = current_user_id());

-- Admins can view all sessions
CREATE POLICY sessions_admin_select ON user_sessions
    FOR SELECT
    TO authenticated
    USING (current_user_role() = 'ADMIN');

-- Service role can manage sessions
CREATE POLICY sessions_service_all ON user_sessions
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- =====================================================
-- PERMISSION HELPER FUNCTIONS
-- =====================================================

-- Check if user can access a specific site
CREATE OR REPLACE FUNCTION can_access_site(check_site_id TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    user_role TEXT;
BEGIN
    user_role := current_user_role();

    -- Admins can access all sites
    IF user_role = 'ADMIN' THEN
        RETURN true;
    END IF;

    -- Users can access sites where they're enrolled
    IF user_role = 'USER' THEN
        RETURN EXISTS (
            SELECT 1 FROM user_site_assignments
            WHERE patient_id = current_user_id()
            AND site_id = check_site_id
            AND enrollment_status = 'ACTIVE'
        );
    END IF;

    -- Investigators can access their assigned sites
    IF user_role = 'INVESTIGATOR' THEN
        RETURN EXISTS (
            SELECT 1 FROM investigator_site_assignments
            WHERE investigator_id = current_user_id()
            AND site_id = check_site_id
            AND is_active = true
        );
    END IF;

    -- Analysts can access their assigned sites
    IF user_role = 'ANALYST' THEN
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

COMMENT ON FUNCTION can_access_site(TEXT) IS 'Check if current user can access the specified site';

-- Check if user can modify a record
CREATE OR REPLACE FUNCTION can_modify_record(check_event_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
    user_role TEXT;
    record_patient_id TEXT;
    record_site_id TEXT;
BEGIN
    user_role := current_user_role();

    -- Get record details
    SELECT patient_id, site_id
    INTO record_patient_id, record_site_id
    FROM record_state
    WHERE event_uuid = check_event_uuid;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    -- Admins can modify any record
    IF user_role = 'ADMIN' THEN
        RETURN true;
    END IF;

    -- Users can only modify their own records
    IF user_role = 'USER' THEN
        RETURN record_patient_id = current_user_id();
    END IF;

    -- Investigators can create annotations but not modify original data
    -- This function is for direct modifications only
    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION can_modify_record(UUID) IS 'Check if current user can modify the specified record';

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

-- Grant access to new tables
GRANT SELECT ON user_profiles TO authenticated;
GRANT UPDATE ON user_profiles TO authenticated;
GRANT INSERT, SELECT ON role_change_log TO authenticated;
GRANT UPDATE ON role_change_log TO authenticated;
GRANT SELECT ON user_sessions TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Service role needs full access
GRANT ALL ON user_profiles, role_change_log, user_sessions TO service_role;

-- Updated at trigger for user_profiles
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
