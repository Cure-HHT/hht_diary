#!/bin/bash
# Create application user for Dart server connections
# This runs as postgres superuser during container initialization
# Uses APP_USER and APP_PASSWORD environment variables from docker-compose

set -e

# Use environment variables with defaults
DB_USER="${APP_USER:-app_user}"
DB_PASS="${APP_PASSWORD:-dev_password}"
DB_NAME="${POSTGRES_DB:-clinical_diary}"

echo "Creating database user: $DB_USER"

psql -v ON_ERROR_STOP=1 --username postgres --dbname "$DB_NAME" <<-EOSQL
    -- Create app user with password from environment
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
            CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
        END IF;
    END
    \$\$;

    -- Grant necessary permissions
    GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
    GRANT ALL ON SCHEMA public TO $DB_USER;

    -- Allow app_user to create tables (needed for schema deployment)
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO $DB_USER;

    -- Note: RLS roles (anon, authenticated, service_role) are created and
    -- granted to app_user in database/roles.sql
EOSQL

echo "User $DB_USER created successfully"
