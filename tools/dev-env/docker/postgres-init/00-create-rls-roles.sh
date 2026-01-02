#!/bin/bash
# Create PostgreSQL roles for Row-Level Security policies
# These roles are used by RLS policies to control access levels

set -e

echo "Creating RLS roles..."

psql -v ON_ERROR_STOP=1 --username postgres --dbname "${POSTGRES_DB:-clinical_diary}" <<-EOSQL
    -- Create roles used by RLS policies

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

    COMMENT ON ROLE anon IS 'Role for unauthenticated access';
    COMMENT ON ROLE authenticated IS 'Role for authenticated users';
    COMMENT ON ROLE service_role IS 'Role for backend services';
EOSQL

echo "RLS roles created successfully"
