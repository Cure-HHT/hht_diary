# Phase 4.22 Task 3 — dedupeByContent matches by entry_type within aggregate

## Goal

Refine `EventStore._appendInTxn`'s `dedupeByContent` lookup from "last event
of any type in aggregate" to "most-recent event of matching entry_type in
aggregate." Pre-condition for Task 4 (system aggregate consolidation), where
multiple system entry types share the install-scoped `source.identifier`
aggregate per REQ-d00154-D and must dedupe per emission stream.

REQ implemented: **REQ-d00134-F** (revised by Task 2 to specify the new
"most-recent event of matching entry_type" semantic).

## TDD Sequence

### Step 1 — Failing test

Wrote `apps/common-dart/event_sourcing_datastore/test/event_store/dedupe_by_content_entry_type_match_test.dart`
with two tests:

1. `REQ-d00134-F: same entry_type same content same aggregate is no-op` —
   sanity check that the existing dedupe behavior still holds when
   entry_type matches.
2. `REQ-d00134-F: different entry_type same content same aggregate is NOT
   a dedupe match` — first emits a `system.destination_registered` event
   with content `{'k': 'v'}`, then attempts to emit a
   `system.entry_type_registry_initialized` event with the same content
   in the same aggregate. Under old behavior, the second emission would
   be incorrectly dedupe-skipped because `aggregateHistory.last` would
   match content-hash regardless of entry_type. Under refined behavior,
   the per-entry_type lookup finds no prior event of matching type and
   the candidate appends. A subsequent identical re-emission of the
   second's entry_type DOES dedupe-skip.

Test bootstraps a minimal `EventStore` with no caller-supplied entry
types (only the auto-registered system entry types). Uses two reserved
system entry types as the two entry-type-distinct events, since both
are auto-registered by `bootstrapAppendOnlyDatastore`.

Annotations:
- Group has `/// Verifies REQ-d00134-F` doc comment.
- Each `test(...)` has `// Verifies: REQ-d00134-F — <prose>` immediately above.
- Test description strings begin with `REQ-d00134-F:`.
- File ends in `_test.dart`.

### Step 2 — Test fails for the right reason

```
00:00 +1 -1: ... REQ-d00134-F: different entry_type same content same aggregate is NOT a dedupe match [E]
  Expected: not null
    Actual: <null>
  first emission of this entry_type in shared aggregate appends despite
  identical content on a different prior entry_type
```

Confirmed: test 1 (same entry_type) passes under old code (existing
behavior already covers it); test 2 (different entry_type) fails
exactly as predicted because the prior-event content hash matches.

### Step 3 — Implement the refinement

Modified `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart`
lines 379-411 (the dedupe-by-content block inside `appendInTxn`).

```text
                ___________________________
old behavior:  | aggregateHistory.last     |
               |   if dedupe && history    |
               |     non-empty             |
                ---------------------------

                ___________________________
new behavior:  | reverse-walk aggregate    |
               | history; pick first event |
               | whose entry_type ==       |
               | candidate's entry_type    |
                ---------------------------
```

Annotated with `// Implements: REQ-d00134-F` and a cross-reference to
REQ-d00154-D explaining WHY (multiple entry types sharing the
install-scoped aggregate need per-stream dedupe). The per-entry_type
linear scan is acceptable for the dedupe path because the existing
implementation already loaded the full `aggregateHistory` from the
backend; the new code only adds a tight loop over the in-memory list,
not a second backend round-trip.

### Step 4 — Test passes

```
00:00 +2: All tests passed!
```

### Step 5 — Full suite (regression check)

```
00:05 +670: All tests passed!
```

668 baseline + 2 new = 670. No existing test regressed; the only
existing `dedupeByContent: true` caller is the bootstrap registry-init
audit at `bootstrap.dart:181`, which today lives in its own
single-purpose aggregate (`'system:entry-type-registry'`), so the
refinement is a no-op for the existing test suite. Task 4 will move
that emission to the install-scoped aggregate.

### Step 6 — Analyze

```
Analyzing event_sourcing_datastore...
No issues found! (ran in 0.9s)
```

## Files Touched

- `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart` (10
  inserted, 4 deleted; lines 379-411 of the appendInTxn dedupe block).
- `apps/common-dart/event_sourcing_datastore/test/event_store/dedupe_by_content_entry_type_match_test.dart`
  (new file, 145 lines, 2 tests).
- `PHASE_4.22_WORKLOG.md` — Task 3 marked complete; Task 3 details section
  appended.
- This file (`PHASE4.22_TASK_3.md`).

## Outcome

The dedupe-by-content semantic now matches REQ-d00134-F. Task 4 may
freely consolidate the 10 system-event call sites under a single
install-scoped `source.identifier` aggregate without surprising
dedupe behavior across distinct emission streams.
