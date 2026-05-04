# event_sourcing_datastore_demo

Linux-desktop sandbox exercising every public surface of
`event_sourcing_datastore`. Two datastores in one process, one mobile
pane bridged into one portal pane, every panel driven from real lib
APIs (no mocks, no fixtures).

## Contents

1. [Overview](#1-overview)
2. [Run It](#2-run-it)
3. [Bootstrap and Startup](#3-bootstrap-and-startup)
4. [Event Types](#4-event-types)
5. [Views](#5-views)
6. [Destinations](#6-destinations)
7. [Provenance and Origin](#7-provenance-and-origin)
8. [Walk-throughs](#8-walk-throughs)

---

## 1. Overview

The demo's defining feature is its dual-pane shell. One Flutter process
hosts two independent `AppendOnlyDatastore` instances side by side:

```text
+-------------------------------------------------------+
|  MOBILE pane                                          |
|  +-----------+----------+----------+----+----+----+   |
|  | MATERIAL- | EVENTS   | AUDIT    | P  | S  | NU |   |
|  | IZED      | (watch)  |          | FIFO   ...   |   |
|  +-----------+----------+----------+----+----+----+   |
|                                                       |
|  AppendOnlyDatastore A (hopId='mobile-device')        |
|  Source.identifier = MOBILE.install.uuid              |
|         |                                             |
|         |  NativeUser / NativeAudit destinations      |
|         |  -> DownstreamBridge.deliver(payload)       |
|         v                                             |
+---------v---------------------------------------------+
|  PORTAL pane                                          |
|  +-----------+----------+----------+----+----+----+   |
|  | MATERIAL- | EVENTS   | AUDIT    | FIFO panels  |   |
|  | IZED      | (watch)  |          |              |   |
|  +-----------+----------+----------+----+----+----+   |
|                                                       |
|  AppendOnlyDatastore B (hopId='portal-server')        |
|  Source.identifier = PORTAL.install.uuid              |
|  EventStore.ingestBatch(...) materializes on portal   |
+-------------------------------------------------------+
```

Both panes are the same code with different `Source` and a different
on-disk database. Mobile's two `NativeDemoDestination` instances
deliver via an in-process `DownstreamBridge` straight into portal's
`EventStore.ingestBatch`. Portal sees the events with mobile's
provenance entry stamped at hop 0 and a portal-stamped receiver entry
at hop 1. Materializer rows appear on portal as ingest commits, not
on a separate code path.

The single MaterialApp hosts the two panes split by a draggable
horizontal divider. Each pane runs its own 1-second sync tick that
calls `fillBatch` per destination plus `SyncCycle()` for drain plus
inbound poll.

---

## 2. Run It

The demo targets Linux desktop. Other Flutter desktop targets work in
principle but are not exercised by CI.

### Prerequisites (Ubuntu / Debian)

```bash
sudo apt-get install \
    cmake clang ninja-build pkg-config \
    libgtk-3-dev liblzma-dev
```

### Run

```bash
cd apps/common-dart/event_sourcing_datastore/example
flutter pub get
flutter run -d linux
```

### Storage paths

Both panes persist their state under
`<applicationSupportDirectory>/event_sourcing_datastore_demo/`:

- `demo.db` — mobile pane's Sembast event log + views + FIFOs.
- `demo_portal.db` — portal pane's same.
- `MOBILE.install.uuid` — mobile pane's persisted `Source.identifier`.
- `PORTAL.install.uuid` — portal pane's persisted `Source.identifier`.

The two `*.install.uuid` files are minted on first launch and re-read
on every subsequent boot. To start over from scratch, delete the four
files (or use the **Reset all** button in either pane's top bar — that
button also deletes the database file).

---

## 3. Bootstrap and Startup

`example/lib/main.dart` boots in a fixed order:

1. Resolve `applicationSupportDirectory` and ensure the demo subdir
   exists.
2. `_readOrMintUUID` reads (or mints + persists) each pane's install
   UUID.
3. Bootstrap the **portal pane first** — the `DownstreamBridge` needs a
   reference to portal's `EventStore` before mobile's
   `NativeDemoDestination` is constructed.
4. Construct the bridge.
5. Bootstrap the **mobile pane** with the bridge wired into its native
   destinations.
6. Hand both panes to `DualDemoApp`.

Per-pane bootstrap (the `_bootstrapPane` function):

```dart
Future<_PaneRuntime> _bootstrapPane({
  required String dbPath,
  required Source source,
  DownstreamBridge? bridge,
}) async {
  final db = await databaseFactoryIo.openDatabase(dbPath);
  final backend = SembastBackend(database: db);

  // Four destinations: two lossy 3rd-party, two native-wire.
  final primary = DemoDestination(id: 'Primary', filter: ...);
  final secondary = DemoDestination(id: 'Secondary', ...);
  final nativeUser = NativeDemoDestination(id: 'NativeUser',
                                           bridge: bridge, ...);
  final nativeAudit = NativeDemoDestination(id: 'NativeAudit',
                                            bridge: bridge, ...);

  final datastore = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: source,
    entryTypes: allDemoEntryTypes,
    destinations: <Destination>[primary, secondary, nativeUser, nativeAudit],
    materializers: const <Materializer>[
      DiaryEntriesMaterializer(promoter: identityPromoter),
    ],
    initialViewTargetVersions: const <String, Map<String, int>>{
      'diary_entries': <String, int>{'demo_note': 1},
    },
  );

  // ... per-destination start_date set, sync tick, AppState.
}
```

The mobile pane passes `bridge: <bridge>`; the portal pane passes
`bridge: null` so portal's native destinations are no-op simulators.

---

## 4. Event Types

`demo_types.dart` declares four user entry types; they cover the full
lifecycle / CQRS / lights demonstrations.

```dart
const EntryTypeDefinition demoNoteType = EntryTypeDefinition(
  id: 'demo_note',
  registeredVersion: 1,
  name: 'Demo note',
  widgetId: 'demo_note_widget_v1',
  widgetConfig: <String, Object?>{},
  effectiveDatePath: 'date',  // resolves answers['date'] for the view
);

const EntryTypeDefinition redButtonType   = EntryTypeDefinition(
  id: 'red_button_pressed',   /* ... */ );
const EntryTypeDefinition greenButtonType = EntryTypeDefinition(
  id: 'green_button_pressed', /* ... */ );
const EntryTypeDefinition blueButtonType  = EntryTypeDefinition(
  id: 'blue_button_pressed',  /* ... */ );
```

`demo_note` is the diary-shaped entry type — it routes through the
`DiaryEntriesMaterializer` because its events are appended with
`aggregateType: 'DiaryEntry'`. The three button types use distinct
aggregate types (`RedButtonPressed`, `GreenButtonPressed`,
`BlueButtonPressed`) and therefore never reach the diary materializer
— they appear in the EVENTS panel and FIFOs but not in the
MATERIALIZED panel. That is the CQRS discriminator demo.

System entry types (the ten reserved ids covered in the lib README's
"Event Types" section) are emitted automatically by lib operations
and surface in the AUDIT panel and (via the `NativeAudit` destination)
on the wire to portal.

---

## 5. Views

The demo wires one materializer:

```dart
materializers: const <Materializer>[
  DiaryEntriesMaterializer(promoter: identityPromoter),
],
```

The `MaterializedPanel` reads from `backend.findEntries(...)` and
re-renders on every `watchView('diary_entries')` snapshot. That panel
appears on BOTH panes. When mobile appends a `demo_note` event:

- Mobile's local `applyInTxn` upserts a row in mobile's
  `diary_entries` view; mobile's `MaterializedPanel` re-renders on the
  emitted snapshot.
- The same event flows through `NativeUser` to portal via the bridge.
- Portal's `EventStore.ingestBatch` runs the SAME materializer code
  path on the SAME event; portal's `diary_entries` view gets its own
  row; portal's `MaterializedPanel` re-renders on portal's snapshot.

Same code, two independent stores, two independently observable view
states. The materialize-on-ingest behavior is what the receiver-side
panel demonstrates.

`example/lib/lights_materializer.dart` defines a second materializer
maintaining an `rgb_lights` view from the three button-press entry
types. It is shipped as a reference example for callers writing their
own materializers; it is not wired into the demo's bootstrap by
default.

---

## 6. Destinations

The demo registers four destinations per pane:

| id | Type | Wire format | Filter |
| --- | --- | --- | --- |
| `Primary` | 3rd-party | `demo-json-v1` | `demo_note`, `red_button_pressed`, `green_button_pressed` |
| `Secondary` | 3rd-party | `demo-json-v1` | `green_button_pressed`, `blue_button_pressed` |
| `NativeUser` | Native (`esd/batch@1`) | `esd/batch@1` | All four user entry types |
| `NativeAudit` | Native (`esd/batch@1`) | `esd/batch@1` | System events only |

`Primary` and `Secondary` are `DemoDestination` —
`serializesNatively: false`; lib invokes `transform` and persists the
resulting `WirePayload` verbatim. `Secondary` opts into
`allowHardDelete: true` so the demo can exercise hard-delete on it.

`NativeUser` and `NativeAudit` are `NativeDemoDestination` —
`serializesNatively: true`; lib produces the `esd/batch@1` envelope
inside `fillBatch` and persists `envelope_metadata` with
`wire_payload: null`. Drain reconstructs the wire bytes
deterministically on each send attempt and (when a bridge is wired)
hands them to `DownstreamBridge.deliver`, which calls
`EventStore.ingestBatch` on portal and maps the outcome to a
`SendResult`.

`NativeAudit` ships only system events. Its filter is the canonical
audit-bridge pattern:

```dart
const SubscriptionFilter(
  entryTypes: <String>[],     // empty: no user entry types match
  includeSystemEvents: true,  // opt-in: every reserved system id matches
);
```

That pairing demonstrates the four-destination wedge-isolation layout:
a poison user event can wedge `NativeUser` without affecting
`NativeAudit`'s ability to keep shipping audit traffic, and a
malformed audit event can wedge `NativeAudit` without affecting user
event flow.

Each destination panel exposes live-tunable knobs (sliders /
dropdowns):

- **Connection** — `ok` (succeed after `sendLatency`), `broken`
  (return `SendTransient`), `rejecting` (return `SendPermanent`).
- **Send latency** — wall-clock delay before `SendOk`.
- **Batch size** — upper bound on `canAddToBatch` length.
- **Accumulate** — `maxAccumulateTime` hold for single-event batches.

The `SyncPolicyBar` above the columns exposes per-pane `SyncPolicy`
knobs (`initialBackoff`, `backoffMultiplier`, `maxBackoff`,
`jitterFraction`, `maxAttempts`, `periodicInterval`) that flow into
the drain loop on each tick.

---

## 7. Provenance and Origin

Each pane mints its own `Source.identifier` on first boot and reuses
it on every subsequent boot. The mobile pane's EVENTS panel shows
every event with an `[L]` (locally originated) or `[R]` (received from
upstream) badge, computed via `EventStore.isLocallyOriginated(event)`
on the pane's own `EventStore`.

Walk-through to see the badge shift across the bridge:

1. In the mobile pane, click any of the four user actions (Start a
   note, press Red / Green / Blue).
2. The new event row appears in mobile's EVENTS panel with `[L]`
   prefixed (mobile-originated).
3. Within ~1 second, the same event flows via `NativeUser` to portal.
   The portal pane's EVENTS panel shows the event with `[R]` prefixed
   — portal evaluates `isLocallyOriginated` against PORTAL's
   identifier, the event's `provenance[0].identifier` is MOBILE's
   UUID, the comparison returns false.

The system-event AUDIT panel shows receiver-stamped audit rows
(`ingest.batch_rejected` / `ingest.duplicate_received`) on the panel
that did the receiving. Because portal's NativeAudit destination has
`bridge: null`, those audit events stop at portal — the demo does not
chain a third hop.

---

## 8. Walk-throughs

Each scenario is a "to see X, do Y, observe Z" exercise. Run them in
order on a fresh launch (use **Reset all** between independent
exercises if needed). All button labels match the in-app UI exactly.

### Demo-note lifecycle

To see one aggregate go through every event-type transition: in
mobile, type a title and body, click **Start** (a `checkpoint` event
fires), edit the body and click **Complete** (a `finalized` event),
edit again and click **Edit selected** then **Complete** (another
`finalized`), finally **Delete selected** (a `tombstone`). Observe
four rows appear in EVENTS sharing one `aggregate_id`, the
materialized row state shift through partial / complete / deleted
markers, all four FIFOs drain those rows independently at their own
send-latency cadence, and the same four rows materialize on the portal
pane via the bridge.

### CQRS invariant

To see action events bypass the materialized view: note the current
row count in MATERIALIZED, then click Red three times, Green once,
Blue twice. Observe six new rows in EVENTS with distinct
`aggregate_type` values (`RedButtonPressed` / `GreenButtonPressed` /
`BlueButtonPressed`), the MATERIALIZED row count unchanged, and all
six rows drain through the FIFOs whose filters admit them.

### Per-destination isolation under a rejection storm

To see one destination wedge while another keeps draining: flip
Secondary's connection from `ok` to `rejecting`, then click Start +
Complete on a new note (two events) and Red once (one more). Observe
Secondary's head row flips through `draining` to `wedged` after one
permanent rejection, the two later rows queue behind it as `pending`
(Secondary's drain has halted), Primary processes the same three
batches to `sent` normally, and `wedgedFifos()` returns one summary
naming Secondary only. To recover, click the wedged row, then
**Tombstone & Refill** in the detail panel — Secondary's wedged row
flips to `tombstoned`, the trail of pending rows is swept, and fresh
rows enqueue and drain on the next tick.

### Transient disconnect and recovery

To see retry plus catchup without loss: with maxAttempts at its
default, flip Primary to `broken`, click Red / Green / Blue (three
events), and watch for ~10 seconds. Observe Primary's head row shows
`retrying` with `attempts[]` accumulating; Secondary continues to
deliver its copies of the same events. Flip Primary back to `ok`.
Observe the queued rows drain in order at Primary's send latency;
`wedgedFifos()` stayed empty throughout.

### Sync policy tuning

To see `SyncPolicy.backoffFor` live: set initialBackoff = 3s,
multiplier = 2.0, maxBackoff = 60s, maxAttempts = 1000. Flip Primary
to `broken` and click Red. Pin the head row in the detail panel.
Watch `attempts[]` accumulate at intervals matching the curve (3s,
6s, 12s, 24s, 48s, 60s, 60s, ...). Then set maxAttempts = 3, click
Green; the new head wedges after exactly 3 attempts —
transient-exhaustion converges on the same wedged terminal state as
permanent rejection.

### Rebuild materialized view

To see the view rebuilt from the event log: with diverse history
accumulated (notes in various states, action events, some
destinations wedged or drained), note current panel contents. Click
**Rebuild view**. Observe MATERIALIZED clears and refills with
byte-identical rows; EVENTS / Primary FIFO / Secondary FIFO are
unchanged (rebuild touches the view store only); idempotent on
repeat clicks.

### Add destination triggers historical replay

To see runtime add plus replay: click **Add destination**, set id =
`Backup`, allowHardDelete = true, submit. A new column appears,
state = `DORMANT`. Set Backup's start date to a value earlier than
any event in the log. Observe Backup's schedule flips to `ACTIVE`,
the lib walks the event log in sequence order, batches into groups
respecting `canAddToBatch`, and populates Backup's FIFO with
`pending` rows; on the next tick they drain to `sent`. Other panels
are unaffected.

### setEndDate semantics

To see end-date filtering: in Primary's schedule editor, set end-date
10 minutes from now (returns `scheduled`); set Secondary's end-date
to 1 hour ago (returns `closed`). Click Start + Complete on a new
note. Observe the two events enqueue and drain through Primary
(their `client_timestamp` is before Primary's end-date) but never
appear in Secondary (their `client_timestamp` is after Secondary's
end-date). Edit Primary's end-date to a past value; subsequent button
presses no longer enqueue to Primary either, but DO appear in EVENTS
— the event log is the source of truth and is not filtered by
destination schedules.

### Mobile-to-portal sync (the dual-pane story)

To see one event flow end-to-end across the bridge: in the mobile
pane click Start, type a title, click Complete. Observe two new rows
in mobile's EVENTS each prefixed `[L]`; mobile's MATERIALIZED gains
a row with the title; mobile's NativeUser FIFO holds the rows
briefly then flips them to `sent`. Look at the portal pane (within
~1 second): two new rows in portal's EVENTS each prefixed `[R]`
(portal evaluates `isLocallyOriginated` against portal's UUID and
reads mobile's identifier on `provenance[0]`); portal's MATERIALIZED
gains the same row (materialize-on-ingest); portal's AUDIT panel
shows an `ingest.duplicate_received` audit row if the same envelope
is replayed.

### Hop discrimination via [L] / [R] badge

To see two installs of the same role class as distinct origins:
delete only `MOBILE.install.uuid` (leave the database). Re-run the
demo. The mobile pane mints a fresh UUID and re-bootstraps; mobile's
events from this run appear with `[L]` on mobile, `[R]` on portal.
Pre-existing portal events that were originated by the previous
mobile install still show their old `provenance[0].identifier` —
the prior mobile UUID — and read as `[R]` on the running mobile pane
(different identifier from the running pane's `Source.identifier`).
