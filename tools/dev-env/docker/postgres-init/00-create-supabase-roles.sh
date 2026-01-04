#!/bin/bash
# Create Supabase-compatible roles for local PostgreSQL
# These roles are built-in to Supabase but need to be created manually for local dev

set -e

echo "Creating Supabase-compatible roles..."

psql -v ON_ERROR_STOP=1 --username postgres --dbname "${POSTGRES_DB:-clinical_diary}" <<-EOSQL
    -- Create roles that Supabase provides by default
    -- These are needed for RLS policies that reference them

    DO \$\$
    BEGIN
        -- 'anon' role: unauthenticated users
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
            CREATE ROLE anon NOLOGIN;
        END IF;

        -- 'authenticated' role: logged-in users
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
            CREATE ROLE authenticated NOLOGIN;
        END IF;

        -- 'service_role' role: backend services with elevated privileges
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'service_role') THEN
            CREATE ROLE service_role NOLOGIN;
        END IF;
    END
    \$\$;

    -- Grant usage on public schema
    GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

    -- Grant the roles to app_user so it can SET ROLE to them
    GRANT anon, authenticated, service_role TO ${APP_USER:-app_user};

    COMMENT ON ROLE anon IS 'Supabase-compatible role for unauthenticated access';
    COMMENT ON ROLE authenticated IS 'Supabase-compatible role for authenticated users';
    COMMENT ON ROLE service_role IS 'Supabase-compatible role for backend services';
EOSQL

echo "Supabase-compatible roles created successfully"
