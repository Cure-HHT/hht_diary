# Phase 4.22 Task 6 — SubscriptionFilter.includeSystemEvents + lift fill_batch / historical_replay hard-drops (REQ-d00128-J, REQ-d00154-F)

## Goal

Move the per-destination admission decision for reserved system entry
types out of two hard-coded guards in `fillBatch` and `runHistoricalReplay`
and into `SubscriptionFilter.matches` itself, controlled by a new opt-in
flag `includeSystemEvents` (default `false`).

After this task, `destination.filter.matches` is the single source of
truth for "does this destination admit this event." The two sync-side
filter chains (live promotion in `fillBatch` and one-shot promotion in
`runHistoricalReplay`) defer entirely to `matches`. A destination that
needs forensic / audit visibility on an upstream node's local-state
mutations sets `includeSystemEvents: true`; every other destination
inherits the safe default and continues to receive only user events.

REQs implemented: **REQ-d00128-J, REQ-d00154-F**.

## TDD Sequence

### Step 1 — Read the current `SubscriptionFilter`

`SubscriptionFilter` was a 4-axis class with `entryTypes`, `eventTypes`,
and `predicate` fields, all optional. No `==` / `hashCode` / `toString`,
so adding a new field required only the field, the constructor
parameter, and the `matches` update — nothing to keep in sync.

`kReservedSystemEntryTypeIds` lives in
`lib/src/security/system_entry_types.dart`; already exported from the
public API. Imports straightforwardly into the filter file.

### Step 2 — Locate the hard-drop guards

```text
lib/src/sync/fill_batch.dart:125:
    if (kReservedSystemEntryTypeIds.contains(e.entryType)) return false;
lib/src/sync/historical_replay.dart:111:
    if (kReservedSystemEntryTypeIds.contains(e.entryType)) return false;
```

One hit each, both inside the `where(...)` filter chain. The surrounding
comment block in each file framed system audits as "never enqueued to
user destinations" — that framing is replaced rather than updated; in
final-state voice the chain admission is just a `matches` call, with no
reference to the now-removed guard.

### Step 3 — Write failing tests

Two new test files added.

**a. `test/destinations/subscription_filter_system_events_test.dart`** —
5 tests on `SubscriptionFilter.matches` directly:

- `REQ-d00128-J: includeSystemEvents=false rejects system events regardless of entryTypes`
- `REQ-d00128-J: includeSystemEvents=true admits system events even with empty entryTypes`
- `REQ-d00128-J: includeSystemEvents=true still applies entryTypes for user events`
- `REQ-d00128-J: default includeSystemEvents is false`
- `REQ-d00154-F: includeSystemEvents=true admits every reserved system entry type` (loops over `kReservedSystemEntryTypeIds` so adding a new reserved id automatically extends coverage)

**b. `test/sync/fill_batch_system_events_test.dart`** — 2 integration
tests using `bootstrapAppendOnlyDatastore` to seed real system audits:

- `REQ-d00128-J: includeSystemEvents=true admits system events through fillBatch; includeSystemEvents=false drops them` — registers an audit-mirror destination (`includeSystemEvents: true`, `entryTypes: []`) and a user-stream destination (default filter), rewinds schedules, runs `fillBatch` to quiescence, asserts FIFO contents.
- `REQ-d00128-J: includeSystemEvents=false rejects system events even if entryTypes contains a reserved id` — guards against the misconfiguration where a destination accidentally lists a reserved id in `entryTypes`; the flag still wins, system events are dropped.

### Step 4 — Run tests; expect failure

Compile failure as predicted: `Error: No named parameter with the name 'includeSystemEvents'`.

### Step 5 — Extend `SubscriptionFilter`

Added the `includeSystemEvents: bool` field (default `false`) and the
matching constructor parameter. Updated `matches` to dispatch reserved
system entry types through the flag (admit on `true`, reject on
`false`); user entry types continue to consult `entryTypes`. The
`eventTypes` and `predicate` constraints still apply to whatever cleared
the entry-type gate, so a system-event subscriber can refine further
by event-type or predicate.

Implementation detail: the dispatch is structured as

```dart
if (kReservedSystemEntryTypeIds.contains(event.entryType)) {
  if (!includeSystemEvents) return false;
  // System event admitted past the entry-type gate; eventTypes /
  // predicate constraints still apply.
} else {
  final entryTypes = this.entryTypes;
  if (entryTypes != null && !entryTypes.contains(event.entryType)) {
    return false;
  }
}
// ... eventTypes and predicate unchanged
```

This makes the two paths visibly disjoint in source (system route
short-circuits on the flag; user route consults `entryTypes`), which
matters because the contract per REQ-d00128-J says the entry-type gate
for system events is the flag, not the list.

Class-level dartdoc rewritten in final-state voice to describe the
four-axis composition (system opt-in + entryTypes + eventTypes +
predicate) rather than the three-axis form.

### Step 6 — Lift the hard-drop in `fillBatch`

Removed the line

```dart
if (kReservedSystemEntryTypeIds.contains(e.entryType)) return false;
```

from the `inWindow` `where(...)` chain. The remaining filter is
time-window + `destination.filter.matches(e)`. Removed the now-unused
`system_entry_types.dart` import. Rewrote the surrounding comment in
final-state voice (annotated `// Implements: REQ-d00128-J`).

### Step 7 — Lift the hard-drop in `runHistoricalReplay`

Symmetric change in `lib/src/sync/historical_replay.dart`. Same removal,
same import cleanup, same final-state comment treatment.

### Step 8 — Run tests; expect green

```text
00:00 +7: All tests passed!
```

All 7 new tests pass.

### Step 9 — Full suite

```text
00:05 +695: All tests passed!
```

688 baseline + 7 new = 695. Zero regressions, because every existing
destination constructs `SubscriptionFilter(...)` without an
`includeSystemEvents` argument and inherits the default `false`. That
preserves the prior end-to-end behavior: system audits never reached
user destinations under the hard-drop, and now they are still rejected
by `matches` — same outcome, decided in a different layer.

Example test suite (`event_sourcing_datastore/example`): 81 / 81 pass,
no regressions.

### Step 10 — Cleanup grep

```bash
grep -rnE "kReservedSystemEntryTypeIds.contains" \
    apps/common-dart/event_sourcing_datastore/lib/src/sync/
```

Zero hits. The bootstrap-side guard
(`lib/src/bootstrap.dart:98`) is unrelated — it rejects caller-supplied
entry-type definitions whose id collides with a reserved id at
registration time, not at FIFO admission time.

### Step 11 — Analyze

```text
Analyzing event_sourcing_datastore...
No issues found! (ran in 1.4s)
```

## Files Touched

### lib/

- `apps/common-dart/event_sourcing_datastore/lib/src/destinations/subscription_filter.dart`
  (~50 lines diff: new field, new import, rewritten `matches`,
  rewritten class-level dartdoc).
- `apps/common-dart/event_sourcing_datastore/lib/src/sync/fill_batch.dart`
  (-1 import, -1 hard-drop line, comment block rewritten; ~10 lines diff).
- `apps/common-dart/event_sourcing_datastore/lib/src/sync/historical_replay.dart`
  (-1 import, -1 hard-drop line, comment block rewritten; ~10 lines diff).

### test/ — new files

- `apps/common-dart/event_sourcing_datastore/test/destinations/subscription_filter_system_events_test.dart` (5 tests, ~100 lines).
- `apps/common-dart/event_sourcing_datastore/test/sync/fill_batch_system_events_test.dart` (2 tests, ~210 lines).

### worklog / task file

- `PHASE_4.22_WORKLOG.md` — Task 6 checkbox flipped; Task 6 details
  section appended.
- This file (`PHASE4.22_TASK_6.md`).

## Outcome

`SubscriptionFilter.matches` is now the single authority on
per-destination admission for both user and system events. Forensic /
audit-mirror destinations opt in via `includeSystemEvents: true` (REQ-
d00154-F bridging path); every other destination inherits the safe
default. The two sync-side filter chains (`fillBatch` for live
promotion, `runHistoricalReplay` for setStartDate replay) defer
entirely to `matches`; no hidden hard-drops remain in the sync path.

This unlocks Task 7 (materialize-on-ingest) and Task 8
(receiver-stays-passive invariant) — both of which need to reason about
which destinations admit which events without consulting a separate
hard-coded reserved-id list.
