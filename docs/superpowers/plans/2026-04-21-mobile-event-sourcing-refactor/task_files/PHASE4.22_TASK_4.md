# Phase 4.22 Task 4 — System aggregate_id = source.identifier (10 sites)

## Goal

Switch all 10 reserved-system audit emission sites from per-registry-string
aggregateIds (`'destination:Primary'`, `'system:entry-type-registry'`,
`'security-retention'`, `'retention-compact-...'`, etc.) to
`source.identifier` (the install UUID). Each install therefore has a
single per-installation hash-chained system aggregate spanning bootstrap,
destination registry, and security/retention audits. The destination /
subject identity moves into the audit event's `data` map (`data.id` for
destination audits; `data.subject_event_id` for redaction audits) so
"all audits about destination X" / "all redactions of event Y" queries
reduce to `entry_type` + `data.id` filters.

REQs implemented: **REQ-d00134-E (revised)**, **REQ-d00129-J/K/L/M/N
(revised)**, **REQ-d00144-G (revised)**, **REQ-d00138-D/E/F/H (revised)**,
all under the umbrella of **REQ-d00154-D**.

## TDD Sequence

### Step 1 — Inventory the 10 sites

```text
                _____________________________________
bootstrap.dart |  system.entry_type_registry_init.   | line ~176
               |  REQ-d00134-E (revised)             |
               -------------------------------------

                _____________________________________
destination_   |  _emitDestinationAuditInTxn helper  | line ~511
registry.dart  |  consolidates 5 callers:            |
               |    addDestination          (~line 110)
               |    setStartDate            (~line 235)
               |    setEndDate              (~line 321)
               |    deleteDestination       (~line 380)
               |    tombstoneAndRefill      (~line 474)
               |  REQ-d00129-J/K/L/M (revised),      |
               |  REQ-d00144-G (revised)             |
               -------------------------------------

                _____________________________________
event_store    |  clearSecurityContext               | line ~163
.dart          |  applyRetentionPolicy:              |
               |    compact branch          (~line 225)
               |    purge branch            (~line 251)
               |    per-sweep audit         (~line 277)
               |  REQ-d00138-D/E/F/H (revised)       |
               -------------------------------------
```

11 distinct lib emission points (the spec lists "10" because the
`setEndDate` and `deactivateDestination` flows share one site —
`deactivateDestination` is implemented as `setEndDate(now())`).

### Step 2 — Inventory existing tests asserting on the old aggregateIds

```bash
grep -rnE "aggregateId.*(destination:|system:entry-type-registry|security-retention|system_retention|system_destination)" \
  apps/common-dart/event_sourcing_datastore/test/
```

Hits in 3 test files:
- `bootstrap_registry_initialized_audit_test.dart` (1 expectation).
- `destinations/registry_audit_test.dart` (6 expectations across 6 tests).
- `event_store_test.dart` (1 expectation in the redaction test).

### Step 3 — Write the failing tests (3 new files)

**a.** `test/destinations/destination_registry_audit_aggregate_id_test.dart`
— 6 tests covering REQ-d00129-J/K/L/M, REQ-d00144-G, REQ-d00154-D
multi-destination aggregate sharing.

**b.** `test/bootstrap_audit_aggregate_id_test.dart` — 2 tests covering
REQ-d00134-E (revised) plus a two-install REQ-d00154-D disjointness check.

**c.** `test/security/event_store_security_audit_aggregate_id_test.dart`
— 3 tests covering REQ-d00138-D/E/F/H and a three-stream REQ-d00154-D
aggregate-sharing check.

All tests use the REQ citation convention: `// Verifies: REQ-x-Y` annotation
above each `test(...)` call AND the assertion ID at the start of every
test description string.

### Step 4 — Tests fail for the right reason

```text
00:00 +0 -11: Some tests failed.
Expected: 'cccc3333-4444-...'
  Actual: 'retention-compact-2030-01-01T00:00:00.000Z'
```

All 11 new tests fail with the predicted "expected install UUID, got
old per-registry string" diff.

### Step 5 — Implement bootstrap site

`bootstrap.dart`: `aggregateId: 'system:entry-type-registry'` ->
`aggregateId: source.identifier`. Annotated `// Implements: REQ-d00154-D`.

### Step 6 — Implement 5 destination_registry sites + tombstoneAndRefill

`_emitDestinationAuditInTxn` rewritten:
- `aggregateId: 'destination:$destinationId'` -> `aggregateId: _eventStore.source.identifier`.
- `destinationId` parameter dropped (unused once aggregate construction
  doesn't need it; destination identity is already in `data['id']` per
  the Phase 4.17 destination-audit data shape).
- 5 callers updated to drop the `destinationId:` argument.
- Dartdoc rewritten in final-state voice describing the install-scoped
  aggregate; new `// Implements: REQ-d00129-J+K+L+M+N (revised),
  REQ-d00144-G (revised), REQ-d00154-D` annotation block above the helper.

### Step 7 — Implement 3 event_store sites

`clearSecurityContext`:
- `aggregateId: eventId` -> `aggregateId: source.identifier`.
- `eventId` moves from aggregateId into `data['subject_event_id']` so
  redaction queries by subject still work via `entry_type` + `data.subject_event_id`.

`applyRetentionPolicy`:
- compact branch: `aggregateId: 'retention-compact-${now}'` -> `aggregateId: source.identifier`.
- purge branch: `aggregateId: 'retention-purge-${now}'` -> `aggregateId: source.identifier`.
- per-sweep audit: `aggregateId: 'security-retention'` -> `aggregateId: source.identifier`.

Each site gets a `// Implements: REQ-d00138-D/E/F/H (revised),
REQ-d00154-D` annotation describing the consolidation rationale.

### Step 8 — New tests pass

```text
00:00 +11: All tests passed!
```

### Step 9 — Full suite; update 8 existing tests in 3 files

Initial full-suite run after implementation: 8 failures, all in the
3 expected files. Each was an existing assertion on the old
aggregateId string. Each updated in place to assert on the install
UUID:

- `bootstrap_registry_initialized_audit_test.dart` — 1 expectation
  updated to `_source.identifier`. Header REQ list extended with
  REQ-d00154-D.
- `destinations/registry_audit_test.dart` — 6 expectations updated to a
  hoisted `_installUUID` constant. Hoisted the test fixture's `Source`
  into a top-level `_source` constant for clarity.
- `event_store_test.dart` — 1 expectation in the redaction test:
  `aggregateId == ev.eventId` -> `aggregateId == fx.eventStore.source.identifier`,
  plus a new `data['subject_event_id'] == ev.eventId` assertion (since
  the redacted event id moves into data).

```text
00:05 +681: All tests passed!
```

670 baseline + 11 new = 681. No tests deleted; updated-in-place per
greenfield rules (no compatibility tests for the old shape).

### Step 10 — Analyze

```text
Analyzing event_sourcing_datastore...
No issues found! (ran in 1.1s)
```

### Step 11 — Cleanup grep

```bash
grep -rnE "aggregateId:\s*'(destination:|system:entry-type-registry|security-retention|system_retention|system_destination|retention-compact|retention-purge)" \
  apps/common-dart/event_sourcing_datastore/lib/
```

Zero hits. The reserved-system aggregateId strings have all been
displaced from `lib/`.

## Files Touched

### lib/

- `apps/common-dart/event_sourcing_datastore/lib/src/bootstrap.dart`
  (1 emission site rewritten; ~5 lines diff).
- `apps/common-dart/event_sourcing_datastore/lib/src/destinations/destination_registry.dart`
  (1 helper rewritten; 5 callers updated; ~30 lines diff).
- `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart`
  (3 emission sites rewritten; ~25 lines diff).

### test/ — new files

- `apps/common-dart/event_sourcing_datastore/test/destinations/destination_registry_audit_aggregate_id_test.dart` (6 tests, ~230 lines).
- `apps/common-dart/event_sourcing_datastore/test/bootstrap_audit_aggregate_id_test.dart` (2 tests, ~125 lines).
- `apps/common-dart/event_sourcing_datastore/test/security/event_store_security_audit_aggregate_id_test.dart` (3 tests, ~245 lines).

### test/ — updated in place (greenfield)

- `apps/common-dart/event_sourcing_datastore/test/bootstrap_registry_initialized_audit_test.dart` (1 expectation).
- `apps/common-dart/event_sourcing_datastore/test/destinations/registry_audit_test.dart` (6 expectations + hoisted fixture constants).
- `apps/common-dart/event_sourcing_datastore/test/event_store_test.dart` (1 expectation + 1 new assertion on `data.subject_event_id`).

### worklog / task file

- `PHASE_4.22_WORKLOG.md` — Task 4 checkbox flipped; Task 4 details section appended.
- This file (`PHASE4.22_TASK_4.md`).

## Outcome

The 10 reserved-system audit emission sites now share a single
per-installation hash-chained system aggregate. Two installations
bridging audits to a downstream observer produce disjoint
aggregateIds, so the observer can split the streams cleanly without
provenance-chain navigation. Destination / subject identity preserved
in `data` so existing query patterns continue to work.

Phase 4.22 Task 5 (the discrimination API: `originatorHop`,
`isLocallyOriginated`, `findAllEvents` filters) builds on this
consolidation directly — every system event a single install emits now
has a stable, query-able aggregateId equal to that install's UUID.
