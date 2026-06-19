# ADR-003: Row-Level Security for Multi-Tenancy

**Status:** Obsolete — superseded by the event-sourcing (EVS) cutover (CUR-1170).

This ADR chose PostgreSQL row-level-security policies for multi-tenant isolation. Those
policies were retired with the in-repo `database/` schema. Under EVS, access control is
event-sourced permissions evaluated in the application layer over the event log (permissions
and role assignments are themselves events). DB-level tamper-resistance for the event store
is an open gap tracked in CUR-1439. Original decision content removed; see git history.
