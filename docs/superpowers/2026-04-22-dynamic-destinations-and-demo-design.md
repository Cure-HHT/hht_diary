# Dynamic Destinations and Demo App — Design

**Date:** 2026-04-22
**Status:** Design awaiting implementation
**Ticket:** CUR-1154
**Parent design:** `docs/superpowers/2026-04-21-mobile-event-sourcing-refactor-design.md`
**Scope:** Two new phases inserted between Phase 4 (sync) and Phase 5 (cutover): Phase 4.3 (library additions) and Phase 4.6 (demo app)
**Acceptance spec:** `apps/common-dart/append_only_datastore/example/USER_JOURNEYS.md`

## 1. Summary

Two phases of work on `append_only_datastore`:

- **Phase 4.3 — Library additions and retrofits.** Adds dynamic destination lifecycle (add/remove, time-windowed subscriptions, historical replay on activation, graceful and hard deactivation), a batch-capable FIFO model (each FIFO row is one wire transaction), an unjam/rehabilitate ops toolkit, and three library features pulled forward from Phase 5 (`EntryService`, `EntryTypeRegistry`, `bootstrapAppendOnlyDatastore`). Also retrofits `SyncPolicy` to be injectable. All with TDD. These additions surface enough small changes to Phase 4's as-specced FIFO contract that Phase 4's plan is surgically revised in the same phase-boundary.

- **Phase 4.6 — Demo app.** A Flutter Linux-desktop sandbox at `apps/common-dart/append_only_datastore/example/` that exercises every library feature end-to-end with live controls: demo_note lifecycle (start/complete/edit/delete), three non-DiaryEntry action events (Red/Green/Blue buttons) demonstrating the CQRS invariant, two+N destinations with connection-state simulation, `SyncPolicy` sliders, schedule editors, batch-size/accumulate-time sliders, unjam, rehabilitate, and hard-delete controls. Nine `USER_JOURNEYS.md` scenarios are the acceptance contract.

Phase 4.3 lands first because the demo depends on it. Phase 4.6 consumes everything Phase 4.3 builds.

## 2. Background

Phase 4 of the parent refactor lands `Destination`, `SubscriptionFilter`, `DestinationRegistry`, `FifoEntry`, `SyncPolicy`, the drain loop, and `sync_cycle()`, with the registry boot-frozen and each FIFO row representing one event's send attempt. None of that machinery has a production caller until Phase 5 wires it in `clinical_diary`. Between Phase 4 green and Phase 5 start, reviewers take the unit tests' word for how the multi-destination fan-out, FIFO ordering, retry behavior, and wedge semantics work — none of which unit tests communicate well to a human reviewer.

Two gaps surface when trying to design a credible demo:

1. **Dynamic destination lifecycle is a product-level requirement that Phase 4 doesn't support.** Real scenarios (a patient using the app buys a backup service; later enrolls in a clinical trial with its own start/end dates; trial ends) need runtime add, time-windowed subscription, historical replay on activation, and graceful deactivation. Boot-time-frozen registration can't model any of that. The work is a compact addition to the core package — adding it now (rather than deferring) keeps Phase 5 focused on integration rather than library work.

2. **The "one event per FIFO row" model in Phase 4's current spec is wrong for destinations with wire-level batch ingest APIs.** If the FIFO is the audit record of what was sent, and sends are batches, then each FIFO row must be a batch. Fixing this after Phase 4 ships per-event FIFOs would be a substantial refactor; better to revise Phase 4's spec surgically and lock the batch model in from the start.

Both gaps are addressed in Phase 4.3. The demo in Phase 4.6 then exercises the full surface.

## 3. Goals

Phase 4.3 makes the following library capabilities available to any consumer:

1. Destinations can be registered dynamically at any time after bootstrap (not just at boot).
2. A destination can be scheduled with an immutable `startDate` and a mutable `endDate`; events outside the window are never enqueued to that destination.
3. Setting a `startDate` on a dormant destination triggers a historical replay: events already in `event_log` with `client_timestamp >= startDate` matching the subscription filter are batched into the destination's FIFO.
4. A destination can be soft-deactivated (`setEndDate(now)`) or hard-deleted (`deleteDestination`), with `allowHardDelete` gated at construction for FDA/audit retention.
5. FIFO rows are per-batch (not per-event); each row carries one wire payload covering one or more events. Batching rule is destination-owned (byte budget, entry count, or whatever internal rule fits the destination's wire API).
6. Drain skips exhausted FIFO rows rather than wedging behind them. A permanent rejection is an audit-logged loss of that batch's events, not an outage for the destination.
7. `unjamDestination(id)` preserves the exhausted audit trail, hard-deletes pending rows, and rewinds `fill_cursor` past exhausted rows so a redeployed batcher can re-batch the same events with new wire bytes.
8. `rehabilitateExhaustedRow(destId, rowId)` (and the bulk variant) flips an exhausted row back to pending for retry without modifying its wire payload — used when the rejection was environmental rather than a code bug.

Phase 4.6 makes the following six invariants (carried over from the original demo design) and three new invariants producible-on-demand by a reviewer in less than two minutes each:

Carried over:
1. DiaryEntry aggregate lifecycle materializes, replays, and drains correctly.
2. Non-DiaryEntry aggregates are in the event log but not the materialized view (CQRS).
3. Events fan out to every destination whose filter matches.
4. Per-destination isolation: rejection storm on one destination leaves others unaffected.
5. Transient disconnect holds events pending, recovers without loss on reconnection.
6. `rebuildMaterializedView()` is lossless and idempotent.

New in Phase 4.6:
7. Adding a destination after events have accumulated, with a past `startDate`, produces a historical replay into that destination's FIFO.
8. Setting `endDate` closes a destination's window: future events do not enqueue; the return code distinguishes `closed` (end <= now) from `scheduled` (end > now).
9. An exhausted batch's wire payload is preserved by unjam; re-batched events produce new FIFO rows with the new `transform_version`; a single exhausted row can be rehabilitated back to pending without touching the others.

## 4. Non-goals

1. **Production-grade UX** on the demo. High-contrast, monospace, black-bg, yellow-headers — dev tool.
2. **Widget tests, golden tests, integration tests against the demo.** Library features carry unit tests; demo is validated visually via USER_JOURNEYS.
3. **Any HTTP, FCM, connectivity-plus, AppLifecycle.** Phase 5. Demo's only trigger is a 1-second `Timer.periodic`.
4. **`PrimaryDiaryServerDestination` or any real destination.** Phase 5.
5. **Widget registry, form widgets, screen updates.** Phase 5.
6. **Portal inbound poll, REQ-d00113 translation.** Phase 5.
7. **At-rest encryption, multi-device conflict resolution.** Carried-over parent non-goals.
8. **Two-phase drain (fillBatch and drain on separate timers).** One timer, one function — see §6.6. Complexity not worth it.
9. **Wire-level batch-send on an unmodified Phase-4 `Destination.send(WirePayload)` contract.** The batch-FIFO model IS the wire-batching mechanism; `WirePayload` bytes contain the whole batch, `send` returns one `SendResult` for the whole batch.
10. **Library-level quarantine of individual events.** Destinations that care about per-event filtering handle it inside their own `transform(List<Event>)`; the library doesn't know.
11. **Re-splitting a partially-failed batch.** `SendPermanent` or terminal `SendTransient` on a 50-event batch marks the whole row exhausted. No attempt to split and retry a subset. Operators resolve by unjamming (new batcher) or rehabilitating (retry same bytes).

## 5. Design decisions

| # | Decision | Rationale |
| --- | --- | --- |
| 1 | **FIFO row = one batch = one wire transaction.** `FifoEntry` carries `event_ids: List<String>` and a single `wire_payload` covering all of them. | The FIFO is the audit log of what was sent; sends are batches; therefore FIFO rows are batches. Per-event FIFOs lose audit-completeness the moment a destination has a batch-ingest API. |
| 2 | **`fill_cursor` per destination in `backend_state`.** Durable watermark: the last `sequence_number` that has been promoted into any FIFO row (pending, sent, or exhausted) for this destination. | App-interrupt recovery: resume batch assembly exactly where we left off. Events sit in `event_log` (durable) until promoted; never in RAM. |
| 3 | **Batching policy is destination-owned** via `canAddToBatch(currentBatch, candidate): bool` and `maxAccumulateTime: Duration`. Library never parses a config. | Destinations differ in their wire API's batch limits (bytes, count, request size). Keep the library's `Destination` interface uniform, let each destination encode arbitrary rules in Dart. |
| 4 | **Drain skips exhausted rows** (`readFifoHead` returns first `pending`; exhausted is inert). | Parent §5 decision #8's "wedge on exhausted head" is a worse failure mode than audit-and-continue: under batching, one poison event can kill a batch of 50, and wedging would block every subsequent event indefinitely. Skip-and-continue gives ops a signal (`anyFifoExhausted` flips) without an outage. Parent §12.1 wedge risk drops dramatically. |
| 5 | **`startDate` is immutable once set; `endDate` is mutable.** Separate `setStartDate` and `setEndDate` methods; each is a standalone command, not two endpoints of a range. | Confirmed semantics: start locks when syncing begins; end can be extended/shortened. They're independent commands, not paired endpoints — you can set endDate without having set startDate. |
| 6 | **Time window compared against `event.client_timestamp`, not `data.effective_date`.** | Stated intent: "real-world date of the event, not the user-supplied date." `client_timestamp` is when the event was first logged on-device — independent of user backdating. Retroactive diary entries for yesterday still enqueue under today's trial window because they were *logged* today. |
| 7 | **`allowHardDelete` per-destination flag, default `false`.** FDA-regulated destinations construct with the default; utility/commercial destinations opt in. | `deleteDestination` removes destination + FIFO; `deactivateDestination` only sets endDate. Callers that want the audit trail preserved use deactivate. Library enforces: `deleteDestination` throws if `allowHardDelete` is false. |
| 8 | **Unjam preserves exhausted rows, rewinds `fill_cursor` to `last_successfully_sent_seq`.** Events in exhausted batches get re-batched by the new code; exhausted audit rows stay untouched. | Matches the stated intent: "retain the record of the batch that wouldn't be accepted, clear the queue behind it, re-queue it in a new way." The events are not lost; the batch-as-wire-record is preserved; the new batcher produces new wire bytes with a new `transform_version`. |
| 9 | **Rehabilitate is a separate operation from unjam.** `rehabilitateExhaustedRow` flips final_status back to pending without changing the wire payload. Used when the remote was temporarily misconfigured. | Orthogonal concerns: unjam = "the code is wrong, redeploy"; rehabilitate = "the remote is now fixed, retry same bytes." Both valuable; neither replaces the other. |
| 10 | **Concurrency model: Dart single-isolate + sembast transaction serialization + `_inFlight` guard on `syncCycle` + `markFinal` tolerates missing row/store.** One concurrency guard added (the missing-row tolerance); everything else falls out of Dart's execution model. | The only genuine race is drain's non-transactional `await send()`: user ops (unjam, delete) can mutate the FIFO while a send is in flight. `markFinal` no-ops on missing targets; the in-flight attempt's result is discarded, which is acceptable for the operations that produce this race (ops commands explicitly accepting audit loss). |
| 11 | **One timer, one function.** `syncCycle` runs `fillBatch(dest)` then `drain(dest)` for each destination per tick. No separate fill-timer. | Simplicity. Fill is cheap when there's nothing to batch; no reason to run on a different cadence than drain. |
| 12 | **SyncPolicy refactored to value object with `SyncPolicy.defaults`.** `drain` and `syncCycle` take an optional `SyncPolicy? policy`. | Demo needs short-backoff values to make retry behavior visible in real time. Retrofit is strictly additive; existing Phase-4 call sites unchanged. |
| 13 | **`EntryService`, `EntryTypeRegistry`, `bootstrapAppendOnlyDatastore` pulled forward from Phase 5 into Phase 4.3.** | The demo is the natural first consumer of `EntryService.record`. If it doesn't use it, it hand-rolls the same atomic-transaction + hash-chain + provenance + no-op-detection logic. Pulling forward: demo exercises these features; Phase 5 shrinks to genuine integration. |
| 14 | **Demo layout and style** (top bar + sync policy bar + 4-plus observation columns + detail drawer; high-contrast black/white/yellow/green/red/magenta/blue state palette at 12%-below-max brightness). | Per 2026-04-22 review of first-draft layout. Dev-tool clarity over style. Demo-UI additions for dynamic destinations fit into the existing column-header area and top-bar system controls. |

## 6. Phase 4.3 — Library work

### 6.1 SyncPolicy retrofit

`apps/common-dart/append_only_datastore/lib/src/sync/sync_policy.dart` becomes a regular class with `final` fields and a `const` constructor. The current Phase-4 static values move to `SyncPolicy.defaults`. `drain()` and `syncCycle()` accept an optional `SyncPolicy? policy` parameter; when null, they resolve to `SyncPolicy.defaults`. All existing call sites in Phase-4 code compile unchanged (they don't pass the param; default kicks in).

### 6.2 Dynamic destination API

On `DestinationRegistry`:

```dart
void addDestination(Destination d);
  // register at any time; destination starts dormant.
  // FIFO store for d.id is created lazily on first enqueue.
  // throws if d.id collides with an existing registered destination.

void setStartDate(String id, DateTime startDate);
  // immutable once set: throws if destination already has a non-null startDate.
  // if startDate <= now(): triggers historical replay synchronously in the
  //   same transaction (walks event_log since startDate, matches filter,
  //   batches via destination's canAddToBatch, enqueues as new FIFO rows).
  // if startDate > now(): no replay; events accumulate normally after wall-clock
  //   crosses startDate.

enum SetEndDateResult { closed, scheduled, applied }

SetEndDateResult setEndDate(String id, DateTime endDate);
  // mutable: can be set, moved later, moved earlier.
  // returns:
  //   closed    — endDate <= now; no new events will enqueue. existing pending
  //               FIFO entries continue to drain.
  //   scheduled — endDate > now; events still enqueue until endDate is reached.
  //   applied   — endDate was changed but relative state (past/future) didn't flip.

void deactivateDestination(String id);
  // shorthand for setEndDate(id, DateTime.now()). returns closed.

void deleteDestination(String id);
  // hard delete: unregisters destination and destroys its FIFO store.
  // throws if Destination.allowHardDelete == false.
  // safe even if FIFO contains pending or exhausted entries (they're destroyed).

Future<UnjamResult> unjamDestination(String id);
  // precondition: destination has endDate set (deactivated).
  //   throws StateError if destination is still active.
  // transaction:
  //   1. hard-delete FIFO rows where final_status == pending.
  //   2. rewind fill_cursor to last_successfully_sent_seq (= max sequence_number
  //      from any row where final_status == sent; -1 if none).
  //   3. exhausted rows stay untouched.
  // returns UnjamResult { deletedPending: int, rewoundTo: int }.

Future<void> rehabilitateExhaustedRow(String destId, String fifoRowId);
  // precondition: row exists; final_status == exhausted.
  // transaction: row.final_status := pending. attempts[] unchanged.
  // drain picks it up on next cycle and may succeed, or mark it exhausted again
  //   (appending a new attempt entry to attempts[]).

Future<int> rehabilitateAllExhausted(String destId);
  // bulk: flips every exhausted row on this destination back to pending.
  // returns count rehabilitated.
```

On `Destination` (interface widened):

```dart
abstract class Destination {
  String get id;
  SubscriptionFilter get filter;
  String get wireFormat;

  /// Flush when the oldest unbatched event reaches this age, even if canAddToBatch
  /// has not returned false. Duration.zero = always flush every event individually.
  Duration get maxAccumulateTime;

  /// Caller should allow destruction of this destination's FIFO store. FDA/audit
  /// destinations leave this false (default).
  bool get allowHardDelete;

  /// Called by fillBatch to ask "may I add this candidate to the current batch?"
  /// Destination decides using whatever internal rule (byte budget, count, etc.).
  /// Return false when full; library flushes and starts a new batch with
  /// candidate as the first entry.
  bool canAddToBatch(List<Event> currentBatch, Event candidate);

  /// Produces one WirePayload covering all events in the batch.
  Future<WirePayload> transform(List<Event> batch);

  Future<SendResult> send(WirePayload payload);
}
```

### 6.3 Batch FIFO model

`FifoEntry` shape updates:

```text
destination_id            string
sequence_in_queue         int, monotonic per destination
event_ids                 List<String>           (one or more)
event_id_range            { first_seq, last_seq }  (convenience for cursor math)
wire_payload              bytes
wire_format               string
transform_version         string
enqueued_at               ISO 8601
attempts                  List<AttemptResult>
final_status              "pending" | "sent" | "exhausted"
sent_at                   ISO 8601 | null
```

Per-destination state added to `backend_state`:

```text
fill_cursor_{destination_id}    int     (last sequence_number promoted into any FIFO row for this dest)
```

### 6.4 fillBatch algorithm

```text
fillBatch(dest):
  # called by syncCycle per tick, per destination.
  # no-op if dest is dormant (startDate is null) or window-closed (endDate < now).
  if dest.startDate == null: return
  if dest.endDate != null and dest.endDate < now(): return

  window_start = dest.startDate
  window_end   = dest.endDate ?? DateTime.farFuture
  window_upper = min(window_end, now())      # only events that exist "now"

  candidates = event_log where
    sequence_number > fill_cursor(dest)
    AND matches dest.subscriptionFilter
    AND event.client_timestamp >= window_start
    AND event.client_timestamp <= window_upper
  if candidates.empty: return

  batch = [candidates.first]                  # always take at least one
  for c in candidates[1..]:
    if dest.canAddToBatch(batch, c):
      batch.add(c)
    else:
      break

  age = now() - batch.first.client_timestamp
  if batch.size == 1 and age < dest.maxAccumulateTime:
    return                                    # wait for a bigger batch or timeout

  wirePayload = await dest.transform(batch)
  (transaction):
    insert FifoEntry { event_ids: batch.ids, wire_payload, ... , final_status: pending }
    fill_cursor(dest) := batch.last.sequence_number
```

### 6.5 Drain algorithm (revised from Phase 4)

```text
drain(destination, {policy = SyncPolicy.defaults}):
  loop:
    head = backend.readFifoHead(destination.id)   # first pending; exhausted invisible
    if head is None: return
    if backoff_not_elapsed(head, policy): return
    attempt = await destination.send(head.wire_payload)
    # appendAttempt and markFinal tolerate missing row/store:
    await backend.appendAttempt(destination.id, head.entry_id, attempt)
    match attempt:
      SendOk:          await backend.markFinal(destination.id, head.entry_id, sent)
                       continue
      SendPermanent:   await backend.markFinal(destination.id, head.entry_id, exhausted)
                       continue    # CHANGED: used to return/wedge; now skips
      SendTransient:
        if head.attempts.length + 1 >= policy.maxAttempts:
          await backend.markFinal(destination.id, head.entry_id, exhausted)
          continue
        return                                # backoff; next tick re-enters
```

Note the `continue` after `SendPermanent` (parent §8.3 used `return` here). This is the inversion of parent decision #8. FIFOs no longer wedge on content rejection.

### 6.6 Concurrency model

Dart's single-isolate execution, combined with sembast's transaction serialization, eliminates most categories of race condition for free. The only genuine race is drain's non-transactional network `await`:

```text
drain:
  (tx 1) readFifoHead                       # transactional
  await dest.send(wirePayload)              # NOT in a transaction; takes seconds
  (tx 2) appendAttempt + markFinal          # transactional
```

Between tx1 and tx2, a user-initiated operation (unjam, delete, rehabilitate) may transact against the FIFO. The guard: **`StorageBackend.markFinal` and `appendAttempt` are documented as no-op on a missing row or missing store.** The in-flight attempt's audit record is then lost along with the destination it belonged to, which is acceptable for the operations that produce this race (unjam and delete explicitly accept this loss; the race window is bounded by the network call duration).

All other potential races serialize cleanly:
- Two `syncCycle` ticks overlapping: existing `_inFlight` guard.
- `EntryService.record` mid-cycle: sembast serializes writes.
- `setStartDate` with historical replay during an in-flight drain: serializes via sembast transactions.
- UI reads of `ValueNotifier.value` during mutations: atomic per Dart spec.

### 6.7 EntryService, EntryTypeRegistry, bootstrap (pulled forward from Phase 5)

These three deliverables keep the Phase-5 contracts as originally planned:

- `EntryService.record({entryType, aggregateId, eventType, answers, checkpointReason?, changeReason?})`: the sole write API. Atomic transaction over event append + materializer upsert. No-op detection via content-hash comparison with the most recent event on the same aggregate. Rejects unregistered `entryType`s. **Note:** under the batch-FIFO model, the write transaction does NOT fan out to FIFOs synchronously — that happens in `fillBatch` on the next cycle. Post-write, `EntryService.record` kicks `syncCycle` fire-and-forget.
- `EntryTypeRegistry`: typed registry of `EntryTypeDefinition` instances. Populated by `bootstrapAppendOnlyDatastore`. `EntryService.record` consults it for validation.
- `bootstrapAppendOnlyDatastore({backend, entryTypes, destinations})`: single init point; registers entry types first, then destinations. Destination-id collision throws.

### 6.8 Dev-spec assertions to add

Numbers claimed at implementation time via `discover_requirements("next available REQ-d")`. Writing all to `spec/dev-event-sourcing-mobile.md`:

- **REQ-ENTRY** — `EntryService.record` contract (assertions A-I, as drafted in `PLAN_PHASE5_cutover.md` Task 2; moved to Phase 4.3). One change: assertion D becomes "atomic transaction over event append + materializer upsert + sequence-counter bump; FIFO fan-out is deferred to `fillBatch` on the next `syncCycle` tick" — reflecting the batch model.
- **REQ-BOOTSTRAP** — as drafted in Phase 5 (A-D); moved to Phase 4.3.
- **REQ-SYNCPOLICY-INJECTABLE** — `SyncPolicy` is a value object with `const` defaults; `drain` and `syncCycle` accept an optional override.
- **REQ-DYNDEST** — `addDestination`, `setStartDate` (immutable), `setEndDate` (mutable), `deactivateDestination`, `deleteDestination` (gated by `allowHardDelete`). Time window uses `event.client_timestamp`. Collision detection on `id`.
- **REQ-REPLAY** — `setStartDate` with past-or-present value triggers synchronous historical replay in the same transaction. Driven by `fillBatch` from `fill_cursor = -1` upward.
- **REQ-BATCH** — `Destination.canAddToBatch`, `maxAccumulateTime`, `transform(List<Event>)`. `FifoEntry.event_ids` is a list; `wire_payload` covers the whole batch. Batch-close-by-size-or-time.
- **REQ-UNJAM** — preconditions (destination deactivated), pending deletion, exhausted preservation, rewind to last_successfully_sent_seq.
- **REQ-REHAB** — single-row and bulk variants; preserves attempts[]; may be called on an active destination.
- **REQ-SKIPMISSING** — `markFinal` and `appendAttempt` are no-ops on missing row or missing store. Covers the drain-mid-flight race.

All new assertions get `// Implements: REQ-xxx-Y` markers at per-function granularity per the plan README's convention. All new tests get `// Verifies: REQ-xxx-Y` markers.

## 7. Phase 4.6 — Demo app

### 7.1 Scope

Flutter Linux-desktop sandbox at `apps/common-dart/append_only_datastore/example/`. Single entry point (`lib/main.dart`) bootstraps `append_only_datastore`, constructs two `DemoDestination` instances (Primary, Secondary), starts a 1-second `Timer.periodic` driving `syncCycle(policy: demoPolicy)`. Everything else is UI.

### 7.2 Package layout

```text
apps/common-dart/append_only_datastore/
└── example/
    ├── pubspec.yaml                       # publish_to: none; dependencies: append_only_datastore: {path: ../}
    ├── analysis_options.yaml              # inherits project root
    ├── README.md                          # one-paragraph orientation + how-to-run
    ├── USER_JOURNEYS.md                   # acceptance spec, nine journeys
    ├── linux/                             # flutter create output; desktop scaffold only
    ├── lib/
    │   ├── main.dart                      # runApp; constructs backend, policy, destinations; starts timer
    │   ├── demo_types.dart                # inline EntryTypeDefinition for demo_note + Red/Green/Blue
    │   ├── demo_destination.dart          # DemoDestination class
    │   ├── demo_sync_policy.dart          # DemoSyncPolicy defaults and ValueNotifier binding
    │   ├── app_state.dart                 # ChangeNotifier: selection, connection state, slider values
    │   ├── app.dart                       # root widget; Scaffold with top bar + observation grid
    │   └── widgets/
    │       ├── top_action_bar.dart        # demo_note fields + lifecycle buttons + actions + system
    │       ├── sync_policy_bar.dart       # five SyncPolicy sliders bound to app_state
    │       ├── materialized_panel.dart    # diary_entries list
    │       ├── event_stream_panel.dart    # event_log list across all aggregate_types
    │       ├── fifo_panel.dart            # one instance per destination; header has schedule + batch + connection + sendLatency + ops
    │       ├── add_destination_dialog.dart # modal for adding a destination at runtime
    │       ├── detail_panel.dart          # right-most; populated by app_state.selectedId
    │       └── styles.dart                # DemoColors, DemoText, demoBorder (12%-below-max palette)
    └── test/
        └── app_state_test.dart            # pure-Dart unit tests on state logic
```

### 7.3 UI

**Top action bar** (two rows):
- Row 1: `demo_note` label + title/body/mood fields + [Start] [Complete] [Edit selected] [Delete selected].
- Row 2: `actions` label + [RED] [GREEN] [BLUE] ... spacer ... `system` label + [Add destination] [Rebuild view] [Reset all].

**SyncPolicy bar**: five sliders (`initialBackoff`, `backoffMultiplier`, `maxBackoff`, `jitterFraction`, `maxAttempts`) bound to the policy `ValueNotifier` passed into `syncCycle`.

**Observation grid**: five equal columns (plus any columns added at runtime via [Add destination]).
- Col 1 `MATERIALIZED` — `diary_entries` list.
- Col 2 `EVENTS` — `event_log` across all aggregate_types.
- Col 3+ per destination — `PRIMARY`, `SECONDARY`, plus any dynamically-added destinations. Each destination column header stack:
  - **Schedule state** line: `DORMANT` / `SCHEDULED until ...` / `ACTIVE` / `CLOSED` / `CLOSED @ ...`.
  - **Start date** editor (appears while DORMANT; locks once set).
  - **End date** editor (always available).
  - **Connection** dropdown: `ok` | `broken` | `rejecting`.
  - **sendLatency** slider.
  - **sendBatchSize** slider (1 = one event per batch; higher values accumulate).
  - **maxAccumulateTime** slider.
  - **Ops drawer** (collapsible): [Unjam] [Rehabilitate all exhausted] [Delete destination] (delete shown only when `allowHardDelete == true`).
- Rightmost col `DETAIL` — populated by clicking any row in cols 1-N.

### 7.4 Styles (full-brightness readability palette)

```text
DemoColors:
  bg               = 0x000000   black
  fg               = 0xFFFFFF   white
  accent           = 0xFFFF00   yellow    (section headers, draining head)
  sent             = 0x00FF00   green
  pending          = 0xCCCCCC   grey
  retrying         = 0xFF0000   red       (head in transient-retry)
  exhausted        = 0xFF00FF   magenta   (exhausted row, inert)
  selected         = 0x001A66   dark navy (cross-panel selection fill)
  selectedOutline  = 0xFFFF00   yellow    (2px rectangle around selected row)
  border           = 0xFFFFFF   white

Action-button colors match corresponding state hue:
  red button    = 0xFF0000
  green button  = 0x00FF00
  blue button   = 0x0066FF
```

All text renders in **bold** (set as the default text weight at the app root). 20px monospace body text; 24-28px uppercase yellow headers; 3px white panel borders; 2px yellow rectangular outline wrapping the selected row against the navy fill; no rounded corners, shadows, or gradients.

### 7.5 Row conventions

Row formats in the observation panels:

```text
Events panel:          #6 ckpt demo_note agg-C
                       #3 fin  Red       agg-R1
Materialized:          agg-C [PTL]
                       agg-B [OK]
FIFO row (pending):    [pend]  #4   events: 3
FIFO row (draining):   > #4    DRAINING  events: 3
FIFO row (retrying):   > #2    RETRYING  events: 5
FIFO row (exhausted):  [exh]   #1   events: 8   (magenta, inert, clickable for detail)
FIFO row (sent):       [SENT]  #3   events: 2
```

The `>` prefix marks the current drain head. Clicking any row sets `app_state.selectedId` and tints linked rows blue across panels.

### 7.6 Demo destination

```dart
class DemoDestination implements Destination {
  DemoDestination({required this.id, this.allowHardDelete = false,
                   Duration initialSendLatency = const Duration(seconds: 10),
                   int initialBatchSize = 1,
                   Duration initialAccumulate = Duration.zero});

  @override final String id;
  @override final bool allowHardDelete;
  @override SubscriptionFilter get filter => SubscriptionFilter.any();
  @override String get wireFormat => "demo-json-v1";

  final ValueNotifier<Connection> connection;
  final ValueNotifier<Duration>   sendLatency;
  final ValueNotifier<int>        batchSize;          // max events per batch (>= 1)
  final ValueNotifier<Duration>   maxAccumulateTimeN; // UI-bound; exposed via override

  @override Duration get maxAccumulateTime => maxAccumulateTimeN.value;

  @override bool canAddToBatch(List<Event> currentBatch, Event candidate) =>
    currentBatch.length < batchSize.value;   // count-based; UI slider knob

  @override Future<WirePayload> transform(List<Event> batch) async => WirePayload(
    bytes: utf8.encode(jsonEncode({"batch": batch.map((e) => e.toJson()).toList()})),
    contentType: "application/json",
    transformVersion: "demo-v1",
  );

  @override Future<SendResult> send(WirePayload p) async {
    final conn = connection.value;
    switch (conn) {
      case Connection.ok:
        await Future.delayed(sendLatency.value);
        return SendOk();
      case Connection.broken:
        return SendTransient(error: "simulated disconnect");
      case Connection.rejecting:
        return SendPermanent(error: "simulated rejection");
    }
  }
}
```

Two instances at boot: `Primary` with `allowHardDelete: false` (FDA-style), `Secondary` with `allowHardDelete: true` (utility-style). Additional instances via the [Add destination] button at runtime — the dialog lets the user pick `allowHardDelete` per new destination.

### 7.7 Demo sync policy defaults

```text
initialBackoff    = 1 second
backoffMultiplier = 1.0               (no growth)
maxBackoff        = 10 seconds
jitterFraction    = 0.0               (deterministic)
maxAttempts       = 1,000,000         (transient is effectively recoverable)
periodicInterval  = not used in demo
```

UI sliders mutate a `ValueNotifier<SyncPolicy>`; each `syncCycle` call reads `.value`.

### 7.8 Storage

File-based `SembastBackend` at `$HOME/.local/share/append_only_datastore_demo/demo.db`. Path logged to stdout at boot. [Reset all] button deletes the file and recreates the backend.

## 8. Acceptance

`apps/common-dart/append_only_datastore/example/USER_JOURNEYS.md` contains nine journeys (`JNY-Datastore-Demo-01` through `-09`). A reviewer accepting Phase 4.6 runs them in order and flags any Expected-Outcome discrepancy as blocking.

Carried from the first draft:
- 01 full demo_note lifecycle
- 02 CQRS invariant via action events
- 03 per-destination isolation
- 04 transient disconnect and recovery
- 05 SyncPolicy sliders observable
- 06 rebuild idempotence

New:
- 07 add destination with past startDate — historical replay
- 08 setEndDate — `closed` return on past, `scheduled` return on future; differentiated behavior between two destinations
- 09 unjam + rehabilitate — induced exhaustion, unjam preserves exhausted audit row, re-batched events appear with new transform_version; rehabilitate a single exhausted row for environmental-retry scenario

## 9. Parent-design changes

Surgical edits landing in Phase 4.3 (within the same squashed commit):

- `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4_sync.md`:
  - `REQ-DEST-D`: `Destination.transform(List<Event> batch)` instead of single event.
  - `REQ-DRAIN-D`: `SendPermanent` marks exhausted and CONTINUES (loop to next head) — not `return`/wedge.
  - Additional fill-step reference in `REQ-SYNC`.
- `docs/superpowers/2026-04-21-mobile-event-sourcing-refactor-design.md`:
  - Changelog footer noting §5 decision #8 inversion (exhausted is skip, not wedge) and §12.1 risk reduction. Original content left in place (design doc remains review-traceable as of 2026-04-21).
- `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/README.md`:
  - Phase-table: add rows for 4.3 and 4.6 between 4 and 5. Update the "Phase sequence" table.
  - Mark `PLAN_PHASE5_cutover.md` Tasks 3-N as "moved to Phase 4.3" where applicable (EntryService, EntryTypeRegistry, bootstrap). Phase 5 still owns: PrimaryDiaryServerDestination, portalInboundPoll, widget registry, triggers, screen updates, deletions, REQ-d00113 behavior update.

## 10. Risks

### 10.1 Phase-4 rebase-in-flight

Phase 4 is currently in implementation (destinations/ directory exists with uncommitted changes). The batch-FIFO contract change needs to land before more Phase-4 code is written, or it becomes rework. Mitigation: Phase 4.3's first task is the PLAN_PHASE4_sync.md revision; Phase 4's implementer reads the revised plan before continuing.

### 10.2 Phase 4.3 is the biggest phase in the refactor

Roughly 2x the line count of any other phase (batch FIFO rewrite + dynamic destinations + unjam/rehabilitate + three pulled-forward features + SyncPolicy retrofit). Mitigated by: library-only (no UI), fully unit-testable, each deliverable has clear assertions, and the phase-squash is still reviewable as one commit because the changes form a coherent unit.

### 10.3 Demo slider density

The column headers now carry: schedule state, start-date editor, end-date editor, connection, sendLatency, sendBatchSize, maxAccumulateTime, ops drawer. That's a lot in one column. Mitigation: the ops drawer is collapsible; schedule editors only appear in relevant states (start-date widget hides once set; end-date widget present always).

### 10.4 Demo storage path collision

If a reviewer runs the demo alongside `clinical_diary` on the same machine, and paths happen to overlap, the demo can corrupt real dev data. Mitigated by a dedicated subdirectory (`$HOME/.local/share/append_only_datastore_demo/`) and stdout path logging at boot.

### 10.5 markFinal-on-missing tolerance as a silent failure

The race guard (`markFinal` no-op on missing row/store) means drain silently drops an attempt audit record when a user ops command races it. Mitigation: log a warning to stderr ("drain attempt completed on missing row/store — expected during destination delete/unjam") so the condition is visible, not fully invisible. Operator can review logs if they suspect audit loss.

### 10.6 A "sent" row whose remote never actually received

Scenario: v1 sent batch X and got SendOk; v1's status recording transaction committed. Network flapped between send() returning and remote persisting. If unjam is later run, unjam reads `final_status == sent` and preserves row X; does not rewind past it; the events are never re-sent; the remote is missing them. This is a destination-protocol concern, not a library concern. Mitigation: destinations that care need exactly-once idempotency on the remote side (event_id-keyed dedup). Out of scope for the library.

## 11. References

- Parent design: `docs/superpowers/2026-04-21-mobile-event-sourcing-refactor-design.md` (§7.2 write path, §8 sync architecture, §11.3 materializer fallbacks, §12 known risks).
- Parent plan README: `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/README.md`.
- Parent Phase 4 plan: `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4_sync.md`.
- Parent Phase 5 plan: `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE5_cutover.md` (for features being pulled forward).
- Acceptance: `apps/common-dart/append_only_datastore/example/USER_JOURNEYS.md`.
- Memory: `project_greenfield_status.md` (no migration concerns), `project_event_sourcing_refactor_out_of_scope.md` (explicit deferred work).
