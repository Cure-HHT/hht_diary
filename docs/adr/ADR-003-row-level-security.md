# ADR-003: Row-Level Security for Multi-Tenancy

**Status:** Obsolete.

Access control is event-sourced: permissions and role assignments are events, evaluated in the
application layer over the event log. (Database-level tamper-resistance for the event store is
tracked in CUR-1439.)
