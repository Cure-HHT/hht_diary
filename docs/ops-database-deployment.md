# Database Deployment Guide (Obsolete)

**Status:** Obsolete — superseded by the event-sourcing (EVS) cutover (CUR-1170).

This guide covered manual deployment of JSONB validation functions and RLS policies to a
raw-Postgres / Supabase database. That `database/` schema was deleted; under EVS the event
store schema is created and owned at runtime by the `event_sourcing` library's
`PostgresBackend` — there is no manual SQL deployment step. Original content removed; see
git history.
