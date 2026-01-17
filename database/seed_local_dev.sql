-- Local Development Seed Data
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-d00027: Containerized Development Environments
--
-- Usage:
--   docker exec -i sponsor-portal-postgres psql -U postgres -d sponsor_portal < database/seed_local_dev.sql
--
-- This creates a Developer Admin for local testing. The firebase_uid will be
-- linked automatically on first login via email match.

-- Developer Admin for local development
INSERT INTO portal_users (email, name, role, status, mfa_type, mfa_enrolled)
VALUES (
    'mike.bushe@anspar.org',
    'Mike Bushe',
    'Developer Admin',
    'active',
    'totp',      -- Developer Admins use TOTP
    false        -- MFA enrollment happens on first login
)
ON CONFLICT (email) DO UPDATE SET
    role = EXCLUDED.role,
    status = EXCLUDED.status,
    mfa_type = EXCLUDED.mfa_type;

-- Add role to portal_user_roles junction table
INSERT INTO portal_user_roles (user_id, role)
SELECT id, 'Developer Admin'::portal_user_role
FROM portal_users
WHERE email = 'mike.bushe@anspar.org'
ON CONFLICT (user_id, role) DO NOTHING;

-- Verify
SELECT email, name, role, status, mfa_type FROM portal_users WHERE email = 'mike.bushe@anspar.org';
