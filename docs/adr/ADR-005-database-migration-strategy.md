# ADR-005: Database Migration Strategy

**Status:** Obsolete — superseded by the event-sourcing (EVS) cutover (CUR-1170).

This ADR defined a formal SQL migration / change-control process. It was retired with the
in-repo `database/` directory and the `database-migration.yml` workflow (the Squawk
migration-lint CI step was removed with it). Under EVS there are no in-repo SQL migrations:
the `event_sourcing` library's `PostgresBackend` creates and owns the event-store schema at
runtime, and the FDA-relevant change record is the hash-chained event log. Original decision
content removed; see git history.
