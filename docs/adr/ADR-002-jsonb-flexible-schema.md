# ADR-002: JSONB for Flexible Diary Schema

**Status:** Obsolete.

Diary data is stored as hash-chained events via the `event_sourcing` library and projected into
read models at runtime.
