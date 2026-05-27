-- =====================================================
-- Migration tracking table
-- =====================================================
-- The database's schema version is MAX(id). Rows are written only by the
-- db-schema-job (MODE=migrate stamps each applied migration; MODE=reset
-- stamps every migration already folded into the consolidated baseline).
-- Application runtime service accounts have SELECT only on this table.

CREATE TABLE IF NOT EXISTS schema_migrations (
    id         INTEGER     PRIMARY KEY,
    name       TEXT        NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE schema_migrations IS
  'Applied DB migrations; schema version = MAX(id). Written only by db-schema-job.';
