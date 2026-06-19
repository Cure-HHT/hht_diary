# ADR-002: JSONB for Flexible Diary Schema

**Status:** Obsolete — superseded by the event-sourcing (EVS) cutover (CUR-1170).

This ADR chose relational JSONB columns for diary-entry storage. Those tables were retired
with the in-repo `database/` schema. Under EVS, diary data is stored as hash-chained events
in the `event_sourcing` event store and projected into read models at runtime; there is no
relational diary schema in-repo. Original decision content removed; see git history.
