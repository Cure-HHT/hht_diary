# Phase 4.22 Task 10 — Demo NativeAudit destination + EventStreamPanel hop badge

## Goal

Make Phase 4.22's two new bridging capabilities visible in the dual-pane example app:

1. A second native destination, `NativeAudit`, sharing the downstream bridge with the existing user-payload native destination (renamed to `NativeUser`). NativeAudit subscribes to system audits via `SubscriptionFilter(entryTypes: [], includeSystemEvents: true)`. This demonstrates REQ-d00128-J (`includeSystemEvents` opt-in) and REQ-d00154-F (cross-hop forensic visibility for system audit events).
2. An origin badge (`[L]` or `[R]`) on every `EventStreamPanel` row, driven by `EventStore.isLocallyOriginated(event)` (REQ-d00154-B). The badge makes cross-hop event discrimination eyeball-visible in the dual-pane UI: every locally-originated event renders as `[L]`, every event ingested from another hop renders as `[R]`.

This task lands the demo wiring + UI plus a portal-soak assertion that system audits actually traverse the bridge end-to-end and a dual-pane integration test that the hop badge is visible.

## Implementation

### Step 1 — Replace single Native with NativeUser + NativeAudit in `_bootstrapPane`

`apps/common-dart/event_sourcing_datastore/example/lib/main.dart`:

The previous demo had one native destination per pane:

```dart
final native = NativeDemoDestination(id: 'Native', bridge: bridge);
```

After Task 10, each pane has two:

```dart
// Implements: REQ-d00128-J, REQ-d00154-F — the demo hosts two parallel
//   native-wire destinations so the dual-pane UI shows both lanes
//   reaching the downstream bridge:
//     - NativeUser ships user-payload events only ...
//     - NativeAudit ships system audit events only
//       (includeSystemEvents: true plus an empty entryTypes list).
final nativeUser = NativeDemoDestination(
  id: 'NativeUser',
  filter: const SubscriptionFilter(
    entryTypes: <String>[
      'demo_note',
      'red_button_pressed',
      'green_button_pressed',
      'blue_button_pressed',
    ],
  ),
  bridge: bridge,
);
final nativeAudit = NativeDemoDestination(
  id: 'NativeAudit',
  filter: const SubscriptionFilter(
    entryTypes: <String>[],
    includeSystemEvents: true,
  ),
  bridge: bridge,
);
```

The `bootstrapAppendOnlyDatastore` `destinations:` arg now lists `[primary, secondary, nativeUser, nativeAudit]`. The post-bootstrap `setStartDate` loop iterates over `['Primary', 'Secondary', 'NativeUser', 'NativeAudit']`. Both panes use the same shape; mobile passes `bridge: bridge`, portal passes `bridge: null` (default), preserving Task 9's one-way mobile -> portal sync model.

### Step 2 — Hop badge in EventStreamPanel

`apps/common-dart/event_sourcing_datastore/example/lib/widgets/event_stream_panel.dart`:

`EventStreamPanel` constructor now requires `EventStore eventStore` alongside its existing `backend` and `appState`. The panel uses `eventStore.isLocallyOriginated(event)` to decide each row's hop badge.

Each `_EventRow` carries a new `bool locallyOriginated` field, computed by the parent panel. The row text format becomes:

```dart
final originBadge = locallyOriginated ? '[L]' : '[R]';
'$originBadge #${event.sequenceNumber} ${event.eventType} '
'${event.aggregateType} $shortAgg'
```

Annotated `// Implements: REQ-d00154-B` on both the `EventStore eventStore` field and the per-row badge computation.

### Step 3 — Wire eventStore through `app.dart`

`DemoPane._buildColumns()` now passes `eventStore: widget.datastore.eventStore` to its single `EventStreamPanel` construction. `DemoPane` already received the `AppendOnlyDatastore` so no new field is needed.

### Step 4 — Lib fix: `runHistoricalReplay` honors `serializesNatively`

The demo configuration surfaces a latent lib bug. `_bootstrapPane` calls `setStartDate(now)` for each destination after the bootstrap-emitted system audit events have already landed in the event log. NativeAudit's filter (`includeSystemEvents: true`) admits those audits. `setStartDate(now)` triggers `runHistoricalReplay`, which calls `destination.transform(batch)` unconditionally — but `NativeDemoDestination.transform` throws by contract because `serializesNatively == true` (REQ-d00152-A+B).

`fillBatch` already branches on `serializesNatively`: native destinations skip `transform` and the library mints a `BatchEnvelopeMetadata` from the caller's `Source`, enqueueing via `nativeEnvelope:`. `runHistoricalReplay` lacked the symmetric branch.

Fix:

- `apps/common-dart/event_sourcing_datastore/lib/src/sync/historical_replay.dart`
  - New optional `Source? source` parameter; `null` keeps the existing call sites working.
  - Branch on `destination.serializesNatively` mirroring `fillBatch`'s lines 182-213.
  - When native and `source == null`, throw `ArgumentError` (matches `fillBatch`).
  - Annotated `// Implements: REQ-d00152-B (replay parity)` with prose covering the post-bootstrap NativeAudit scenario.
- `apps/common-dart/event_sourcing_datastore/lib/src/destinations/destination_registry.dart`
  - `setStartDate` (the sole caller of `runHistoricalReplay`) threads `_eventStore.source` through the new parameter.

### Step 5 — Tests

#### Test setups updated to NativeUser + NativeAudit shape

- `apps/common-dart/event_sourcing_datastore/example/test/portal_sync_test.dart`
- `apps/common-dart/event_sourcing_datastore/example/test/portal_soak_test.dart`
- `apps/common-dart/event_sourcing_datastore/example/integration_test/dual_pane_test.dart`

The `_mkPane` (or equivalent) helpers now construct NativeUser + NativeAudit instead of a single Native. Tests that probed the single Native via `whereType<NativeDemoDestination>().single` now iterate over the type. Tests that listed FIFOs by id `'Native'` switch to `'NativeUser'`.

#### portal_soak_test — system-audits-bridged assertion

After the existing 60-second click loop and flush sequence, the soak test now also asserts:

```dart
// Verifies: REQ-d00128-J + REQ-d00154-F — system audits bridge through
//   NativeAudit to portal.
final allPortalEvents = await portal.backend.findAllEvents();
final portalSystemEvents = allPortalEvents
    .where((e) => kReservedSystemEntryTypeIds.contains(e.entryType))
    .toList();
expect(portalSystemEvents, isNotEmpty,
    reason: 'NativeAudit must bridge mobile system audits to portal');
final mobileOriginated = portalSystemEvents.where(
  (e) => e.originatorHop.identifier == mobile.source.identifier,
);
expect(mobileOriginated, isNotEmpty,
    reason: 'at least one portal-stored system event must originate from '
        'mobile install ...');
```

This guards against a regression where the bridge silently drops system events or where one of the two panes' bootstrap audits accidentally satisfies the assertion without any actual cross-hop traffic.

#### dual_pane_test — hop badge widget test

```dart
// Verifies: REQ-d00154-B — hop badge visible in EventStreamPanel.
testWidgets(
  'REQ-d00154-B: portal pane shows [R] for ingested events; mobile shows [L]',
  (tester) async {
    final setup = await _setupDualApp(testId: 'hop-badge');
    // ... resize to wide window, pump, tap GREEN inside MOBILE pane ...
    await setup.mobile.tick();
    await setup.portal.tick();
    await tester.pumpAndSettle();

    expect(find.descendant(
      of: _paneByLabel('MOBILE'),
      matching: find.textContaining('[L] '),
    ), findsAtLeastNWidgets(1));
    expect(find.descendant(
      of: _paneByLabel('PORTAL'),
      matching: find.textContaining('[R] '),
    ), findsAtLeastNWidgets(1));
  },
);
```

#### historical_replay_test — REQ-d00152-B replay parity regression tests

`apps/common-dart/event_sourcing_datastore/test/destinations/historical_replay_test.dart`:

- `'REQ-d00152-B: replay on a native destination skips transform and stamps envelope metadata'` — seeds 3 events, registers a `NativeDestination`, calls `setStartDate(past)`, asserts the resulting FIFO row has `envelope_metadata` populated (with sender_hop / sender_identifier from the registry's source) and `wire_payload == null`. Pre-fix, this throws because `NativeDestination.transform` is unreachable on `serializesNatively == true`.
- `'REQ-d00152-B + REQ-d00128-J: native audit-mirror picks up prior system audits via replay'` — first registers a `FakeDestination` (which itself emits a `system.destination_registered` audit into the event log), then registers a native destination with `includeSystemEvents: true` and empty `entryTypes` (NativeAudit shape). `setStartDate(past)` enqueues the prior system audit row through the native branch. This is the exact scenario the demo surfaced.

Wedge-isolation property test (poison user event wedges NativeUser; NativeAudit keeps draining): not added in this task. The basic system-audits-reach-portal assertion in the soak is sufficient for spec compliance and eyeball validation. A dedicated wedge-isolation test would require either a per-event configurable failure on `NativeDemoDestination.send` or a dedicated test-double, which is more elaborate than this task warrants — recorded as deferred follow-up if a future regression makes it necessary.

## Verification

```text
$ (cd apps/common-dart/event_sourcing_datastore/example && flutter test)
01:05 +81: All tests passed!

$ (cd apps/common-dart/event_sourcing_datastore && flutter test)
00:06 +705: All tests passed!

$ (cd apps/common-dart/event_sourcing_datastore && flutter analyze)
No issues found! (ran in 0.8s)

$ (cd apps/common-dart/event_sourcing_datastore/example && flutter analyze)
No issues found! (ran in 0.9s)
```

- example test count: 81 -> 81 (the new dual_pane_test test runs under the integration_test harness, not the standard `flutter test` runner).
- lib test count: 703 -> 705 (+ 2 native-replay parity regression tests).

## Files Touched

### lib/

- `apps/common-dart/event_sourcing_datastore/lib/src/sync/historical_replay.dart` — `runHistoricalReplay` accepts optional `Source? source`; branches on `destination.serializesNatively` symmetrically with `fillBatch`. New imports: `batch_envelope_metadata`, `batch_envelope`, `source`, `uuid`.
- `apps/common-dart/event_sourcing_datastore/lib/src/destinations/destination_registry.dart` — `setStartDate` threads `_eventStore.source` through the new parameter.

### example/

- `apps/common-dart/event_sourcing_datastore/example/lib/main.dart` — `_bootstrapPane` builds NativeUser + NativeAudit; setStartDate loop covers both.
- `apps/common-dart/event_sourcing_datastore/example/lib/widgets/event_stream_panel.dart` — `EventStreamPanel` requires `EventStore`; `_EventRow` shows `[L]` / `[R]` badge prefix.
- `apps/common-dart/event_sourcing_datastore/example/lib/app.dart` — `DemoPane._buildColumns()` passes `eventStore` to `EventStreamPanel`.

### test/

- `apps/common-dart/event_sourcing_datastore/test/destinations/historical_replay_test.dart` — 2 new tests for REQ-d00152-B replay parity.
- `apps/common-dart/event_sourcing_datastore/example/test/portal_sync_test.dart` — `_mkPane` shape; broken-link test iterates both natives; FIFO listing renamed to `'NativeUser'`.
- `apps/common-dart/event_sourcing_datastore/example/test/portal_soak_test.dart` — `_mkPane` shape; iteration over both natives; new system-audits-bridged assertion at the end of the soak.
- `apps/common-dart/event_sourcing_datastore/example/integration_test/dual_pane_test.dart` — `_mkPane` shape; broken-link test iterates both natives; new hop-badge widget test.

### worklog / task file

- `PHASE_4.22_WORKLOG.md` — Task 10 checkbox flipped; Task 10 details section appended.
- This file (`PHASE4.22_TASK_10.md`).

## Outcome

The dual-pane example app demonstrates Phase 4.22's two new capabilities visibly:

1. **System audits cross-hop via NativeAudit** (REQ-d00128-J + REQ-d00154-F). Mobile pane's NativeAudit ships every reserved system entry type through the same downstream bridge as user payloads. The portal pane's event log accumulates mobile-originated system audits alongside its own bootstrap audits, providing cross-hop forensic visibility into mobile install state mutations.
2. **Hop badge** (REQ-d00154-B). Every `EventStreamPanel` row prefixes its label with `[L]` or `[R]` driven by `EventStore.isLocallyOriginated`. On mobile, every locally-recorded button event renders as `[L]`. On portal, the same event renders as `[R]`. Portal's own bootstrap audits render as `[L]` on portal but never appear on mobile (one-way sync).

Library fix: `runHistoricalReplay` now honors `serializesNatively` symmetrically with `fillBatch`. Native destinations registered after events have already landed in the event log catch up via the native branch, never through `transform` — preserving the destination-contract guarantee in REQ-d00152-A+B.
