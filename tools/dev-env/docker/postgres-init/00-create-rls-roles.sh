#!/bin/bash
# Bootstrap RLS roles for Docker PostgreSQL initialization
#
# NOTE: This is a BOOTSTRAP script for local development only.
# The authoritative role definitions are in database/roles.sql.
# This script creates the PostgreSQL roles needed by 01-create-user.sh
# before the schema files are loaded.

set -e

echo "Creating RLS roles (bootstrap)..."

psql -v ON_ERROR_STOP=1 --username postgres --dbname "${POSTGRES_DB:-clinical_diary}" <<-EOSQL
    -- Create PostgreSQL roles used by RLS policies
    -- These must exist before app_user can be granted membership

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
EOSQL

echo "RLS roles created (bootstrap complete)"
