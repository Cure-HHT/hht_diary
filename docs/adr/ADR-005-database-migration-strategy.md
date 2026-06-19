# ADR-005: Database Migration Strategy

**Status:** Obsolete.

The `event_sourcing` library's `PostgresBackend` creates and owns the event-store schema at
runtime; the FDA-relevant change record is the hash-chained event log.
