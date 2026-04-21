# Mobile Event-Sourcing Implementation

**Version**: 1.0
**Audience**: Development Specification
**Status**: Draft
**Last Updated**: 2026-04-21

> **See**: prd-database.md for the immutable audit trail principle (REQ-p00004) and complete data change history (REQ-p00013)
> **See**: prd-event-sourcing-system.md for the Event Type Registry (REQ-p01050) and offline event queue (REQ-p01001)
> **See**: docs/superpowers/2026-04-21-mobile-event-sourcing-refactor-design.md for the target architecture
> **See**: docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/ for the phased implementation plan (CUR-1154)

This specification defines the mobile-side implementation of the event-sourcing architecture described in prd-database.md and prd-event-sourcing-system.md. It accumulates DEV-level requirements added across the 5 phases of CUR-1154. Phase 1 introduces the two pure-Dart data types that underpin all subsequent work: `ProvenanceEntry` (chain-of-custody) and `EntryTypeDefinition` (registry entry shape).

---

# REQ-d00115: ProvenanceEntry Schema and Append Rules

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00004, REQ-p00013

## Rationale

REQ-p00004 (Immutable Audit Trail via Event Sourcing) and REQ-p00013 (Complete Data Change History) require that every data change be attributable to its origin and immutable once recorded. For events that flow across multiple systems (mobile device to diary server to sponsor portal to EDC), a single top-level `device_id` and `client_timestamp` captures only the originating hop. Downstream hops — the diary-server ingestion, portal-server receipt, any transform stages — need to contribute their own attribution without mutating the original record.

A chain-of-custody structure stored in `event.metadata.provenance` solves this: each hop appends one entry on receipt, recording who, when, what software version, and whether a transform was applied. Prior entries are never touched. The resulting chain is a complete, immutable record of the event's journey, directly supporting the ALCOA+ *Attributable* and *Contemporaneous* principles for cross-system data flow.

The top-level `device_id`, `client_timestamp`, and `software_version` event fields remain as duplicates of `provenance[0]` as a migration bridge during the mobile refactor; they are removed once the portal ingestion reads provenance directly (deferred work).

## Assertions

A. The system SHALL append exactly one `ProvenanceEntry` to `event.metadata.provenance` on each hop that receives the event, such that the length of the chain equals the number of systems the event has traversed.

B. The system SHALL NOT mutate any `ProvenanceEntry` already present in the chain; subsequent hops SHALL only append.

C. Each `ProvenanceEntry` SHALL carry the fields `hop` (string), `received_at` (ISO 8601 with timezone offset), `identifier` (string), `software_version` (string), and an optional `transform_version` (string).

D. The `identifier` SHALL be a device UUID when the hop represents a patient-facing mobile device; for server hops the `identifier` SHALL be a server instance identifier.

E. The `software_version` SHALL follow the format `"<package-name>@<semver>[+<build>]"`, enabling each hop's software version to be precisely identified from the provenance entry alone.

F. The `transform_version` field SHALL be non-null when and only when this hop's incoming wire payload was produced by a transform at the previous hop; absence SHALL indicate the payload was passed through without transformation.

*End* *ProvenanceEntry Schema and Append Rules* | **Hash**: e129e6a9

---

# REQ-d00116: EntryTypeDefinition Schema

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01050

## Rationale

REQ-p01050 (Event Type Registry) establishes that the system maintains a registry of event types and requires metadata on each type for discoverability, versioning, and sponsor eligibility. The mobile implementation needs a concrete data structure to carry that metadata: a pure-Dart value type that describes one entry type's identity, its schema version, the widget used to render it, and optional hints for materializer and destination routing behavior.

`EntryTypeDefinition` is that data structure. It is pure data — no storage, no Flutter dependency — so that the same package can be used on the portal server when server-side entry-type definitions are introduced. The Phase 1 deliverable is the type itself and its JSON round-trip. The registry that consumes these definitions and the widget registry that resolves `widget_id` are downstream phases (3 and 5 respectively) of CUR-1154.

## Assertions

A. An `EntryTypeDefinition` SHALL carry an `id` string that matches the `event.entry_type` value for every event of this entry type.

B. An `EntryTypeDefinition` SHALL carry a `version` string identifying the schema version under which events of this type are written.

C. An `EntryTypeDefinition` SHALL carry a `name` string used for display purposes by the UI and by operational tooling.

D. An `EntryTypeDefinition` SHALL carry a `widget_id` string that serves as a key into the Flutter widget registry, selecting the bespoke or shared widget that renders this entry type.

E. An `EntryTypeDefinition` SHALL carry a `widget_config` JSON payload; the shape of `widget_config` SHALL be determined by the widget corresponding to `widget_id`, not by the EntryTypeDefinition itself.

F. An `EntryTypeDefinition` MAY carry a nullable `effective_date_path` string; when non-null, `effective_date_path` SHALL be a JSON path usable by the materializer to extract the entry's effective date from `event.data.answers`.

G. An `EntryTypeDefinition` MAY carry an optional `destination_tags` list of strings; destinations SHALL be able to match on these tags via `SubscriptionFilter`.

*End* *EntryTypeDefinition Schema* | **Hash**: 0bb2f928
