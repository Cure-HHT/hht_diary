-- =====================================================
-- Migration tracking table
-- =====================================================
-- The database's schema version is MAX(id). Rows are written only by the
-- db-schema-job (MODE=migrate stamps each applied migration; MODE=reset
-- stamps every migration already folded into the consolidated baseline).
-- Only the db-schema-job writes this table; application code reads it.

CREATE TABLE IF NOT EXISTS schema_migrations (
    id         INTEGER     PRIMARY KEY,
    name       TEXT        NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE schema_migrations IS
  'Applied DB migrations; schema version = MAX(id). Written only by db-schema-job.';

-- Grants are NOT defined here. This file runs early in init.sql, before
-- roles.sql creates the application roles, so any conditional grant against
-- `authenticated` / `service_role` would be skipped and dead. The runtime
-- read path (service_role) is covered by the catch-all
-- `GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role` in
-- rls_policies.sql, which runs after this table exists.
