# Supabase Pre-Deployment Audit (Obsolete)

**Status:** Obsolete — the project is off Supabase and off the relational schema.

This was a pre-deployment audit of the retired Supabase / raw-Postgres relational design.
The audited `database/` directory was deleted in the EVS cutover (CUR-1170); the event store
is now created and owned at runtime by the `event_sourcing` library's `PostgresBackend`
(deployed via `portal_server_evs`). Original content removed; see git history.
