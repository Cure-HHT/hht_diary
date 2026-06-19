# ADR-004: Separation of Investigator Annotations

**Status:** Obsolete — superseded by the event-sourcing (EVS) cutover (CUR-1170).

This ADR chose separate relational tables to keep investigator annotations apart from
participant-originated entries. Those tables were retired with the in-repo `database/`
schema. Under EVS the same separation holds by event type and provenance: investigator
annotations are distinct events in the shared hash-chained event log. Original decision
content removed; see git history.
