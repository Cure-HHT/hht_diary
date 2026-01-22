-- =====================================================
-- Local Development Role Grants
-- =====================================================
--
-- IMPLEMENTS REQUIREMENTS:
--   REQ-d00027: Containerized Development Environments
--
-- This file contains role grants specific to local development.
-- It is NOT applied in production - only by run_local.sh --reset.
--
-- In local dev, we connect as postgres superuser directly.
-- Production uses app_user with proper role membership.
-- =====================================================

-- Grant RLS roles to postgres (for local dev when connecting as superuser)
-- This allows SET ROLE to work in local development environments
-- Required for executeWithContext() to function properly
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'postgres') THEN
        GRANT anon, authenticated, service_role TO postgres;
        RAISE NOTICE 'Granted RLS roles to postgres user for local development';
    END IF;
END
$$;
