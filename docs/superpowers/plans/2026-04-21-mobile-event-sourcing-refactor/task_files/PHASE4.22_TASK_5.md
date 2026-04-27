# Phase 4.22 Task 5 — Discrimination API (REQ-d00154-A+B+C)

## Goal

Add three new API surfaces that let receivers and dashboards distinguish
locally-originated events from bridged-from-upstream events without
hand-rolling provenance navigation:

1. `StoredEvent.originatorHop` — instance getter that returns the first
   `ProvenanceEntry` in the event's chain (materialized from
   `metadata['provenance'][0]`). Throws `StateError` when provenance is
   missing or empty.
2. `EventStore.isLocallyOriginated(StoredEvent event)` — returns `true`
   iff the event's originator install identity equals
   `source.identifier`. Comparison is on install UUID, not on hop class
   (`hopId`), because two installations of the same role class are
   distinct originators.
3. `StorageBackend.findAllEvents` — extended with two new optional
   named parameters: `originatorHopId` (matches `provenance[0].hopId`)
   and `originatorIdentifier` (matches `provenance[0].identifier`).
   AND'd together when both supplied.

REQs implemented: **REQ-d00154-A, REQ-d00154-B, REQ-d00154-C**.

## TDD Sequence

### Step 1 — Read existing API shapes

- `StoredEvent` is a regular `class` (not sealed) with a public
  `metadata: Map<String, dynamic>` field. Provenance is stored as a
  `List<Map<String, Object?>>` under `metadata['provenance']`.
  Decision: add `originatorHop` as an **instance getter on the class**
  (not an extension). The class already has `toMap`, `toJson`, and
  `toString` instance members — adding one more keeps the convenience
  accessor next to the data it reads.
- `ProvenanceEntry` lives in `apps/common-dart/provenance/lib/src/`
  with `hop`, `identifier`, `softwareVersion` (and optional receiver
  fields). Constructed via `ProvenanceEntry.fromJson(map)`.
- `EventStore` constructor exposes `final Source source;` as a public
  field (not `_source`). `isLocallyOriginated` reads `source.identifier`
  directly — no getter needed.
- `StorageBackend.findAllEvents` previously declared `({int?
  afterSequence, int? limit})`. Two new optional named parameters
  added at the end of the parameter list to preserve source
  compatibility for existing callers.
- `SembastBackend.findAllEvents` already loads + decodes events; the
  filter slots in after the existing load.

### Step 2 — Write the failing tests

Three new test files added (described in detail in the worklog
section for Task 5). Each file is annotated with:

- A header `IMPLEMENTS REQUIREMENTS:` block listing the asserted
  REQs.
- Per-test `// Verifies: REQ-d00154-X — <prose>` comments.
- Test description strings starting with the assertion ID
  `REQ-d00154-X:`.

### Step 3 — Run tests to verify they fail

```text
test/storage/find_all_events_originator_filter_test.dart:106:11:
  Error: No named parameter with the name 'originatorIdentifier'.
test/storage/find_all_events_originator_filter_test.dart:124:11:
  Error: No named parameter with the name 'originatorHopId'.
[stored_event_origin_test.dart and event_store_is_locally_originated_test.dart
 fail with "originatorHop not defined" / "isLocallyOriginated not defined"
 once the find_all_events_originator_filter compile error is past.]
```

All 7 tests fail for the predicted reasons (missing API surface).

### Step 4 — Implement `StoredEvent.originatorHop`

Instance getter added on `StoredEvent`. Implementation:

```dart
ProvenanceEntry get originatorHop {
  final raw = metadata['provenance'];
  if (raw is! List || raw.isEmpty) {
    throw StateError(
      'StoredEvent has empty or missing provenance; expected at least the '
      'originator entry per REQ-d00115',
    );
  }
  final first = raw.first;
  if (first is! Map) {
    throw StateError(
      'StoredEvent provenance[0] is not a Map; cannot decode originator hop',
    );
  }
  return ProvenanceEntry.fromJson(Map<String, Object?>.from(first));
}
```

Annotated `// Implements: REQ-d00154-A`. The JSON->object materialization
runs on each access — acceptable for the mobile-scale call frequency and
keeps `StoredEvent` stateless (no decoded cache to invalidate). The
extra non-Map guard surfaces malformed JSON loudly rather than letting
the cast inside `ProvenanceEntry.fromJson` throw a less obvious
`TypeError`.

`ProvenanceEntry` re-exported from `event_sourcing_datastore.dart`'s
public API alongside the existing `BatchContext` re-export so consumers
of the getter have a name for the return type without an extra package
import.

### Step 5 — Implement `EventStore.isLocallyOriginated`

Method added to `EventStore` between `append` (line ~133) and
`clearSecurityContext` (line ~153) so it sits with the other public
read-side helpers near the top of the class:

```dart
bool isLocallyOriginated(StoredEvent event) =>
    event.originatorHop.identifier == source.identifier;
```

Dartdoc explains the install-vs-class semantics. Annotated
`// Implements: REQ-d00154-B`.

### Step 6 — Extend `StorageBackend.findAllEvents` abstract signature

Added two optional named parameters:

```dart
Future<List<StoredEvent>> findAllEvents({
  int? afterSequence,
  int? limit,
  String? originatorHopId,
  String? originatorIdentifier,
});
```

Existing positional/named callers compile unchanged because the new
params are optional. Dartdoc updated to describe the AND semantics
when both filters are supplied.

### Step 7 — Implement `findAllEvents` in `SembastBackend`

Added Dart-side filtering after the existing `_eventStore.find` load.
When both `originatorHopId` and `originatorIdentifier` are null the
filter is skipped (zero overhead for the common path); otherwise each
event's `originatorHop` is materialized once and matched against the
non-null filters. Sembast finders cannot project across nested array
elements inside the JSON-encoded `metadata` blob, so in-memory
filtering is the simplest correct implementation; for mobile-scale
event logs the cost is bounded.

### Step 8 — Run new tests; expect green

```text
00:00 +7: All tests passed!
```

### Step 9 — Full suite; update 3 in-memory test doubles

Initial full-suite run after implementation produced 3 compile failures
in test files containing in-memory `StorageBackend` doubles. Each
override of `findAllEvents` was extended with the two new optional
named parameters (and, where the double forwards to a real backend,
the params were threaded through):

- `test/storage/storage_backend_contract_test.dart` — filter-blind
  double; new params accepted and ignored.
- `test/event_repository_test.dart` — counter-decorator double;
  forwards new params to delegate.
- `test/entry_service_test.dart` — recording-decorator double;
  forwards new params to inner backend.

Final full suite: 681 baseline + 7 new = **688** tests, all passing.

### Step 10 — Analyze

Initial analyze surfaced two `comment_references` infos in the new
`isLocallyOriginated` dartdoc (`[source.identifier]` and `[source.hopId]`
were not resolvable as dartdoc references). Replaced the bracket form
with backtick code spans (`` `source.identifier` `` /
`` `source.hopId` ``). Re-run:

```text
Analyzing event_sourcing_datastore...
No issues found! (ran in 0.9s)
```

## Files Touched

### lib/

- `apps/common-dart/event_sourcing_datastore/lib/src/storage/stored_event.dart`
  (1 import + ~22-line getter added).
- `apps/common-dart/event_sourcing_datastore/lib/event_sourcing_datastore.dart`
  (`ProvenanceEntry` added to existing provenance re-export).
- `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart`
  (1 method added; ~18 lines).
- `apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart`
  (abstract `findAllEvents` signature extended; dartdoc rewritten;
  ~12 lines diff).
- `apps/common-dart/event_sourcing_datastore/lib/src/storage/sembast_backend.dart`
  (concrete `findAllEvents` extended; filter block added; ~25 lines diff).

### test/ — new files

- `apps/common-dart/event_sourcing_datastore/test/storage/stored_event_origin_test.dart` (2 tests, ~70 lines).
- `apps/common-dart/event_sourcing_datastore/test/event_store/event_store_is_locally_originated_test.dart` (2 tests, ~95 lines).
- `apps/common-dart/event_sourcing_datastore/test/storage/find_all_events_originator_filter_test.dart` (3 tests, ~145 lines).

### test/ — updated test doubles

- `apps/common-dart/event_sourcing_datastore/test/storage/storage_backend_contract_test.dart` (`findAllEvents` override extended).
- `apps/common-dart/event_sourcing_datastore/test/event_repository_test.dart` (`findAllEvents` override extended; new params forwarded).
- `apps/common-dart/event_sourcing_datastore/test/entry_service_test.dart` (`findAllEvents` override extended; new params forwarded).

### worklog / task file

- `PHASE_4.22_WORKLOG.md` — Task 5 checkbox flipped; Task 5 details
  section appended.
- This file (`PHASE4.22_TASK_5.md`).

## Outcome

The discrimination API is in place. Receivers can call
`eventStore.isLocallyOriginated(event)` to discriminate without
provenance navigation. Dashboards / forensic tools can call
`backend.findAllEvents(originatorHopId: ..., originatorIdentifier: ...)`
to project on originator identity directly. The getter
`event.originatorHop` is the lower-level building block both APIs
ride on, also available to downstream code (e.g. the demo app's
per-pane install UUID display in Task 9-10).

Phase 4.22 Task 6 (SubscriptionFilter.includeSystemEvents +
fill_batch / historical_replay hard-drop lift) builds on Task 4's
install-scoped system aggregateIds — Task 5 is a peer of Task 4
that exposes the read-side query primitives bridging the two will
need.
