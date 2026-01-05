# ADR-011: Event Sourcing Refinements

**Date**: 2026-01-01
**Status**: Accepted

---

## Context

The HHT Diary system uses event sourcing for FDA 21 CFR Part 11 compliance. Several implementation questions arose regarding data redundancy and timestamp handling in an event-sourced architecture.

---

## Decisions

### Decision 1: Omit old_value from Events

**Decision**: Do not store `old_value` in event payloads.

**Rationale**: In event sourcing, `old_value` equals the `new_value` of the previous event in the stream. Storing it creates redundant data. FDA/ALCOA requires preserving original values and complete history - both are satisfied by the event stream itself without explicit `old_value` storage.

**Trade-off**: Audit reports showing before/after values require joining consecutive events. This minor query complexity is acceptable to maintain single source of truth.

---

### Decision 2: Derive State from Events

**Decision**: Record state (locked, complete, deleted) is derived from the event stream, not stored as a separate column.

**Rationale**:
- Explicit state storage duplicates information derivable from events
- Risk of state drifting out of sync with event truth
- "Locked" is an authorization policy enforced at the application layer, not a data attribute
- Event sourcing protects against tampering; explicit state only prevents user mistakes
- Analysts already filter by derived properties (e.g., excluding deleted records)

**Implementation**: To enforce "lock" functionality, emit a `record.locked` event. State derivation reflects it, and policy enforcement prevents further edits.

---

### Decision 3: Include Sync Timestamps in EDC Metadata

**Decision**: Include `diary_sync_timestamp` in metadata sent to the EDC.

**Rationale**: ALCOA+ "Contemporaneous" principle requires complete chain of custody. Three timestamps exist:
1. `client_timestamp` - when patient performed action
2. `diary_sync_timestamp` - when received by HHT Diary backend
3. `edc_timestamp` - when received by EDC (captured by EDC)

Including timestamp #2 in EDC metadata provides complete audit visibility without requiring auditors to query multiple systems.

---

## Consequences

### Positive
- Single source of truth (events)
- No redundant data storage
- Complete chain of custody timestamps
- Simpler event schema

### Negative
- Before/after reports require joining events
- Analysts must understand derived state

---

**Review History**:
- 2026-01-01: Accepted
