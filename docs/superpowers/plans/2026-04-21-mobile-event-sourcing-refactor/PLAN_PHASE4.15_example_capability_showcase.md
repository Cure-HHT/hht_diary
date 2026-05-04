# Master Plan Phase 4.15: Example App Capability Showcase

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface the most demoable library capabilities — old and new — in the example app, without making it convoluted. Three highlight additions: (1) a native demo destination alongside the existing lossy one, with the FIFO panel rendering the storage-shape difference visibly; (2) an Audit Panel that exposes the new `StorageBackend.queryAudit` API; (3) an "ingest a batch" simulator + display of `origin_sequence_number` on ingested events to demonstrate Phase 4.14's unified store.

**Scoping principle (from user 2026-04-25)**: "Prefer making a finished plan over a plan which is 100% coverage." Three additions are enough. Anything beyond risks visual clutter that hides the demo's pedagogy.

**Architecture:** Additive; no structural rework of the existing app shell. The current panels stay where they are. New native demo destination is registered alongside the lossy one. The FIFO panel adds a small "format" badge + envelope summary inline. A new top-level "Audit" tab/panel uses `watchEvents` to refresh its query results when new events land. Top action bar gains an "Ingest sample batch" button that constructs a canonical `esd/batch@1` envelope from synthetic events and feeds it through `EventStore.ingestBatch`, producing entries whose `origin_sequence_number` is non-null and visible in the detail panel.

**Depends on**: Phase 4.14 fully landed. Specifically:
- Group B: `ProvenanceEntry.originSequenceNumber` field exists; ingest reassigns local sequence_number.
- Group C: `Destination.serializesNatively` declaration; library handles native serialization in fillBatch.
- Group D: `StorageBackend.queryAudit` exists; `debugDatabase()` is removed.

If Phase 4.14 has not landed when this plan starts, STOP and surface to orchestrator — the plan as written assumes 4.14's API surface.

**Tech Stack:** Flutter (the example app), Dart, `flutter/material.dart`, `event_sourcing_datastore` library.

**Decisions log:** `docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md` (decisions appended as a new "Phase 4.15" section if needed during execution).

**Branch:** `mobile-event-sourcing-refactor`. **Ticket:** CUR-1154 (continuation, but the natural close of CUR-1154's library + example scope). **Phase:** 4.15 (final phase before mobile cutover). **Depends on:** Phase 4.14 complete on HEAD.

---

## Capabilities to expose (and why these three)

| # | Capability | Origin | Demo value |
| --- | --- | --- | --- |
| 1 | Native vs lossy FIFO storage shape | Phase 4.13 + 4.14-C | Shows the storage-savings story: same events, two destinations, dramatically different per-row sizes. The FIFO panel's row tile gains a small "NATIVE" / "LOSSY" badge + a one-line summary (`{batchId, eventCount}` for native; `wire_payload: <bytes> bytes` for lossy). |
| 2 | Cross-store audit queries | Phase 4.14-D | Shows the abstraction-leak closure: a panel that queries security-context + events with filters/cursor pagination via the typed `StorageBackend.queryAudit`. No more `debugDatabase()` reach-around. |
| 3 | Unified event store + origin chain reconstruction | Phase 4.14-B | Shows the "ingested events look just like local events" story: an "Ingest sample batch" button produces events that flow through the same `event_log`, with `origin_sequence_number` visible in the detail panel for the receiver-hop provenance entry. |

## Capabilities consciously NOT exposed (per "prefer finished")

- **`watchEntry` reactive materialized view** — deferred to mobile cutover (CUR-1169) per decisions log §4.12.D. `materialized_panel.dart` keeps polling.
- **Wedge-skip stats** — Phase 4.10's optimization is invisible by design; surfacing a "skips this minute" counter would add UI without educating.
- **Verification chain visualization** — `verifyEventChain` / `verifyIngestChain` are powerful but their value lives in CI / forensics, not a demo.
- **Sync policy editor** — already a bar at the top; no expansion.
- **Schedule editor for destinations** — already in fifo_panel; no expansion.
- **Tombstone-and-refill operator UI** — already accessible; no expansion.

---

## Phase invariants

1. `flutter test` clean in `apps/common-dart/event_sourcing_datastore` (library tests unchanged or growing — example changes don't generally regress lib).
2. `flutter analyze` clean in `event_sourcing_datastore/example`.
3. The example app builds and runs (`cd apps/common-dart/event_sourcing_datastore/example && flutter run -d linux`) — manual eyeball check of the three new capabilities at phase end.
4. `grep -rn "debugDatabase" apps/common-dart/event_sourcing_datastore/example/lib/` returns ZERO hits (4.14-D removed it from lib; example does not reintroduce).

---

## Plan

### Task 1: Baseline + worklog

**Files:** Create `PHASE_4.15_WORKLOG.md`.

- [ ] **Step 1: Confirm Phase 4.14 is committed on HEAD**

```bash
git log --oneline -5
```

Look for the Phase 4.14 close commit. If absent, STOP — this plan depends on 4.14.

- [ ] **Step 2: Run baseline checks**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
```

Capture pass count + analyze status.

- [ ] **Step 3: Verify the Phase 4.14 surface is present**

```bash
grep -n "serializesNatively\|originSequenceNumber\|queryAudit" \
  apps/common-dart/event_sourcing_datastore/lib/src/destinations/destination.dart \
  apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart \
  apps/common-dart/provenance/lib/src/provenance_entry.dart 2>/dev/null
```

Expected: hits in all three. If empty, STOP and surface.

- [ ] **Step 4: Snapshot the example's current panel set**

```bash
ls apps/common-dart/event_sourcing_datastore/example/lib/widgets/
```

- [ ] **Step 5: Write `PHASE_4.15_WORKLOG.md`** (mirror Phase 4.13 worklog pattern; track 6 tasks).

- [ ] **Step 6: Commit**

```bash
git add PHASE_4.15_WORKLOG.md
git commit -m "[CUR-1154] Phase 4.15 Task 1: baseline + worklog"
```

---

### Task 2: Add `NativeDemoDestination` and register it alongside `DemoDestination`

**Files:**
- Create: `apps/common-dart/event_sourcing_datastore/example/lib/native_demo_destination.dart`
- Modify: `apps/common-dart/event_sourcing_datastore/example/lib/main.dart` (or wherever destinations are registered at boot)

- [ ] **Step 1: Read `demo_destination.dart` to mirror the existing destination's shape**

```bash
cat apps/common-dart/event_sourcing_datastore/example/lib/demo_destination.dart
```

Note the SubscriptionFilter, send-result behavior, etc.

- [ ] **Step 2: Write `native_demo_destination.dart`**

```dart
import 'package:event_sourcing_datastore/src/destinations/destination.dart';
import 'package:event_sourcing_datastore/src/destinations/subscription_filter.dart';
import 'package:event_sourcing_datastore/src/destinations/wire_payload.dart';
import 'package:event_sourcing_datastore/src/storage/send_result.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';

/// Native demo destination — declares it speaks `esd/batch@1` so the
/// library handles serialization itself (Phase 4.14 REQ-d00152). FIFO
/// rows for this destination store envelope metadata + null wire_payload
/// (REQ-d00119-K). Used in the example to demonstrate the storage-shape
/// difference vs `DemoDestination` (lossy 3rd-party).
class NativeDemoDestination implements Destination {
  NativeDemoDestination({this.id = 'demo-native'});

  @override
  final String id;

  @override
  bool get serializesNatively => true;

  @override
  String get wireFormat => 'esd/batch@1';

  @override
  SubscriptionFilter get filter => const SubscriptionFilter();

  @override
  bool get allowHardDelete => false;

  @override
  Duration get maxAccumulateTime => Duration.zero;

  @override
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate) =>
      currentBatch.length < 10;

  @override
  Future<WirePayload> transform(List<StoredEvent> batch) {
    // Library handles native serialization in fillBatch (REQ-d00152-B);
    // transform should never be called for this destination.
    throw StateError('transform must not be called on native destination');
  }

  @override
  Future<SendResult> send(WirePayload payload) async {
    // Demo: succeed for everything. Real native destinations would POST
    // to a server.
    return const SendResult.ok();
  }
}
```

(Adjust property accessors to match the actual current `Destination` interface — there may be other required getters.)

- [ ] **Step 3: Register `NativeDemoDestination` alongside the existing `DemoDestination`** in `main.dart` (or wherever registration happens). Both destinations subscribe to the same events via their filters (the default `SubscriptionFilter()` matches all); `fillBatch` produces a row in EACH destination's FIFO per matching event batch — visibly demonstrating the per-destination FIFO pattern.

- [ ] **Step 4: Run example analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
```

Expected: clean.

- [ ] **Step 5: Run lib tests** — confirm nothing broke (the example's destination doesn't run during lib tests, but the analyze cycle could surface mismatches).

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -3)
```

- [ ] **Step 6: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/example/lib/native_demo_destination.dart \
        apps/common-dart/event_sourcing_datastore/example/lib/main.dart
git commit -m "[CUR-1154] Phase 4.15 Task 2: NativeDemoDestination registered alongside lossy"
```

---

### Task 3: FIFO panel renders per-row format badge + envelope summary

**Files:** Modify `apps/common-dart/event_sourcing_datastore/example/lib/widgets/fifo_panel.dart`.

- [ ] **Step 1: Locate the row tile builder** (probably `_FifoRowTile` or similar from Phase 4.11/4.12).

- [ ] **Step 2: Add a small badge + summary**

For each FIFO row, render:

- A badge: `[NATIVE]` (green) when `entry.envelopeMetadata != null`; `[LOSSY]` (orange) otherwise.
- A summary line:
  - Native: `batch ${entry.envelopeMetadata!.batchId.substring(0,6)} | ${entry.eventIds.length} events | wire bytes recovered on demand`.
  - Lossy: `wire_payload: ${entry.wirePayload?['bytes']?.length ?? '?'} bytes`.

Keep the rest of the tile (`sequenceInQueue`, `entryId`, `finalStatus`, `attempts`) unchanged.

- [ ] **Step 3: Show BOTH destinations side-by-side**

If the FIFO panel currently shows ONE destination at a time, add a destination selector (dropdown or tab) so the user can switch between `demo-native` and `demo-lossy`. If the panel already iterates over all registered destinations (less likely), no change needed.

The simplest implementation: add a `Tab`-bar at the top of the panel listing each registered destination's id, with the body rendering that destination's FIFO snapshot via `watchFifo`.

- [ ] **Step 4: Run example analyze + manually verify (developer eyeball)**

```bash
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
```

(Manual run: `flutter run -d linux` and trigger a few `EntryService.record` calls via the existing top action bar; both destinations' FIFOs should fill, with their visibly-different storage shapes.)

- [ ] **Step 5: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/example/lib/widgets/fifo_panel.dart
git commit -m "[CUR-1154] Phase 4.15 Task 3: FIFO panel renders native/lossy badge + summary"
```

---

### Task 4: Add `AuditPanel` using `StorageBackend.queryAudit`

**Files:**
- Create: `apps/common-dart/event_sourcing_datastore/example/lib/widgets/audit_panel.dart`
- Modify: `apps/common-dart/event_sourcing_datastore/example/lib/app.dart` (add the new panel to the layout — pick the cleanest insertion point: a new tab if the app uses tabs, or a new panel slot).

- [ ] **Step 1: Sketch the panel**

```dart
class AuditPanel extends StatefulWidget {
  const AuditPanel({super.key, required this.backend});
  final StorageBackend backend;
  @override State<AuditPanel> createState() => _AuditPanelState();
}

class _AuditPanelState extends State<AuditPanel> {
  PagedAudit? _page;
  StreamSubscription<StoredEvent>? _eventsSub;
  String? _flowTokenFilter;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Re-query on every event arrival — keeps the audit list live without
    // its own polling timer.
    _eventsSub = widget.backend.watchEvents().listen((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    final page = await widget.backend.queryAudit(
      flowToken: _flowTokenFilter,
      limit: 50,
    );
    if (mounted) setState(() => _page = page);
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    if (page == null) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _filterBar(),
        Expanded(
          child: ListView.builder(
            itemCount: page.rows.length,
            itemBuilder: (context, i) {
              final row = page.rows[i];
              return ListTile(
                title: Text(row.event.eventId),
                subtitle: Text(
                  'recorded ${row.context.recordedAt.toIso8601String()}\n'
                  'initiator ${row.event.initiator.toJson()}\n'
                  'flow ${row.event.flowToken ?? "(none)"}',
                ),
              );
            },
          ),
        ),
        if (page.nextCursor != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('More rows available (cursor: ${page.nextCursor})'),
          ),
      ],
    );
  }

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        decoration: const InputDecoration(
          labelText: 'flow_token filter (blank for all)',
        ),
        onSubmitted: (v) {
          setState(() => _flowTokenFilter = v.isEmpty ? null : v);
          _refresh();
        },
      ),
    );
  }
}
```

(Adjust `Initiator.toJson()` and other accessor names to match the actual library types.)

- [ ] **Step 2: Wire it into the app shell**

Pick the cleanest insertion point. If `app.dart` uses a `TabBar`-style layout, add a new tab. If it uses a fixed grid of panels, add a new cell. Pick whichever matches the existing app shape; do NOT restructure.

- [ ] **Step 3: Run example analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
```

- [ ] **Step 4: Manual eyeball** — run the example, click around, confirm the audit panel renders rows and the filter works.

- [ ] **Step 5: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/example/lib/widgets/audit_panel.dart \
        apps/common-dart/event_sourcing_datastore/example/lib/app.dart
git commit -m "[CUR-1154] Phase 4.15 Task 4: AuditPanel using StorageBackend.queryAudit"
```

---

### Task 5: "Ingest sample batch" button + detail panel renders `originSequenceNumber`

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/example/lib/widgets/top_action_bar.dart` — add the new button.
- Modify: `apps/common-dart/event_sourcing_datastore/example/lib/widgets/detail_panel.dart` — render `originSequenceNumber` from each ProvenanceEntry when present.

- [ ] **Step 1: Add an "Ingest sample batch" button to `top_action_bar.dart`**

The button's onPressed:

```dart
final eventStore = widget.eventStore;
// Construct a synthetic batch — three fake events that look like they
// came from another device.
final syntheticEvents = <StoredEvent>[
  // Build with arbitrary aggregate_id, sequence_number = 1001/1002/1003
  // (pretend originator's seq), eventHash computed via the standard
  // hash function. Wrap in a BatchEnvelope with batchId / sender_hop /
  // sender_identifier / sender_software_version / sent_at.
  // ... (helper for this in example/lib/synthetic_ingest.dart) ...
];
final envelope = BatchEnvelope(
  batchFormatVersion: '1',
  batchId: 'demo-ingest-${DateTime.now().millisecondsSinceEpoch}',
  senderHop: 'remote-mobile-1',
  senderIdentifier: 'remote-device-uuid',
  senderSoftwareVersion: 'remote-diary@1.0.0',
  sentAt: DateTime.now().toUtc(),
  events: syntheticEvents.map((e) => e.toMap()).toList(),
);
await eventStore.ingestBatch(envelope.encode(), wireFormat: 'esd/batch@1');
```

(Extract synthetic-event construction into a new `apps/common-dart/event_sourcing_datastore/example/lib/synthetic_ingest.dart` helper for cleanness; the button just calls the helper.)

- [ ] **Step 2: In `detail_panel.dart`, render `origin_sequence_number` from receiver-hop provenance entries**

The detail panel already renders the selected event's metadata (probably as JSON or a structured view). Find where the provenance chain is rendered and add a per-entry line:

```dart
// For each ProvenanceEntry in event.metadata['provenance']:
if (entry.originSequenceNumber != null)
  Text('origin_sequence_number: ${entry.originSequenceNumber}'),
```

This makes the demonstration concrete: ingest a batch, click an ingested event in the event_stream_panel, and the detail panel shows `sequence_number: 4` (local) plus `provenance[1].origin_sequence_number: 1001` (the original).

- [ ] **Step 3: Run example analyze**

- [ ] **Step 4: Manual eyeball** — click the new button, then click an ingested event, verify the origin_sequence_number is visible.

- [ ] **Step 5: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/example/lib/widgets/top_action_bar.dart \
        apps/common-dart/event_sourcing_datastore/example/lib/widgets/detail_panel.dart \
        apps/common-dart/event_sourcing_datastore/example/lib/synthetic_ingest.dart
git commit -m "[CUR-1154] Phase 4.15 Task 5: ingest button + detail panel renders origin_sequence_number"
```

---

### Task 6: Final verification + close worklog

**Files:** `PHASE_4.15_WORKLOG.md`, `docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md`.

- [ ] **Step 1: Run full invariants**

```bash
(cd apps/common-dart/event_sourcing_datastore && flutter test 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | tail -3)
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze 2>&1 | tail -3)
```

- [ ] **Step 2: Final greps**

```bash
grep -rn "debugDatabase" apps/common-dart/event_sourcing_datastore/example/lib/
```

Expected: zero (4.14-D removed it from lib; example doesn't reintroduce).

```bash
grep -rn "Timer.periodic" apps/common-dart/event_sourcing_datastore/example/lib/
```

Expected: same as Phase 4.12 §4.12.F — only the intentional remainders (main.dart drain ticker, materialized_panel, comments).

- [ ] **Step 3: Manual eyeball checklist**

Document in the worklog:
- Native vs lossy FIFO badges visible: yes/no.
- Audit panel renders rows + filter works: yes/no.
- Ingest button works + originSequenceNumber visible in detail panel: yes/no.

- [ ] **Step 4: Worklog update + decisions-log close line.**

- [ ] **Step 5: Commit**

```bash
git add PHASE_4.15_WORKLOG.md docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md
git commit -m "[CUR-1154] Phase 4.15 Task 6: close worklog (final verify clean)"
```

- [ ] **Step 6: Surface phase-end summary** + run-end summary.

---

## What does NOT change in this phase

- `materialized_panel.dart` polling — deferred to mobile cutover (CUR-1169).
- Existing `DemoDestination` (lossy) — unchanged; it's the comparison reference for the new native one.
- Sync policy, schedule editor, tombstone-and-refill UI — unchanged.
- Any library code — this phase is example-only.
- Storage internals visibility (raw store inspection panels) — out of scope; the audit panel demonstrates abstraction-leak closure, not raw inspection.

## Risks

### Risk 1: Two destinations doubles FIFO panel render cost

Each `watchFifo` subscription costs one snapshot fetch per FIFO mutation. Two destinations × N mutations = 2N fetches. At demo scale this is negligible; at production scale a coordination layer would help (deferred per §4.12.E).

### Risk 2: Synthetic ingest needs valid hash chain

`EventStore.ingestBatch` performs Chain 1 verification — if the synthetic events' `previous_event_hash` chain is malformed, ingest throws `IngestChainBroken`. Mitigation: the synthetic-ingest helper computes the chain correctly using the standard hash function; if that's tricky to do from inside the example app, restrict the demo to a single synthetic event per batch (no chain to validate beyond the bottom).

### Risk 3: AuditPanel queryAudit returns empty for stock demo

Audit rows exist only when events have been recorded WITH security context (which the example may or may not do today). Mitigation: confirm the example records events with security context — if not, add a simple "set context" toggle on the top action bar so the demo can populate the audit log.

### Risk 4: Detail panel rendering becomes cluttered with origin_sequence_number lines

If every provenance entry gets a verbose line, the detail panel grows unwieldy. Mitigation: only show `origin_sequence_number` when non-null (i.e., on receiver-hop entries — most local events show none).
