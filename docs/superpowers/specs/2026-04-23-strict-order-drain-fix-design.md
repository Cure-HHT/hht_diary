# Strict-Order Drain Semantics Fix (Design Spec)

**Date**: 2026-04-23
**Ticket**: CUR-1154 (new phase on the existing `mobile-event-sourcing-refactor` branch)
**Scope**: Mobile library `apps/common-dart/append_only_datastore` — drain semantics, terminal-status enum, `tombstoneAndRefill` operator recovery primitive.

## 1. Problem

REQ-d00119-D and REQ-d00124-H, as they read before this fix, allow drain to "continue past exhausted" FIFO rows: when drain encounters a terminally-failed head row, it skips the row and attempts the next pending row in the same invocation. Per-row `rehabilitate` (REQ-d00132) has the same property: `rehabilitate(#60)` while #59 is still exhausted causes #60 to ship first.

For destinations that commit events in receipt order — Rave-style EDCs, portal ingestion endpoints that do not re-sort by `sequence_number` before commit — this out-of-order delivery is silent corruption. The destination has no mechanism to detect the skew because it never sees the gap; it commits what arrives. A downstream investigator reconciling events against `sequence_number` finds the ordering broken with no library-level breadcrumb.

Phase 4.6's `DemoDestination` reproducer exhibits the drift: rehabilitate an exhausted Secondary row #60 while #59 is still exhausted, observe Secondary ships #60 before #59.

## 2. Design

Strict-order FIFO delivery is the sole semantics. One operator recovery primitive — `tombstoneAndRefill` — covers all wedge-recovery flows.

### 2.1 Terminal-status enum

`FinalStatus` holds three terminal values: `sent`, `wedged`, `tombstoned`. `FifoEntry.finalStatus` is typed `FinalStatus?`; `null` represents the pre-terminal state where the row is a candidate for drain to attempt.

- `sent` — drain successfully delivered the row's `wire_payload`.
- `wedged` — drain has exhausted its retry budget on the row (via `SendPermanent` or `SendTransient` at `SyncPolicy.maxAttempts`). Drain halts at the first wedged row in `sequence_in_queue` order.
- `tombstoned` — the operator declared the row's `wire_payload` permanently undeliverable via `tombstoneAndRefill`. Drain treats the row as terminal-passable and continues to the next row.

### 2.2 Drain halt rule

`readFifoHead(destId)` returns the first row whose `final_status` is `null` or `wedged`; rows with `final_status` in `{sent, tombstoned}` are skipped. When the returned row's `final_status` is `wedged`, drain returns without calling `destination.send`. When it is `null`, drain attempts it subject to backoff.

Terminal-passable statuses are `{sent, tombstoned}`. `wedged` is the sole blocking terminal state.

### 2.3 `tombstoneAndRefill(destId, fifoRowId)` — operator recovery

A destination wedged at its head cannot make drain progress. `tombstoneAndRefill` is the sole operator recovery primitive.

Precondition: `fifoRowId` identifies the current head of the destination's FIFO (the row `readFifoHead` would return). Target's `final_status` is therefore `null` or `wedged`.

Atomic cascade inside one storage transaction:

- Target's `final_status` transitions to `tombstoned`; `attempts[]` and all other fields preserved.
- Every row with `sequence_in_queue > target.sequence_in_queue` AND `final_status IS null` is deleted.
- `fill_cursor` rewinds to `target.event_id_range.first_seq - 1`.

Post-cascade: the next `fillBatch` re-promotes the events covered by the tombstoned target AND by the deleted trail into fresh FIFO rows, built against the current transform and destination state. Events on the event log are not abandoned; the tombstoned row is the permanent audit artifact of the specific `wire_payload` that failed.

Returns `TombstoneAndRefillResult { String targetRowId, int deletedTrailCount, int rewoundTo }`.

### 2.4 `sequence_in_queue` monotonic invariant

Per-destination `sequence_in_queue` is assigned monotonically at row insertion from a counter that never rewinds and never reuses values when a row is deleted. A gap in `sequence_in_queue` across surviving rows is the audit signal that one or more rows were deleted from the FIFO store. The only code path that deletes FIFO rows is the cascade above.

### 2.5 Multi-Destination pattern for per-topic ordering isolation

A destination's backing sink often needs per-topic wedge isolation: a wedge in one event category must not block delivery of unrelated categories to the same sink. The intended pattern is to register multiple `Destination` instances with disjoint `SubscriptionFilter`s against the same underlying sink. Each `Destination` owns its own FIFO and its own strict-order wedge; one wedged FIFO leaves the others draining normally. The library's uniqueness of `destination.id` and per-destination `SubscriptionFilter` are the structural support this pattern needs — no additional library primitive is required.

### 2.6 State transition diagram

```text
STATE TRANSITIONS
=================

  [enqueue]           [SendOk]
     v                   v
  +-------+         +---------+
  | null  | ------> |  sent   |    terminal-passable
  +-------+         +---------+
      |
      | [SendPermanent]
      | [SendTransient at maxAttempts]
      v
  +---------+
  | wedged  |   blocking terminal; drain halts here
  +---------+
     |
     | [tombstoneAndRefill on wedged head]
     v
  +-------------+
  | tombstoned  |   terminal-passable
  +-------------+

  null head also transitions directly to tombstoned when an
  operator runs tombstoneAndRefill on a pending (null) head.
  attempts[] is preserved on the target regardless of starting
  state.

  Adjacent to a tombstoneAndRefill target: null trail rows are
  DELETED in the same transaction (their attempts[] is always
  empty under strict-order, so deletion is lossless).

  fill_cursor rewinds to target.event_id_range.first_seq - 1 on
  tombstoneAndRefill, so events in the tombstoned target and in
  the deleted trail are re-promoted by the next fillBatch into
  fresh rows.
```

## 3. Out of scope

- `blockOnExhaust` flag or any non-strict-order mode. No current destination requires out-of-order delivery, and `fill_cursor`'s scalar shape makes a generic non-strict cascade impossible (see brainstorm notes in the deferred-items memory).
- Event-level permanent exclusion from a destination. Achieved caller-side via `SubscriptionFilter` mutation.
- `AppendOnlyDatastore` config-as-events (boot-time consistency and config-change audit trail). Separate ticket; captured in the project's deferred-items memory.
- Transform-bug-specific recovery tooling. Operators handle transform bugs by deploying a fix and running `tombstoneAndRefill` on the wedged head; `fillBatch` rebuilds with the fixed transform.

## 4. Specification changes

### 4.1 REQ-d00119 (Per-Destination FIFO Queue Semantics)

**Assertion C**: `final_status` is `null` OR one of `{sent, wedged, tombstoned}`. `null` means "not yet terminal"; the three enum values are the complete set of terminal states.

**Assertion D**: a row whose `final_status` has become non-null SHALL NOT be deleted from its FIFO store (retained forever as audit record).

**New assertion E**: `sequence_in_queue` SHALL be assigned monotonically at row insertion from a per-destination counter that SHALL NOT rewind and SHALL NOT reuse values when a row is deleted. A gap in `sequence_in_queue` between two surviving rows is the audit signal that one or more rows were deleted from the FIFO store (the only code path that deletes FIFO rows is REQ-d00144-C).

### 4.2 REQ-d00124 (Per-Destination FIFO Drain Loop)

**Assertion A**: `readFifoHead(destId)` SHALL return the first row in `sequence_in_queue` order whose `final_status` is `null` or `wedged`; rows whose `final_status` is `sent` or `tombstoned` SHALL be skipped. When the destination's FIFO has no such row, `readFifoHead` SHALL return `null` and `drain` SHALL return without calling `destination.send`.

**Assertion D**: On `SendPermanent`, drain SHALL call `markFinal(id, entry_id, FinalStatus.wedged)`.

**Assertion E**: On `SendTransient` where `attempts.length + 1 >= SyncPolicy.maxAttempts`, drain SHALL call `markFinal(id, entry_id, FinalStatus.wedged)`.

**Assertion H**: Strict FIFO order. Terminal-passable statuses are `{sent, tombstoned}`. `wedged` is the sole blocking terminal state; drain SHALL return without calling `destination.send` whenever `readFifoHead` returns a row whose `final_status` is `wedged`. Recovery from a wedged head requires `tombstoneAndRefill` (REQ-d00144).

### 4.3 REQ-d00144 (NEW) — `tombstoneAndRefill` Operation

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01001

#### Rationale

A destination whose head row is wedged cannot make drain progress (REQ-d00124-H). `tombstoneAndRefill` is the recovery primitive: the operator declares the bundle at the FIFO head permanently undeliverable as-built — its wire bytes were malformed because of a transform bug that has since been fixed, or its content was rejected by the destination until a server-side change landed, or (in the case of a `null` head) the operator knows the bundle will never succeed and wants to short-circuit retry-exhaustion. The library archives that row as a tombstone preserving its `attempts[]` as the audit record of the delivery attempt, clears the pending trail that had been building up behind it, and rewinds `fill_cursor` so the next `fillBatch` rebuilds the events covered by the tombstoned target AND by the deleted trail into fresh bundles against the current transform and destination state.

The events in the tombstoned row are not abandoned — they remain on the event log and are re-queued by the next `fillBatch` into a new FIFO row whose bytes reflect the current code. The tombstoned row is strictly a bundle-level audit artifact: "this specific payload was attempted N times and failed; the same events have been re-shipped via a different payload." Requiring the target to be the FIFO's current head keeps the cascade coherent: earlier rows are all terminal-passable (`sent` or `tombstoned`), so rewinding `fill_cursor` past the target is guaranteed to reinstate only events whose latest FIFO row is either the tombstoned target or one of the deleted trail rows.

When the operator's fix is valid, the fresh rows drain through successfully. When the fix is invalid, the fresh rows reproduce the original failure and the operator runs another `tombstoneAndRefill` — honest signaling, not silent data loss. Trail rows behind the head always have empty `attempts[]` under strict-order drain (drain processes rows sequentially and only ever holds one in flight at a time, so any delivery attempts are recorded on the head itself); deleting them preserves the full audit history that ever existed for them. REQ-d00127's missing-row tolerance handles the narrow race where drain is mid-`send` on the head at the moment this operation runs.

`tombstoneAndRefill` is the sole recovery primitive for the drain loop and the sole code path by which a FIFO row reaches `final_status == tombstoned`.

#### Assertions

A. `tombstoneAndRefill(String destId, String fifoRowId)` SHALL throw `ArgumentError` unless `fifoRowId` identifies the current head of the destination's FIFO — equivalently, the row that `readFifoHead(destId)` (REQ-d00124-A) would return. The head's `final_status` is therefore `null` or `wedged`.

B. Inside one storage transaction, the target row's `final_status` SHALL transition to `tombstoned`; its `attempts[]` and all other fields SHALL be preserved unchanged.

C. Inside the same transaction, every FIFO row whose `sequence_in_queue > target.sequence_in_queue` AND whose `final_status IS null` SHALL be deleted from the destination's FIFO store.

D. Inside the same transaction, `fill_cursor` SHALL be rewound to `target.event_id_range.first_seq - 1`, so the next `fillBatch` resumes promotion at the first event the target had covered.

E. The call SHALL return a `TombstoneAndRefillResult { String targetRowId, int deletedTrailCount, int rewoundTo }`.

F. A subsequent `fillBatch(destination)` invocation SHALL re-promote the events covered by the tombstoned target AND by the deleted trail into fresh FIFO rows built against the current transform and destination state.

### 4.4 REQ-d00122 (Destination Contract) — rationale addition

Append one rationale paragraph documenting the multi-Destination pattern for per-topic ordering isolation (section 2.5 of this design). Assertions unchanged.

### 4.5 REQ-d00123-E (Retry lifetime cap)

Assertion body reads: "an entry that accumulates this many `attempts` on its log SHALL be marked `wedged` on the next transient-failure drain step, wedging its FIFO."

### 4.6 REQ-d00127 (markFinal / appendAttempt tolerance) — rationale update

The rationale's race list becomes "drain/tombstoneAndRefill or drain/delete" — the only concurrent operations that can remove a row during drain's send-and-write sequence.

### 4.7 REQ-d00131 and REQ-d00132

Both REQs are removed from `spec/dev-event-sourcing-mobile.md`. `spec/INDEX.md` rows for REQ-d00131 and REQ-d00132 are removed; a REQ-d00144 row is added.

## 5. Implementation

### 5.1 Code delta

Delete:

- `apps/common-dart/append_only_datastore/lib/src/ops/unjam.dart`
- `apps/common-dart/append_only_datastore/lib/src/ops/rehabilitate.dart`
- `apps/common-dart/append_only_datastore/test/ops/unjam_test.dart`
- `apps/common-dart/append_only_datastore/test/ops/rehabilitate_test.dart`

Add:

- `apps/common-dart/append_only_datastore/lib/src/ops/tombstone_and_refill.dart` — implements REQ-d00144 A–F.
- `apps/common-dart/append_only_datastore/test/ops/tombstone_and_refill_test.dart` — per-assertion tests.

Update:

- `lib/src/destinations/destination_schedule.dart` — `UnjamResult` dropped; `TombstoneAndRefillResult` defined.
- `lib/src/storage/storage_backend.dart` — `FinalStatus` enum is `{sent, wedged, tombstoned}`; `FifoEntry.finalStatus` is `FinalStatus?`; `readFifoHead` contract revised to return first row with `final_status` in `{null, wedged}`; doc comments refer to `tombstoneAndRefill` only.
- `lib/src/storage/sembast_backend.dart` — implementation reflects `FinalStatus?` and revised `readFifoHead` predicate; doc comments updated.
- `lib/src/drain.dart` (or equivalent drain implementation file) — drain halts at wedged head (returns without calling `send` when `readFifoHead` returns a wedged row).
- `example/lib/widgets/fifo_panel.dart` — single TombstoneAndRefill button on head row (visible when head `final_status` is `null` or `wedged`).
- `example/USER_JOURNEYS.md` — strict-order wedge + `tombstoneAndRefill` recovery flow documented.

Global sweep across the library and example app: `== FinalStatus.pending` becomes `== null`; `FinalStatus.exhausted` becomes `FinalStatus.wedged`.

### 5.2 Tests

Unit tests per assertion, co-located with ops and storage:

- REQ-d00119-E: monotonic `sequence_in_queue`; deletion leaves a permanent gap; `fillBatch` continues the counter past gaps.
- REQ-d00124-A: `readFifoHead` returns first row with `final_status` in `{null, wedged}`; skips `{sent, tombstoned}`.
- REQ-d00124-H: drain halts at wedged head; trail rows are never attempted.
- REQ-d00144-A: non-head targets, `sent` targets, `tombstoned` targets, and missing rows throw `ArgumentError`.
- REQ-d00144-B/C/D: target transition to `tombstoned`, `attempts[]` preserved, trail deleted, `fill_cursor = target.event_id_range.first_seq - 1` post-cascade.
- REQ-d00144-E: result record fields match invariants.
- REQ-d00144-F: next `fillBatch` re-promotes target events AND trail events into fresh rows.

Regression test (two-destination integration):

- Events with `sequence_number` 59 and 60 are enqueued to a Secondary destination whose `send` is configured to `SendPermanent` on #59.
- Pre-fix behavior: drain continues past #59 and ships #60 before #59 is resolved.
- Post-fix assertion: drain halts at #59; #60 stays `null` until operator runs `tombstoneAndRefill(#59)`; after operator action + next `fillBatch` + drain cycle, fresh rows deliver both #59's and #60's events in sequence order.

Demo-app smoke:

- Phase 4.6's `DemoDestination` reproducer exercisable from the example app's `FifoPanel`.
- UI flow: trigger wedge on a specific row, observe drain halted (later rows stay pending), invoke TombstoneAndRefill from the button on the wedged head, observe tombstoned row preserved + `sequence_in_queue` gap visible in the panel, observe fresh rows appear and drain delivers.

## 6. Risks and open questions

None at design-review time.

One implementation-time caveat: the regression test's strict-order assertion depends on a mock destination that records receipt order; the mock's correctness should be verified independently (a buggy mock would silently pass either pre-fix or post-fix behavior).
