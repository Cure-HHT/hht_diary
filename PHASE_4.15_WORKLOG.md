# Phase 4.15 Worklog — Example App Capability Showcase (CUR-1154)

**Plan:** docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.15_example_capability_showcase.md
**Decisions log:** docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md (Phase 4.15 section if appended)
**Branch:** mobile-event-sourcing-refactor
**Depends on:** Phase 4.14 closed at 42663666

## Baseline (Task 1)

- event_sourcing_datastore: +595 All tests passed
- analyze (event_sourcing_datastore lib): No issues found
- analyze (event_sourcing_datastore/example): No issues found
- Phase 4.14 surface present:
  - `Destination.serializesNatively` — lib/src/destinations/destination.dart:95
  - `ProvenanceEntry.originSequenceNumber` — apps/common-dart/provenance/lib/src/provenance_entry.dart:141
  - `StorageBackend.queryAudit` — lib/src/storage/storage_backend.dart:594
- Example panel set snapshot (lib/widgets/): add_destination_dialog, detail_panel,
  event_stream_panel, fifo_panel, materialized_panel, styles, sync_policy_bar,
  top_action_bar.
- Example lib root: app.dart, app_state.dart, demo_destination.dart,
  demo_sync_policy.dart, demo_types.dart, main.dart, widgets/.

## Tasks

- [x] Task 1: Baseline + worklog
- [x] Task 2: NativeDemoDestination registered alongside lossy DemoDestination
- [x] Task 3: FIFO panel renders per-row format badge + envelope summary
- [x] Task 4: AuditPanel using StorageBackend.queryAudit
- [x] Task 5: Ingest sample batch button + detail panel renders origin_sequence_number
- [x] Task 6: Final verification + close worklog

## Task 3 notes

- AppState.destinations widened from `List<DemoDestination>` to
  `List<Destination>` so the Native destination gets its own column. The
  FIFO panel branches on `Destination is DemoDestination` for the
  connection / latency / batch-size knobs (only DemoDestination carries
  them); native destinations render the header + FIFO list without knobs.
  This keeps the existing per-destination column layout in `app.dart`
  unchanged — no TabBar / dropdown insertion needed.
- Per-row badge: `[NATIVE]` (DemoColors.green) when
  `entry.envelopeMetadata != null`; `[LOSSY]` (DemoColors.accent)
  otherwise.
- Per-row summary line:
  - native: `batch <first 6 chars of batchId> | <eventCount> events | wire bytes recovered on demand`
  - lossy: `wire_payload: <utf8.encode(jsonEncode(payload)).length> bytes`
    — `wirePayload` on `FifoEntry` is the decoded JSON Map (the path
    `enqueueFifo` runs `jsonDecode` on the bytes before persisting), so
    re-encoding gives a stable, comparable byte count.
- Format badge also shown in panel header (above schedule label) so the
  destination's format is identifiable even when the FIFO is empty.
- Test update: `app_state_test.dart` 'destinations reflects only
  DemoDestination instances' rewritten as 'destinations reflects every
  registered destination' (no behavioral assertion change beyond the
  rename — both DemoDestination instances still appear).

## Task 4 notes

- AuditPanel slotted into `app.dart` as a fixed-width resizable column
  between EventStreamPanel and the per-destination FIFO columns. No
  shell restructure — fits the existing multi-column resizable layout
  verbatim.
- Live re-query subscribes to `StorageBackend.watchEvents()` rather
  than polling. Filter bar lets the user constrain by `flow_token`.
- Stock demo's `EventStore.append` calls did NOT pass `SecurityDetails`
  initially, so the panel rendered an empty-state with a hint pointing
  at the future "set demo security context" toggle (Plan §4.15 Task 4
  Risk 3, mitigation (a)). Toggle delivered in Task 5 per §4.15.A.

## Task 5 notes

- "Ingest batch" button on the system row builds a one-event
  `esd/batch@1` envelope (sender_hop=remote-mobile-1,
  origin_sequence_number=1001) via SyntheticBatchBuilder and feeds it
  through `EventStore.ingestBatch`. Single-event-per-batch by design:
  chain-1 verification walks `provenance[len-1..1]`, so a single origin
  entry trivially passes — no canonical event_hash required.
- Detail panel for a selected event now renders a per-provenance-entry
  summary line above the JSON dump, surfacing `origin_sequence_number`
  (REQ-d00115-K) and `ingest_sequence_number` (REQ-d00115-I) when set.
  Local events show `[0] hop=mobile-device` with no seq lines; ingested
  events show `[1] hop=mobile-device ingest_seq=N origin_seq=1001` —
  the unified-event-store property of Phase 4.14-B made concrete.
- Plan §4.15.A: "sec ctx" Switch on the system row. When ON, every
  `_record()` call passes `_kDemoSecurityDetails` (fixed
  ip/userAgent/sessionId/geo/requestId) so `security_context` populates
  and AuditPanel renders non-empty rows. Off by default so the empty-
  state in AuditPanel stays observable.

## Final verification (Task 6)

- event_sourcing_datastore: +595 All tests passed
- provenance: +45 All tests passed
- analyze (event_sourcing_datastore lib): No issues found
- analyze (event_sourcing_datastore/example): No issues found
- analyze (provenance): No issues found
- `grep -rn debugDatabase apps/common-dart/event_sourcing_datastore/example/lib/` — zero hits (4.14-D removed; example doesn't reintroduce).
- `grep -rn "Timer.periodic" apps/common-dart/event_sourcing_datastore/example/lib/` — same intentional remainders as Phase 4.12 §4.12.F:
  - `widgets/materialized_panel.dart:31` (deferred to CUR-1169 mobile cutover, per §4.12.D)
  - `main.dart:109` (drain ticker — by design)
  - `main.dart:101` and `demo_sync_policy.dart:20` (comments only)

### Manual eyeball checklist (orchestrator runs the example app)

- [ ] Native vs lossy FIFO badges visible side-by-side: trigger a few
  `EntryService.record` calls via the top action bar; both `demo-native`
  and `demo-lossy` columns should fill, native rows show `[NATIVE]` +
  `batch …` summary, lossy rows show `[LOSSY]` + `wire_payload: N bytes`.
- [ ] AuditPanel renders rows + filter works: turn the "sec ctx" switch
  ON in the top action bar, record a few entries, watch the AuditPanel
  populate live; type a flow_token into the filter bar and confirm rows
  narrow.
- [ ] Ingest button works + originSequenceNumber visible in detail panel:
  click "Ingest batch", click the resulting ingested event in the event
  stream panel, the detail panel's provenance summary line should show
  `[1] hop=mobile-device ingest_seq=N origin_seq=1001`.
