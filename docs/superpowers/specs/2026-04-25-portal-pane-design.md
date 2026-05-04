# Portal Pane: Two-Datastore Demo for `event_sourcing_datastore` Example

**Date:** 2026-04-25
**Scope:** `apps/common-dart/event_sourcing_datastore/example/` (demo app only — library untouched)

## Summary

Add a second full instance of the `event_sourcing_datastore` example UI to the bottom half of the demo window. The top half (mobile) emits an `esd/batch@1` wire stream from its `Native` destination; the bottom half (portal) receives that stream via `EventStore.ingestBatch` and runs its own independent sync cycle. Sync is one-way (mobile → portal); both panes can also inject events locally. Portal will always have ≥ the events of mobile.

## Architecture

One Flutter process, one root `MaterialApp`, two `AppendOnlyDatastore` instances over two sembast DBs. The screen splits vertically:

```text
    +------------------------------------------------------------+
    |  MOBILE  source.hopId=mobile-device  db=demo.db            |
    |  [TopActionBar] [SyncPolicyBar]                            |
    |  [Materialized | Events | Audit | FIFO Primary | ... ]     |
    +============== draggable horizontal divider ================+
    |  PORTAL  source.hopId=portal  db=demo_portal.db            |
    |  [TopActionBar] [SyncPolicyBar]                            |
    |  [Materialized | Events | Audit | FIFO Primary | ... ]     |
    +------------------------------------------------------------+

    A.Native.send(payload)  --bridge-->  B.eventStore.ingestBatch(payload.bytes,
                                                wireFormat: payload.contentType)
                                                |
                                              SendOk / SendPermanent / SendTransient
                                              mapped from IngestBatchResult
```

The bridge is a single in-memory function. Mobile's `Native` destination calls it during `send()`; the existing `connection`/`sendLatency` knobs gate that call, so flipping mobile's Native to `broken` simulates "link down" with no extra plumbing.

The portal's own `Native` destination is unbridged — its `send()` is a no-op simulator (today's behavior).

Each pane has its own `Reset all` button that wipes only its own DB; resetting one side doesn't touch the other.

## Components

All changes live in `example/lib/`. The library is untouched.

### 1. `DemoApp` refactor — split root from pane

Today `DemoApp` owns both the `MaterialApp` and the Scaffold/Column body. Split:
- **`DemoPane`** (extracted from current `DemoApp` body): keeps the same constructor surface — `datastore`, `backend`, `appState`, `entryTypeLookup`, `dbPath`, `tickController` — plus a new `paneLabel` ("Mobile" / "Portal") used in a header strip so users can tell halves apart. Returns a `Widget` with no `MaterialApp` wrapper.
- **`DualDemoApp`** (described in Component 2): the new owner of `MaterialApp`. Replaces `DemoApp` as the widget passed to `runApp`.

No behavior change inside the pane.

### 2. `DualDemoApp` — new root widget

Takes two complete pane configurations (mobile + portal). Renders one `MaterialApp` whose home is a `Scaffold` with a `Column`: top `DemoPane` (mobile), draggable horizontal divider (mirrors the existing column-divider pattern), bottom `DemoPane` (portal). Holds divider-position state with a min-height clamp.

### 3. `DownstreamBridge` — new value type, ~30 lines

Lives in the example, not the library — demo-specific glue.

```dart
class DownstreamBridge {
  DownstreamBridge(this._target);
  final EventStore _target;

  Future<SendResult> deliver(WirePayload payload) async {
    try {
      final result = await _target.ingestBatch(
        payload.bytes, wireFormat: payload.contentType);
      return _mapResult(result);
    } on IngestDecodeFailure catch (e)   { return SendPermanent(error: '$e'); }
    on IngestIdentityMismatch catch (e)  { return SendPermanent(error: '$e'); }
    on IngestChainBroken      catch (e)  { return SendPermanent(error: '$e'); }
    catch (e)                            { return SendTransient(error: '$e'); }
  }
}
```

### 4. `NativeDemoDestination` extension — one optional constructor param

Add `DownstreamBridge? bridge` to the constructor. In `send()`, when `connection == ok`, after the existing `sendLatency` delay:
- If `bridge != null` → `return bridge.deliver(payload);`
- Otherwise → fall through to today's `SendOk`.

`broken`/`rejecting` branches unchanged. Bridge is never called when `connection != ok`.

### 5. `main()` rewrite — bootstrap two datastores

- Open two sembast DBs: `demo.db` (mobile), `demo_portal.db` (portal).
- Bootstrap two datastores, each with its own `Source`:
  - Mobile: `hopId='mobile-device'`, `identifier='demo-device'` (today's strings).
  - Portal: `hopId='portal'`, `identifier='demo-portal'`.
- Each pane gets its own destination instances (`Primary`, `Secondary`, `Native`) — destinations carry per-instance state (`connection`, `sendLatency`, `batchSize` notifiers) and cannot be shared.
- Construct `DownstreamBridge(portal.eventStore)` and pass it into mobile's `Native` constructor.
- Two tick timers, one per datastore. Each has its own `syncInFlight` reentrancy guard (today's pattern, two copies).
- Hand the pair to `DualDemoApp`.

## Data Flow

Two independent sync ticks, one per datastore. The bridge is the only point of contact.

```text
   MOBILE PANE (datastore A)                    PORTAL PANE (datastore B)
   ---------------------------                  ---------------------------
   user clicks [Add demo_note]                  user clicks [Add demo_note]
        |                                            |
        v                                            v
   A.eventStore.append(...)                     B.eventStore.append(...)
        |                                            |
        v                                            v
   A: tick (1s)                                 B: tick (1s)
   for each dest in {Primary,Secondary,Native}: for each dest in {Primary,Secondary,Native}:
     fillBatch -> FIFO row appended               fillBatch -> FIFO row appended
   for each dest:                               for each dest:
     drain -> dest.send(payload)                  drain -> dest.send(payload)
                                                  (B.Native: no bridge, simulate SendOk)
        |
        | A.Native.send(payload):
        |   if connection==broken    -> SendTransient
        |   if connection==rejecting -> SendPermanent
        |   else delay sendLatency, then:
        |     bridge != null ?
        |       yes -> bridge.deliver(payload)
        |       no  -> SendOk
        |                |
        |                v
        |       B.eventStore.ingestBatch(payload.bytes, wireFormat: payload.contentType)
        |       (Native produces 'esd/batch@1', the only wireFormat ingestBatch accepts)
        |                |
        |                +--> decode envelope          (IngestDecodeFailure  -> SendPermanent)
        |                +--> verify chain             (IngestChainBroken    -> SendPermanent)
        |                +--> stamp receiver provenance (hop=portal)
        |                +--> reassign local seq#, append to B's event store
        |                +--> return IngestBatchResult
        |                |
        |                v
        |       map result -> SendOk / SendTransient / SendPermanent
        v
   drain processes SendResult:
     SendOk        -> markFinal, advance FIFO
     SendTransient -> backoff, retry next tick
     SendPermanent -> mark FIFO row final-failed
```

Mobile's drain doesn't know portal exists; it sees only a `SendResult`. Portal's tick doesn't know mobile exists; it observes new events landing in its event store from `ingestBatch` (instead of from `append`) and processes them through its own destinations. Both sides can independently inject local events via their own `TopActionBar` ([Add demo_note], [Add red/green/blue], [Ingest sample batch]).

## Error Handling

Three classes of failure, all routed through existing surfaces — no new error UI.

### 1. Link-level failure (mobile's connection knob)

- `broken` → `SendTransient` (FIFO row stays pending, retry next tick with backoff).
- `rejecting` → `SendPermanent` (FIFO row marked final-failed in mobile's panel).

Bridge isn't called in either case. Unchanged from today's `NativeDemoDestination` behavior.

### 2. Portal-side ingest failure (bridge result mapping)

| Portal-side outcome           | Mobile-side `SendResult` | Why                                       |
|-------------------------------|--------------------------|-------------------------------------------|
| `IngestDecodeFailure`         | `SendPermanent`          | Wire bytes won't ever decode — no retry.  |
| `IngestIdentityMismatch`      | `SendPermanent`          | Wrong receiver — won't fix on retry.      |
| `IngestChainBroken`           | `SendPermanent`          | Hash chain corrupt — won't fix on retry.  |
| Any other thrown exception    | `SendTransient`          | Treat unknowns as recoverable.            |
| `IngestBatchResult` (success) | `SendOk`                 | Per-event outcomes are portal's concern.  |

A successful `IngestBatchResult` always maps to `SendOk` even if some per-event outcomes inside the batch are non-success — mobile's job is "did the batch arrive?", and per-event detail is observable in portal's audit panel.

Mobile's pane shows the failure on the Native FIFO row (existing UI). Portal's pane shows whatever it ingested in its audit panel (existing UI), including partial-batch outcomes.

### 3. Pane-local failures (unchanged)

Append failures, materializer errors, portal's own destination drain failures — all surface in their own pane through panels that already exist. The bridge plays no role.

### 4. Reset isolation

Each pane's `Reset all` cancels only its own tick, closes only its own `SembastBackend`, deletes only its own DB file. The other pane is unaffected.

If mobile is reset while a bridge call is mid-flight, the call completes against portal (portal doesn't know mobile is gone) and mobile's tick is already canceled — the result is dropped, no FIFO state to update. Acceptable for a demo: user clicked Reset, expects fresh start.

## Testing

Library primitives (`EventStore.ingestBatch`, `fillBatch`, `drain`, `NativeDemoDestination`) are already covered by the package's own test suite. Tests focus on the new glue.

### Unit tests (`example/test/`)

1. **`DownstreamBridge.deliver` — outcome mapping**
   - Happy path: portal's `EventStore.ingestBatch` returns success → `SendOk`. Use real `bootstrapAppendOnlyDatastore` over in-memory sembast; build envelope with existing `SyntheticBatchBuilder`.
   - Decode failure: garbage bytes → `SendPermanent`.
   - Chain broken: tampered `event_hash` on a multi-event batch → `SendPermanent`.
   - Generic throw: stub `EventStore` that throws `StateError` → `SendTransient`.

2. **`NativeDemoDestination` with bridge wired**
   - `connection=ok, bridge=null` → `SendOk` (regression: existing behavior preserved).
   - `connection=ok, bridge!=null, bridge returns SendOk` → `SendOk`.
   - `connection=broken, bridge!=null` → `SendTransient`, **bridge not called** (assert via spy).
   - `connection=rejecting, bridge!=null` → `SendPermanent`, bridge not called.

### Integration test (`example/integration_test/` — one new test)

3. **End-to-end mobile→portal sync**
   - Bootstrap two datastores in one process (mirrors new `main()`).
   - On mobile: append three demo_notes via `EventStore.append`.
   - Run a few sync ticks (call `fillBatch`+`drain` directly, matching the demo's tick).
   - Assert: portal's event store contains three events with provenance chains showing `hop=mobile-device` followed by `hop=portal`, and portal's FIFOs/materialized view reflect them.
   - Assert: portal's local `append` works independently — append one event on portal, run portal's tick, no event appears on mobile (one-way).

### Out of scope

- No widget tests for `DualDemoApp` — layout/divider behavior is covered by Flutter's own framework; the example has no widget tests today, and we shouldn't introduce a new testing surface for a demo.

### Manual verification (one-time, before declaring done)

Run `flutter run -d linux` from `example/`. Confirm:
- Both panes render with their `paneLabel` headers.
- Append events on top, watch them appear on bottom (with portal-stamped provenance in audit panel).
- Drag the divider; both panes resize.
- Flip mobile's Native connection to `broken`; mobile's Native FIFO row stays pending, portal is unchanged.
- Each pane's `Reset all` wipes only its own state.

## Requirements

This is an example-app design only — the library surface it exercises is already covered by existing REQs. The dual-pane demo exercises (does not extend) the following:

- REQ-d00145-A+B+C+D+E+F+G+K — `EventStore.ingestBatch` contract (portal-side ingest of the bridge's wire payloads).
- REQ-d00128-E+F+G+H — `fillBatch` contract (mobile-side; emits the wire stream the bridge forwards).
- REQ-d00125-A+B+C — `SyncCycle` contract (per-pane drain orchestration).
- REQ-d00134-A+B+C+D — `bootstrapAppendOnlyDatastore` contract (used twice — once per pane).

No new assertion bodies land from this spec; it is a demo-only design and the library REQs it exercises are already in the assertion graph.
