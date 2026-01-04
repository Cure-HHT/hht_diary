-- Create application user for Dart server connections
-- This runs as postgres superuser during container initialization

-- Create app_user with password from environment
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_user') THEN
        CREATE USER app_user WITH PASSWORD 'dev_password';
    END IF;
END
$$;

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON DATABASE clinical_diary TO app_user;
GRANT ALL ON SCHEMA public TO app_user;

-- Allow app_user to create tables (needed for schema deployment)
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO app_user;
