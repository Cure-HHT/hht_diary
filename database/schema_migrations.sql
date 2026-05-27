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

-- Application runtime role may read the current schema version; writes are
-- reserved for the db-schema-job (runs as the owner/superuser, not as
-- authenticated). Guard so this file can be sourced in environments where
-- roles.sql has not yet run (e.g. bare test containers).
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
        GRANT SELECT ON schema_migrations TO authenticated;
    END IF;
END
$$;
