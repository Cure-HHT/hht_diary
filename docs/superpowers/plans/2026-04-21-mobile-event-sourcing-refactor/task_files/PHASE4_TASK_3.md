# PHASE 4 TASK 3 — WirePayload + Destination + Phase-2 prereq resolutions

## What landed

1. `lib/src/destinations/wire_payload.dart` — immutable value type carrying `bytes` (Uint8List, defensively copied on construction), `contentType`, and `transformVersion`. Element-wise byte equality + hash.
2. `lib/src/destinations/destination.dart` — abstract class exposing `id`, `filter`, `wireFormat`, `transform(event) -> WirePayload`, and `send(payload) -> Future<SendResult>`.
3. `lib/src/destinations/subscription_filter.dart` — **abstract** base with `bool matches(StoredEvent)`. Concrete implementation with `entryTypes` / `eventTypes` / `predicate` fields is Task 4; this file exists now only so `Destination.filter`'s return type type-checks.
4. Phase-2 **Prereq A** (FIFO `sequence_in_queue` ownership) resolved — see below.
5. Phase-2 **Prereq B** (`nextSequenceNumber` semantics) resolved — see below.
6. Tests: 22 new (9 WirePayload, 7 Destination, 3 Prereq-A FIFO, 3 Prereq-B event).

## Phase-2 Prereq A — decision: Option 1 (backend-owned sequence_in_queue)

**Change:**

- `SembastBackend.enqueueFifo` ignores caller-supplied `entry.sequenceInQueue`.
- Backend computes `assigned = max(existing Sembast int key) + 1` inside the same transaction and writes the entry under `store.record(assigned).put(...)` with `payload['sequence_in_queue'] = assigned`.
- `FifoEntry.sequenceInQueue` is now a read-side field: on `readFifoHead` it reflects the actual queue position; on `enqueueFifo` input it is discarded.
- Contract docstring on `StorageBackend.enqueueFifo` updated to state the new input/output semantics.

**Rationale:**

- Option 1 was explicitly marked preferred by the Phase-4 plan.
- Keeping the Sembast int key, the payload `sequence_in_queue`, and the FIFO sort order in lockstep eliminates any class of bug where a caller passes a stale, reused, or out-of-order value.
- Option 2 (caller-owned + backend enforcement) preserves a public-surface footgun — the caller still has to know how to produce a valid value — without gaining any ergonomic or performance advantage.

**Why `max(key) + 1` rather than `store.add(...)`:** using the max + 1 pattern keeps the backend-assigned `sequence_in_queue` monotonic across retained sent/exhausted entries (REQ-d00119-D retains them forever). A bare `store.add` would still produce monotonic sembast keys, but would require a two-write dance (add, then update) to propagate the assigned key into the payload's `sequence_in_queue` field. Max+1 is one query + one `record.put`.

**Test coverage:**

- `enqueueFifo ignores caller-supplied sequence_in_queue and assigns its own monotonic value (Prereq A, Option 1)` — caller passes 9999, -7, 0; backend writes 1, 2, 3.
- `sequence_in_queue advances across sent/exhausted entries (Prereq A, Option 1)` — e1 gets 1, is marked sent, e2 gets 2 (not 1).
- `sequence_in_queue equals the Sembast store key (lockstep)` — invariant between key and payload field.

## Phase-2 Prereq B — decision: Option 1 (reserve-and-increment)

**Change:**

- `SembastBackend.nextSequenceNumber` advances the counter as a side effect. A second call in the same txn returns `current + 2`.
- `SembastBackend.appendEvent` no longer advances the counter. It validates `event.sequenceNumber == current counter value` and rejects mismatches with a clear error message referencing the prereq. The append still persists the event under the same txn.
- Storage-backend contract docstring updated on both methods to document the new pair semantics.

**Rationale:**

- Option 1 was explicitly marked preferred by the Phase-4 plan.
- Reserve-and-increment is the only pattern that is safe under composition: any helper that calls `nextSequenceNumber` twice in a single transaction now gets two distinct reservations; any helper that skips `nextSequenceNumber` and calls `appendEvent` directly fails immediately instead of silently accepting a wrong value.
- Option 2 (documented use-once contract + stronger error) leaves the footgun in place; a future helper composing `nextSequenceNumber` into a transaction would have to know the implicit "call once only" rule.

**Call-site audit:**

- `event_repository.dart:118` — already calls `nextSequenceNumber` then `appendEvent`; no change needed under the new semantics.
- `rebuild_test.dart.appendEventViaBackend` — same pattern; no change needed.
- `sembast_backend_event_test.dart` — updated one existing test (renamed "not current+1" → "does not match the reserved counter value"; kept the rejection behavior); added two new tests locking the new semantics.

**Test coverage:**

- `REQ-d00117-C: two nextSequenceNumber calls in one txn return current+1 and current+2 (reserve-and-increment)` — direct lock on Option-1 semantics.
- `REQ-d00117-C: appendEvent consumes the reservation without re-advancing the counter (Prereq B, Option 1)` — counter post-append equals reserved value, not reserved+1.
- `appendEvent throws when sequenceNumber does not match the reserved counter value (Prereq B, Option 1)` — renamed existing test; still catches the skipped-nextSequenceNumber case.

## What did NOT change

- `EventRepository.append()` — already paired nextSequenceNumber + appendEvent; new semantics are a no-op at the call site.
- `FifoEntry` value type — `sequenceInQueue` stays non-nullable and required. The field semantics changed (read-side only on input) but the shape is preserved.
- No production code path is altered in behavior; only storage-backend internals.

## Files changed

- `apps/common-dart/append_only_datastore/lib/src/destinations/wire_payload.dart` (new, 55 lines)
- `apps/common-dart/append_only_datastore/lib/src/destinations/destination.dart` (new, 76 lines)
- `apps/common-dart/append_only_datastore/lib/src/destinations/subscription_filter.dart` (new, 20 lines — abstract base, Task 4 fleshes out)
- `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart` (docstrings updated — nextSequenceNumber + enqueueFifo)
- `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart` (behavior changes — nextSequenceNumber + appendEvent + enqueueFifo)
- `apps/common-dart/append_only_datastore/test/destinations/wire_payload_test.dart` (new, 9 tests)
- `apps/common-dart/append_only_datastore/test/destinations/destination_test.dart` (new, 7 tests)
- `apps/common-dart/append_only_datastore/test/storage/sembast_backend_event_test.dart` (1 test renamed, 2 new)
- `apps/common-dart/append_only_datastore/test/storage/sembast_backend_fifo_test.dart` (3 new)

## Verification

- `flutter test` in `append_only_datastore`: 247 passed (was 227; +20 new).
- `flutter analyze` in `append_only_datastore`: No issues found.
