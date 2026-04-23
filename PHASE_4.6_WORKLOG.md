# Phase 4.6 Worklog

One section per completed task. Current state only — no diff narration.

---

## Per-task controller workflow (user instructions — re-read each task)

> After each phase I want you to:
> - append to `PHASE_4.6_WORKLOG.md` a very brief outline of the work done. Don't say "it was like that before, now its like this." Just say "it works like this". I.e. don't keep repeating history, just report the status.
> - commit the changes
> - Launch a sub-agent to review the commit. Tell it NOT to read the `docs/` folder. I want an unbiased code review.
> - decide which of the review comments to address and which to not address. Log both to WORKLOG.
> - commit again
> - include these instructions at the end of WORKLOG each phase.
> - re-read these instructions.
> Then proceed to the next phase.

("phase" here denotes each numbered task of Phase 4.6; the full Phase 4.6 lands as one squashed commit per the user's preference. Per the user's kickoff direction, Phase 4.6 uses a single consolidated review at phase end — mirroring Phase 4.4 / 4.5.)

---

## Scope decision (kickoff, 2026-04-23)

Phase 4.5 carries re-evaluated at 4.6 kickoff — all three dropped:

- **Storage-health query/stream surface** — no demo journey consumes it; signal would never flip on a Linux-desktop review walk.
- **`FailureInjector` test seam** — the demo already *is* the failure injector at the Destination layer (`DemoDestination.connection` + `sendLatency`); backend-level injection has no UI and no journey.
- **`EntryService.record` / `EventStore.append` classification wrap** — library polishing with no observable demo effect; deserves its own phase when a real consumer (portal ingest, background sync) lands.

Net: Phase 4.6 proceeds exactly as `PLAN_PHASE4.6_demo.md` is written. No plan edits beyond the REQ-d placeholder substitutions required by Task 1.

Out-of-scope-entirely items remain out of scope (storage-failure audit log, MaterializedView read-corruption recovery — per memory `project_event_sourcing_refactor_out_of_scope.md`).

---

## Plan

`docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.6_demo.md` — 16 tasks building a Flutter Linux-desktop sandbox at `apps/common-dart/append_only_datastore/example/` that exercises every library feature shipped in Phases 4 / 4.3 / 4.4 via live UI. Acceptance = reviewer-walked nine-scenario USER_JOURNEYS. No widget tests, no integration tests, no CI (design non-goals §4.2). Unit tests on value objects (styles palette, demo types, demo destination, demo sync policy, app state).

## Task 1: Baseline verification

### Git state

- HEAD before rebase: `b2cf5699` (Phase 4.5 tip, from memory)
- `origin/main` moved one commit (`5f430f7b..9f4aa87d`) during Phase 4.4/4.5 — CUR-1111 admin_action_log constraint fix. Main's change touches `diary_functions/questionnaire_submit.dart` + four pubspec version bumps + two SQL files; zero overlap with `append_only_datastore/`.
- Rebased the 64-commit branch onto `origin/main` with `-X ours` (keeps main's newer pubspec versions at conflict points; no real code conflicts). New HEAD: `abcf3315`. All Phase 4.4 + 4.5 artifacts intact (`storage_exception.dart`, `classifyStorageException`, EventStore, materialization lib, security sidecar).
- Carried `.githooks/pre-commit` working-tree change (ELSPAIS_VERSION unset fix) stashed through the rebase and restored afterward — orthogonal to Phase 4.6.

### Baseline tests (post-rebase)

- `append_only_datastore` (`flutter test`): **472 pass**; `dart analyze --fatal-infos` clean
- `provenance` (`dart test`): **31 pass**; `dart analyze` clean
- `trial_data_types` (`dart test`): **59 pass**; `dart analyze` clean
- `clinical_diary` (`flutter test`): **1098 pass** (1 skip); `flutter analyze` clean

### REQ-d number substitution

Plan authored before Phase 4.3 landed; its applicable-REQ table used topic-name placeholders. Substitutions (from `spec/dev-event-sourcing-mobile.md` and library REQ-citation headers):

| Plan placeholder | Actual REQ-d | Title |
| --- | --- | --- |
| REQ-ENTRY | REQ-d00133 | EntryService.record Contract |
| REQ-BOOTSTRAP | REQ-d00134 | bootstrapAppendOnlyDatastore Contract |
| REQ-SYNCPOLICY | REQ-d00126 | SyncPolicy Injectable Value Object |
| REQ-SYNCCYCLE | REQ-d00125 | sync_cycle() Orchestrator and Trigger Contract |
| REQ-DEST | REQ-d00122 | Destination Contract for Per-Destination Sync |
| REQ-DYNDEST | REQ-d00129 | Dynamic Destination Lifecycle |
| REQ-REPLAY | REQ-d00130 | Historical Replay on Past startDate |
| REQ-TIMEWINDOW | REQ-d00129-I | (time-window clause of Dynamic Destination Lifecycle) |
| REQ-BATCH | REQ-d00128 | (batch shape, canAddToBatch, maxAccumulateTime, transform) |
| REQ-FIFO | REQ-d00119 | Per-Destination FIFO Queue Semantics |
| REQ-UNJAM | REQ-d00131 | Unjam Destination Operation |
| REQ-REHAB | REQ-d00132 | Rehabilitate Exhausted FIFO Row |
| REQ-SKIPMISSING | REQ-d00127 | markFinal and appendAttempt Tolerate Missing FIFO Row |

Plan's applicable-REQ table updated in-place with these substitutions.

### Library-surface notes (plan line 83 reconciliation)

Plan asked for these symbols to be exported from `package:append_only_datastore/append_only_datastore.dart`. Actual surface differs in three spots; demo adapts per plan's own "exact names must match the Phase-4.3-shipped API" admonition (lines 249, 347, 392, 463, 537 of the plan):

- `EntryTypeDefinition` — lives in `package:trial_data_types/trial_data_types.dart`, not in the datastore barrel. Example's `pubspec.yaml` will declare `trial_data_types` as a direct dep at Task 3.
- `Event` — canonical event value type is `StoredEvent` (exported). `Destination.canAddToBatch` / `transform` take `List<StoredEvent>`. Demo uses `StoredEvent` throughout.
- `syncCycle` — not a top-level function. `SyncCycle` is a class (exported); caller constructs one and invokes `.call()`. Demo's `main.dart` Timer.periodic will hold a `SyncCycle` instance and call `.call()`.

All other plan-required symbols are exported as expected: `bootstrapAppendOnlyDatastore`, `AppendOnlyDatastore`, `EntryService`, `EntryTypeRegistry`, `Destination`, `SubscriptionFilter`, `DestinationRegistry`, `WirePayload`, `SendOk`, `SendTransient`, `SendPermanent`, `SyncPolicy`, `rebuildMaterializedView`, `UnjamResult`, `SetEndDateResult`, plus Phase 4.4/4.5 additions (`EventStore`, `StorageException` + variants, `classifyStorageException`, `Materializer`, `DiaryEntriesMaterializer`, security sidecar).

### Bootstrap shape (plan Task 9 reconciliation)

`bootstrapAppendOnlyDatastore` actual signature:
- Requires `backend`, `source`, `entryTypes`, `destinations`; optional `materializers`, `syncCycleTrigger`.
- Returns `AppendOnlyDatastore` facade with fields `eventStore`, `entryTypes`, `destinations` (the DestinationRegistry), `securityContexts`.
- Demo's `main.dart` will additionally construct an `EntryService` (for the Task 12 lifecycle buttons) since the facade does not expose one, passing `backend`, `entryTypes`, `syncCycleTrigger`, `deviceInfo`.

Task 9 template in the plan will be adjusted to this shape during implementation (per plan's own explicit allowance).

---

## Task 2: Scaffold the `example/` Flutter Linux-desktop app

`flutter create --platforms=linux --org com.example --project-name append_only_datastore_demo .` ran inside `apps/common-dart/append_only_datastore/example/`. Scaffold is clean:

- `pubspec.yaml` with `flutter` + `flutter_test` deps (Task 3 rewrites to add `append_only_datastore` + `trial_data_types` path deps).
- `analysis_options.yaml` with default lints (Task 3 switches to inherit parent package's config).
- `lib/main.dart` emptied to `// Rewritten in Task 9.`.
- `test/widget_test.dart` deleted (design §4.2 non-goal).
- `linux/` runner scaffold (CMakeLists + `main.cc` + `my_application.cc/h`).
- `.metadata` and `README.md` from the scaffold kept as-is.
- `.gitignore` extended: `.flutter-plugins`, `.packages`, `/linux/flutter/ephemeral/`.

`flutter pub get` and `flutter analyze` inside the example — no issues found.

---

## Task 3: Wire `example/pubspec.yaml` to parent package

`example/pubspec.yaml` has a path dep on `append_only_datastore` (`../`) and a direct path dep on `trial_data_types` (`../../trial_data_types`) — the latter is required because `EntryTypeDefinition` lives in `trial_data_types`, not in the datastore barrel, and the demo constructs instances of it at Task 5.

`flutter_lints: ^6.0.0` kept in `dev_dependencies` — needed to resolve the `package:flutter_lints/flutter.yaml` include chained in via `../analysis_options.yaml`. Dev-deps are not transitive, so the example declares its own copy; dropping it breaks analyze with `include_file_not_found`. Commented in pubspec.

`example/analysis_options.yaml` reduced to `include: ../analysis_options.yaml` — demo is held to the same strict lint bar as the library (`strict-casts`, `strict-inference`, `require_trailing_commas`, `prefer_const_constructors`, long linter list).

`flutter pub get` resolves cleanly; `flutter analyze` — no issues found.

---

## Task 4: `styles.dart` — palette tripwire

`lib/widgets/styles.dart` declares three static-only surfaces:

- `DemoColors` — 12 `static const Color` fields covering the design §7.4 palette (bg, fg, accent, sent, pending, retrying, exhausted, selected, border; action-button red/green/blue).
- `DemoText` — `bodyFontSize = 20.0`, `headerFontSize = 24.0`, `fontFamilyMonospace = 'monospace'`, plus two `static const TextStyle`s (`body` white on bg; `header` accent-yellow).
- `demoBorder` — `final Border` via `Border.all(color: DemoColors.border, width: 3.0)` — rectangular, 3px white, same on all four sides.

`test/styles_test.dart` — 19 tripwire tests asserting every hex, both font sizes (header within inclusive [24, 28]), both TextStyles' fontSize + fontFamily round-trips, and the per-side Border width+color. Each group header cites "design §7.4 palette lock".

**Final state**: example — 19 tests pass; `flutter analyze` clean.

---

## Task 5: `demo_types.dart` — entry type definitions

Four `const EntryTypeDefinition` top-level instances — `demoNoteType`, `redButtonType`, `greenButtonType`, `blueButtonType` — plus `allDemoEntryTypes` (registered at bootstrap) and `demoAggregateTypeByEntryTypeId` (lookup used by the Task 12 action buttons when calling `eventStore.append(aggregateType:)`).

`EntryTypeDefinition` (from `trial_data_types`) does **not** carry an `aggregateType` field in the shipped REQ-d00116 shape; the CQRS discriminator the plan describes lives on the event, not on the type definition. `EventStore.append` (REQ-d00141-B) takes `aggregateType` as a per-call argument, so the demo keeps a plain id-keyed map and passes the looked-up value into each `append` call.

`demo_note` maps to `'DiaryEntry'` and materializes (has `effectiveDatePath: 'date'`). The three action buttons each have `widgetId: 'action_button_v1'`, `effectiveDatePath: null`, and distinct aggregate types (`RedButtonPressed` / `GreenButtonPressed` / `BlueButtonPressed`) — this is the JNY-02 CQRS invariant.

`test/demo_types_test.dart` — 18 tests cover per-type id/widgetId/effectiveDatePath, per-id aggregate-type lookup, non-'DiaryEntry' action predicates, and the all-entries list shape (4 entries, unique ids, expected contents).

**Final state**: example — 37 tests pass (+18 from Task 4); `flutter analyze` clean.

---

## Task 6: `demo_destination.dart` — DemoDestination class

`lib/demo_destination.dart` declares `enum Connection { ok, broken, rejecting }` and `class DemoDestination implements Destination`:

- `id`, `allowHardDelete` final fields; `wireFormat = 'demo-json-v1'`; `filter = const SubscriptionFilter()` (null allow-lists = match everything).
- Four `ValueNotifier` fields live-tunable from UI: `connection`, `sendLatency`, `batchSize`, `maxAccumulateTimeN`.
- `maxAccumulateTime` getter reads the notifier value each call.
- `canAddToBatch` returns `currentBatch.length < batchSize.value` — empty batch always accepts; full batch rejects next candidate.
- `transform(batch)` encodes `{"batch": [event1.toJson(), ...]}` as UTF-8 JSON, contentType `application/json`, transformVersion `demo-v1`.
- `send(payload)` switches on `connection.value`: `ok` → awaits `sendLatency` then `SendOk`; `broken` → `SendTransient(error: 'simulated disconnect')` immediately; `rejecting` → `SendPermanent(error: 'simulated rejection')` immediately.

`test/demo_destination_test.dart` — 14 tests cover identity (id, wireFormat, filter), `allowHardDelete` default + opt-in, `canAddToBatch` at batchSize 1/5 and empty-batch edge, `maxAccumulateTime` notifier reading, `transform` round-trip (contentType, transformVersion, JSON-decoded batch length + per-event-id verification), all three `send` branches with latency/timing assertions, and initial-value constructor seeding.

**Final state**: example — 51 tests pass (+14 from Task 5); `flutter analyze` clean.

---

## Task 7: `demo_sync_policy.dart` — defaults + notifier

`lib/demo_sync_policy.dart` declares:

- `demoDefaultSyncPolicy`: `const SyncPolicy(initialBackoff: 1s, backoffMultiplier: 1.0, maxBackoff: 10s, jitterFraction: 0.0, maxAttempts: 1_000_000, periodicInterval: 1s)` per design §7.7. Short backoff so retry cadence is observable live without waiting minutes.
- `demoPolicyNotifier`: `final ValueNotifier<SyncPolicy>` seeded with `demoDefaultSyncPolicy`. Task 12's sync-policy bar mutates this; `main.dart`'s Timer tick reads it at every cycle.

Shipped `SyncPolicy` carries a sixth `periodicInterval` field not called out in the plan (foreground cadence, REQ-d00123-F). Demo seeds it to 1s — a no-op for the reviewer because `main.dart` runs its own Timer.periodic — but the constructor needs every required field.

`test/demo_sync_policy_test.dart` — 8 tests cover all six default fields, `demoPolicyNotifier` initial-value identity, `ValueNotifier<SyncPolicy>` type, and listener-notification semantics on `.value = ...` (uses a local notifier to avoid process-wide leakage).

**Final state**: example — 59 tests pass (+8 from Task 6); `flutter analyze` clean.

---

## Task 8: `app_state.dart` — ChangeNotifier with selection + registry binding

`lib/app_state.dart` declares `class AppState extends ChangeNotifier`:

- Three nullable `String` selection fields (`selectedAggregateId`, `selectedEventId`, `selectedFifoRowId`); public getters.
- Four mutators — `selectAggregate`, `selectEvent`, `selectFifoRow`, `clearSelection` — each sets the chosen field, nulls the other two (mutually exclusive cross-panel selection), and calls `notifyListeners()` once.
- `destinations` getter filters `registry.all()` through `whereType<DemoDestination>()` so the UI controls (sliders, schedule editors, ops drawer) are typed to `DemoDestination` knobs.
- `addDestination(DemoDestination)` awaits the registry's async `addDestination` and notifies.
- `policyNotifier` is held as a final field; widget tasks read it directly.

`test/app_state_test.dart` — 10 tests with a real `DestinationRegistry` backed by `sembast_memory` (shipped test pattern from the library test corpus):

- All three initial selections null.
- Each mutator selects its field and clears the other two (3 tests).
- `clearSelection` resets and notifies once.
- Each setter notifies exactly once per call.
- `destinations` empty when registry is empty; reflects added `DemoDestination`s in registration order (including `allowHardDelete: true`).
- `addDestination` notifies after the registry call resolves.
- `policyNotifier` identity round-trip.

`sembast` added as a direct dev dep so `depend_on_referenced_packages` is satisfied (lint requires transitive imports to declare themselves).

**Final state**: example — 69 tests pass (+10 from Task 7); `flutter analyze` clean.

---

## Task 9: `main.dart` + `app.dart` — bootstrap and root widget

`lib/main.dart`:

- Resolves the Linux app-support dir via `path_provider`, creates `append_only_datastore_demo/demo.db`, logs the path.
- Opens sembast via `databaseFactoryIo` and constructs a `SembastBackend`.
- Instantiates two boot destinations (`Primary` allowHardDelete:false, `Secondary` allowHardDelete:true).
- Calls `bootstrapAppendOnlyDatastore(backend, source, entryTypes: allDemoEntryTypes, destinations, materializers: [DiaryEntriesMaterializer()])`.
- Sets both destinations' `startDate` to `DateTime.now().toUtc()`.
- Constructs `AppState(registry: datastore.destinations, policyNotifier: demoPolicyNotifier)`.
- Runs a `Timer.periodic(1s)` that per-tick calls `fillBatch` then `drain` on every destination. Drain reads the live policy from `demoPolicyNotifier.value` so slider changes take effect next tick.

SyncCycle is **not** used by the demo. `SyncCycle.call` captures `policy` at construction time (Phase 4 wiring) and does not drive `fillBatch` (library test corpus explicitly orchestrates `fillBatch → drain` in sequence). The demo's direct tick loop matches the needed shape for live policy hot-swap + per-tick fillBatch.

`lib/app.dart`:

- `DemoApp` is a `StatefulWidget` with constructor passthrough for `datastore`, `backend` (typed `SembastBackend` for the `.close()` hook), `appState`, `dbPath`, `tickController`. No provider/riverpod dep — Tasks 10-13 read these from the widget tree directly.
- `MaterialApp` with dark theme; `Scaffold` body is a `Column` of `[TopActionBar placeholder, SyncPolicyBar placeholder, Expanded(Row of 4 column placeholders: MATERIALIZED, EVENTS, FIFO-per-destination, DETAIL)]`. Each placeholder uses `demoBorder` + `DemoText.header` so the palette lock is exercised as-shipped.
- `resetAll()` method cancels the tick, closes the backend, deletes the db file. Wired to the Task 12 `[Reset all]` button.

Direct deps added to `example/pubspec.yaml`: `path`, `path_provider`, `sembast` — shape-forced by `depend_on_referenced_packages`. `flutter_lints` remains in dev_deps.

**Final state**: example — `flutter analyze` clean; no new tests (widget code per design non-goal §4.2). Compile-only verification; `flutter run -d linux` smoke is Task 14.

---

## Task 10: MATERIALIZED + EVENTS read panels

`lib/widgets/materialized_panel.dart`:

- `StatefulWidget` with `Timer.periodic(500ms)` that calls `backend.findEntries(entryType: 'demo_note')` and stores the list.
- Listens to `appState` for selection repaint.
- Header `MATERIALIZED` in `DemoText.header`; rows render `agg-<short8> [ok|ptl|del]` per design §7.5.
- Row tint flips to `DemoColors.selected` when `appState.selectedAggregateId` matches. Tap → `selectAggregate(entryId)`.

`lib/widgets/event_stream_panel.dart`:

- Same shape; `Timer.periodic(500ms)` → `backend.findAllEvents(limit: 500)`; sorted by `sequenceNumber`.
- Header `EVENTS`; rows render `#<seq> <short_event_type> <aggregate_type> <short_agg_id>`.
- Row tint on `appState.selectedEventId` match. Tap → `selectEvent(eventId)`.
- Renders every event regardless of `aggregate_type` (JNY-02 needs action events visible here, next to their distinct aggregate types).

Both panels wired into `app.dart`'s observation grid as the first two columns; FIFO + DETAIL slots still placeholders.

**Final state**: example — `flutter analyze` clean.

---

## Task 11: `fifo_panel.dart`

One per destination. Stateful widget whose build pulls from:

- `widget.appState.registry.scheduleOf(id)` every 500ms → schedule label (`DORMANT` / `SCHEDULED until …` / `ACTIVE` / `CLOSED @ …`).
- `intMapStoreFactory.store('fifo_<id>').find(widget.backend.debugDatabase())` every 500ms → FIFO rows as raw maps. No shipped `listFifoRows` API; the demo reaches into `debugDatabase()` (documented as "for tests that need to inspect raw stores"). Rows render per design §7.5 state prefixes (`[SENT]` green, `[exh]` magenta, `> ` red+retrying, `[pend]` white).
- Listens to all four destination `ValueNotifier`s (`connection`, `sendLatency`, `batchSize`, `maxAccumulateTimeN`) so slider drags propagate immediately.

Column stack top-down:

1. Title (`destination.id.toUpperCase()` in `DemoText.header`).
2. Schedule state label in accent yellow.
3. Start-date text editor — ISO-8601 input, visible while the destination is DORMANT or future-SCHEDULED. `[Set]` button calls `registry.setStartDate`.
4. End-date text editor — always visible. `[Set]` calls `registry.setEndDate` and flashes the `SetEndDateResult` (`scheduled` / `closed`) in a 2-second banner.
5. Connection dropdown bound to `destination.connection`.
6. Three sliders: `sendLatency` (0-30s in ms), `batchSize` (1-50), `maxAccumulateTimeN` (0-30s). Each slider's numeric label renders the current int value.
7. Collapsible ops drawer (`ops ▸` / `ops ▾`) with `[Unjam]`, `[Rehabilitate all]`, and — gated on `destination.allowHardDelete` — `[Delete destination]`.
8. Transient banner slot for op-result messages.
9. Scrolling FIFO row list with per-row inline `rehab` button on exhausted rows.

Tapping a row → `appState.selectFifoRow(entryId)`; blue-tint on match.

Ops functions imported via `package:append_only_datastore/src/ops/...` with `// ignore: implementation_imports` — they're not exported from the barrel. Library tests use the same pattern; the demo matches convention.

`app.dart` wires one `FifoPanel` per `appState.destinations` entry, wrapped in `ListenableBuilder(listenable: appState)` so add/delete destination rebuilds the column strip. Panels key on destination id to preserve state across rebuilds.

**Final state**: example — `flutter analyze` clean.

---

## Task 12: `top_action_bar.dart` + `sync_policy_bar.dart`

`lib/widgets/top_action_bar.dart` — two-row bar:

- **Row 1 (demo_note lifecycle)**: title / body / mood text fields; `[Start]` / `[Complete]` / `[Delete]` buttons. All three use `datastore.eventStore.append(aggregateType: 'DiaryEntry', ...)` — the Phase 4.4 write API. `EntryService.record` hardcodes `aggregate_type = 'DiaryEntry'` (line 215 of `entry_service.dart`), so it cannot produce the action-type events JNY-02 needs; the demo standardizes on `EventStore.append` for every write path.
- **Row 2 (actions + system)**: `[RED]` / `[GREEN]` / `[BLUE]` action buttons (each press → new aggregate id, `entryType` `<color>_button_pressed`, `aggregateType` from `demoAggregateTypeByEntryTypeId`); `[Add destination]` (opens `AddDestinationDialog`); `[Rebuild view]` (calls `rebuildMaterializedView(backend, entryTypeLookup)` positionally, surfaces count via SnackBar); `[Reset all]` with a confirm dialog that routes to `DemoApp.resetAll()`.

Button-dim logic: `[Complete]` and `[Delete]` are disabled when no aggregate is selected.

`lib/widgets/sync_policy_bar.dart` — five live-tunable sliders:

- `init` (initialBackoff 100-30000 ms)
- `mult` (backoffMultiplier 1.0-5.0)
- `max` (maxBackoff 1-120 s)
- `jit` (jitterFraction 0.0-1.0)
- `attempts` (maxAttempts 1-1,000,000, log-scaled: `value = log(p.maxAttempts)/log(1M)` mapped through `pow(1M, value)` on change)

Every slider drag constructs a fresh `SyncPolicy` value (carrying the unchanged `periodicInterval`) and stores it on `demoPolicyNotifier`. The `main.dart` Timer reads `demoPolicyNotifier.value` at next tick; drain applies the new curve immediately.

---

## Task 13: `add_destination_dialog.dart` + `detail_panel.dart`

`lib/widgets/add_destination_dialog.dart` — modal:

- id text field (required; inline error on empty).
- `allowHardDelete` checkbox.
- Optional `initialStartDate` ISO-8601 input — non-empty + valid → `setStartDate` called after add.
- Catches `ArgumentError` from registry `addDestination` (duplicate id) and surfaces inline.

`lib/widgets/detail_panel.dart` — rightmost column (width 320):

- 500ms polling gives the live summary (events count, aggregates count, `anyFifoExhausted` + list of exhausted destination ids, current policy snapshot) when no selection is active.
- On `selectedAggregateId` → scans `backend.findEntries()` for the match, renders the `DiaryEntry` row as pretty JSON (entry_id, entry_type, is_complete, is_deleted, updated_at, current_answers, latest_event_id).
- On `selectedEventId` → scans `backend.findAllEvents(limit: 100000)` for the event and renders its full `StoredEvent.toMap()` (event_id, sequence_number, aggregate_id, aggregate_type, entry_type, event_type, client_timestamp, event_hash, previous_event_hash, data, metadata).
- On `selectedFifoRowId` → scans every destination's FIFO store via `backend.debugDatabase()` and renders the full row map.

Inner `_AsyncJson` stateful helper handles the async load + pretty-print; `didUpdateWidget` reloads on selection change.

`main.dart` now builds a `_RegistryLookup` adapter over `EntryTypeRegistry.byId` and passes it to `DemoApp` so `rebuildMaterializedView` can consume it.

`app.dart`: placeholders gone; `_PlaceholderBanner` class deleted as unused.

**Final state**: example — 69 tests pass (unchanged — widget code per §4.2 no-tests non-goal); `flutter analyze` clean. Demo compile-ready end-to-end; Task 14 is the `flutter run -d linux` smoke.

---

## Sync tick reentrancy fix (2026-04-23 — Task 14 smoke regression)

First smoke-run surfaced a `Bad state: markFinal(... FinalStatus.sent): entry is already FinalStatus.sent; final_status transitions are one-way.` stack trace from `drain` called inside the Timer.

Root cause: my `main.dart` Timer.periodic had no reentrancy guard. With `DemoDestination`'s default `sendLatency = 10s`, a tick can take ≥ 10s to complete; the next 1s-scheduled Timer fires concurrently. Two drain invocations on the same destination both observe the same pending head, both call `destination.send()`, both attempt `markFinal(...sent)` — the second throws because `final_status` transitions are one-way.

This is exactly the race `SyncCycle`'s `_inFlight` guard solves (REQ-d00125-C: "allowing concurrent sync cycles would produce overlapping send calls that each see the same pending head entry and each record an attempt"). Bypassing `SyncCycle` (needed for per-tick live policy from `demoPolicyNotifier`) meant the guard had to be rebuilt in demo code.

Fix:

- `syncInFlight` boolean in the Timer closure; ticks that land while a prior run is still in flight return immediately (matches `SyncCycle.call` line 52).
- `fillBatch` + `drain` now run concurrently across destinations via `Future.wait`, matching `SyncCycle`'s per-destination fan-out (REQ-d00125-A). Sembast serializes writes internally; `destination.send()` is outside the transaction, so concurrent destinations genuinely overlap their simulated-network waits — which is what JNY-01's "both FIFOs drain independently" expects.

`flutter analyze` clean; unit tests untouched (this is a main.dart-only change).

## Restart-safety fix (2026-04-23 — second smoke crash)

Post-reentrancy-fix restart crashed at boot with `DestinationRegistry.setStartDate(Primary): startDate is already set to 2026-04-23T…; startDate is immutable once assigned (REQ-d00129-C)`. The registry persists schedules across process restarts (`addDestination` reads the persisted schedule back); unconditionally re-calling `setStartDate` at every boot is a one-shot-immutable violation on the second run.

Fix: main.dart now reads `scheduleOf(id)` first and only calls `setStartDate` when `schedule.startDate == null` (i.e. a genuinely dormant first-boot schedule). On restart the persisted startDate is read back and the call is skipped — idempotent boot.

---

## TopActionBar listener fix (2026-04-23 — smoke)

`[Complete]` / `[Delete]` appeared permanently disabled. Root cause: `TopActionBar` is a `StatefulWidget` but never subscribed to `appState`, so the `dim: widget.appState.selectedAggregateId == null` check was evaluated once at initial build (selection null → buttons dim) and never re-evaluated. `[Start]` calls `selectAggregate` correctly, but the bar didn't rebuild.

Fix: `initState` adds `appState.addListener(_onAppState)`; `dispose` removes it; `_onAppState` does a no-arg `setState`. Same pattern as the other panels.

---

## UI tweak (2026-04-23 — smoke feedback)

Three panels now render most-recent-on-top:

- MATERIALIZED sorts descending by `DiaryEntry.updatedAt`.
- EVENTS sorts descending by `StoredEvent.sequenceNumber`.
- FIFO rows sort descending by `sequence_in_queue` for display; cumulative event counts are computed on an ascending pass first so each row's cumulative reflects "events shipped from queue start up through this row." Row label now reads `[state] #<seq>: events: <local> (<cumul>)  attempts:<n>` — e.g. `[SENT] #28: events: 2 (38)  attempts:1`. The cumulative number lets a reviewer read off queue-vs-event-log progress at a glance.

---

## FIFO selection fix (2026-04-23 — smoke feedback)

Selecting a row in Secondary's FIFO rendered Primary's row in DETAIL. Root cause: `FifoEntry.entryId == eventIds.first` (library convention, documented at `fifo_entry.dart:190-194`). When both destinations subscribe to the same event with batch size 1, each enqueues a FIFO row whose `entry_id` equals that event's `event_id` — rows collide on entry_id across destinations. `AppState.selectedFifoRowId` held only the entry_id; `DetailPanel`'s loader iterated destinations in registration order and returned the first match.

Fix: `AppState` now carries `(destinationId, entryId)` for FIFO selection. `selectFifoRow(destinationId, entryId)` takes both; `selectedFifoDestinationId` is a new getter. `FifoPanel` passes `widget.destination.id` at tap time and requires both to match for row highlight. `DetailPanel` looks up directly in the specific destination's FIFO store and stamps `"destination"` into the rendered map so the reviewer can eyeball which side they're reading.

Test: `selectFifoRow` takes two args; updated the three call sites and added a `selectedFifoDestinationId` null-check. 69 tests still pass.

---

## Resizable columns + wider DETAIL (2026-04-23 — smoke feedback)

Columns are now user-draggable. Defaults: MATERIALIZED 200px, EVENTS 280px, each FIFO column 260px; DETAIL is wrapped in `Expanded` so it auto-fills the remainder (default on a 1920px window: ~700px+). Between each fixed column a 5px white divider is a `MouseRegion(cursor: resizeColumn) + GestureDetector` — horizontal drag mutates the left column's width with a 80px minimum. Widths live in `_DemoAppState._widths` keyed by column id (`'materialized'`, `'events'`, `'fifo_<destination_id>'`), so adding a destination doesn't lose existing widths.

`flutter analyze` clean, 69 tests still pass (the change is app.dart-only).

---

## FIFO slider ranges (2026-04-23 — smoke feedback)

Tightened for easier small-value dial-in:

- `latency (ms)` — range 0-10000, **non-linear** (slider position `p ∈ [0,1]`, actual `ms = p² × 10000`). Quarter-slider ≈ 625ms, half-slider ≈ 2500ms; small values live in the first half where drag precision is ±100ms-ish. Display label shows actual ms (not slider position).
- `batch size` — 1-12 (was 1-50).
- `accumulate (s)` — 0-20 (was 0-30). Kept min=0 so `Duration.zero` (the DemoDestination default, "no hold") is still reachable.

`_sliderRow` helper grew a `displayOverride` parameter for the latency slider's "show ms, not slider pos" case; everything else passes through unchanged.

---

## Task 14: `flutter run -d linux` smoke test — handoff to user

Blocked in this environment: `flutter build linux` requires `cmake`, `clang`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`. `cmake` is not installed on the current machine; `apt install cmake clang ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev` is the install path.

Pre-Task-14 validation that I *was* able to run:

- `append_only_datastore` library: 472 tests pass; `dart analyze --fatal-infos` clean.
- Example: 69 unit tests pass (styles 19, demo_types 18, demo_destination 14, demo_sync_policy 8, app_state 10); `flutter analyze` clean.
- Parent-package baselines (provenance 31, trial_data_types 59, clinical_diary 1098) unchanged from Task-1 baseline.
- All Dart semantics, lints, and constructor/field shapes verified against the shipped Phase 4.3/4.4/4.5 surface.

What still needs to happen under Task 14 (with cmake installed):

1. `(cd apps/common-dart/append_only_datastore/example && flutter run -d linux)`.
2. Confirm storage path log line prints on stdout: `[demo] storage: /home/<user>/.local/share/append_only_datastore_demo/demo.db`.
3. Run the plan's click-once sanity checks (demo_note Start → Complete, a RED click, row tap in EVENTS populates DETAIL, connection dropdown flip, slider drag, Add destination dialog, Rebuild view, Reset all).
4. Record any runtime exceptions from stderr.

## Task 15: Walk USER_JOURNEYS — handoff to user

Blocked on Task 14 smoke; reviewer walks the nine journeys in `apps/common-dart/append_only_datastore/example/USER_JOURNEYS.md` and signs off per-journey.

## Task 16: Phase squash + push — deferred until 14/15 sign-off

After Task 14 + 15 are clean:

- Interactive rebase to squash `abcf3315..HEAD` (intra-phase commits: Task 1..13 + any 14/15 fixes) into one `[CUR-1154] Phase 4.6: Demo app` commit on top of origin/main.
- `git push --force-with-lease`.
- PR comment linking the new squash SHA.

---

## Consolidated phase-end review — deferred

Per the user's kickoff direction (single consolidated review at phase end, mirroring 4.4 / 4.5). Will run once 14+15 clear.

---

## Per-task controller workflow (user instructions — re-read each task)

> After each phase I want you to:
> - append to `PHASE_4.6_WORKLOG.md` a very brief outline of the work done. Don't say "it was like that before, now its like this." Just say "it works like this". I.e. don't keep repeating history, just report the status.
> - commit the changes
> - Launch a sub-agent to review the commit. Tell it NOT to read the `docs/` folder. I want an unbiased code review.
> - decide which of the review comments to address and which to not address. Log both to WORKLOG.
> - commit again
> - include these instructions at the end of WORKLOG each phase.
> - re-read these instructions.
> Then proceed to the next phase.
