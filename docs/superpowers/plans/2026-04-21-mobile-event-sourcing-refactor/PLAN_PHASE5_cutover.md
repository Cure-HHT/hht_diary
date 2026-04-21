# Master Plan Phase 5: Cutover — `EntryService`, widgets, triggers, delete old services

**Branch**: `mobile-event-sourcing-refactor` (shared)
**Ticket**: CUR-1154
**Phase**: 5 of 5
**Status**: Not Started
**Depends on**: Phase 4 squashed and phase-reviewed

## Scope

The cutover phase. Introduce `EntryService.record()` as the single write API, the `EntryTypeRegistry` and its bundled JSON assets, the first concrete `PrimaryDiaryServerDestination` with REQ-d00113 response translation, the `portalInboundPoll()` implementation for tombstones, widget registry + `EpistaxisFormWidget` + `SurveyRendererWidget`, boot-time bootstrap in `main.dart`, trigger wiring in `clinical_diary/services/triggers.dart`, screen updates to read from the `diary_entries` view and call `EntryService.record()`, and deletion of `NosebleedService` and `QuestionnaireService`.

This is the phase with meaningful behavior change. Its squashed commit is the one reviewers should scrutinize hardest and the one that would be the target of any future revert (reverting just Phase 5's commit leaves the Phase 1-4 machinery intact on `main`).

**Produces:**
- `append_only_datastore/lib/src/entry_service.dart` — `EntryService.record()` with no-op detection.
- `append_only_datastore/lib/src/entry_type_registry.dart` — registry.
- `append_only_datastore/lib/src/bootstrap.dart` — `bootstrapAppendOnlyDatastore(...)` entry point.
- `clinical_diary/lib/destinations/primary_diary_server_destination.dart` — first concrete destination; includes REQ-d00113 409 → `SendOk` translation.
- `clinical_diary/lib/destinations/portal_inbound_poll.dart` — tombstone inbound path (§11.1).
- `clinical_diary/lib/entry_widgets/{registry,epistaxis_form_widget,survey_renderer_widget}.dart`.
- `clinical_diary/lib/services/{entry_service_bootstrap,triggers,diary_entry_reader}.dart`.
- Updated bundled asset `trial_data_types/assets/data/entry_type_definitions.json` (new file or added to `questionnaires.json`).
- Updated screens: `home_screen.dart`, `recording_screen.dart`, `simple_recording_screen.dart`, `calendar_screen.dart`.
- Integration tests covering the full end-to-end flows.

**Deletes:**
- `clinical_diary/lib/services/nosebleed_service.dart`
- `clinical_diary/lib/services/questionnaire_service.dart`
- `nosebleed_service_test.dart` — replaced by widget + `EntryService` tests.
- `EventRepository.getUnsyncedEvents` / `markEventsSynced` / `getUnsyncedCount` — the per-event sync-marker methods (replaced by FIFO machinery). Also `StoredEvent.syncedAt` field.
- The date-bucket `aggregate_id = "diary-YYYY-M-D"` pattern — UUIDs only after this phase.
- `parentRecordId` in the nosebleed payload.

## Execution Rules

Read [README.md](README.md), design doc §6 in full, §7.2 (write path), §9 (questionnaire-to-event flow), §10 (package layout), §11 (cross-cutting concerns) before starting Task 1.

For screens: the rule is "migrate one screen at a time, keep the app green between tasks." Don't delete `NosebleedService` until every call site is migrated off it. The last task before deletion re-runs all screen tests to confirm no caller remains.

**Important**: the event-schema restriction `event_type ∈ {finalized, checkpoint, tombstone}` becomes enforced in this phase (Phases 2-4 allowed the legacy `NosebleedRecorded` value to coexist). Enforcement lives in `EntryService.record()` — not in `StoredEvent` constructor, because `StoredEvent` is still used by the legacy-read path for events appended prior to cutover (if any exist in local storage during development — greenfield production has none).

---

## Plan

### Task 1: Baseline verification

**TASK_FILE**: `PHASE5_TASK_1.md`

- [ ] **Confirm Phase 4 complete**: `git log --oneline` shows Phase 4's squashed commit as HEAD (or immediately behind Phase 4 review fixups).
- [ ] **Stay on shared branch**.
- [ ] **Rebase onto main** in case main moved: `git fetch origin main && git rebase origin/main`. Four squashed phase commits remain.
- [ ] **Baseline tests** — green across all packages.
- [ ] **Manual smoke test**: run `clinical_diary` in an emulator; record a nosebleed; confirm the app still works via the legacy `NosebleedService` path. Record the exact screens touched so the cutover tests can replicate them.
- [ ] **Create TASK_FILE** with baseline output and Phase 4 completion SHA.

---

### Task 2: Spec additions — EntryService, REQ-d00113 translation, destination registration ABI

**TASK_FILE**: `PHASE5_TASK_2.md`

Three REQs added; numbers claimed via `discover_requirements("next available REQ-d")`. Also run `discover_requirements("write API entry service materialized view bootstrap")` and `discover_requirements("deleted questionnaire submission tombstone")` to find existing applicable assertions.

Modify REQ-d00113 (already exists from `spec/dev-questionnaire.md`) to reflect the new UX where the tombstone arrives via inbound poll rather than a submit-time error — this is a behavior change and the assertion text for REQ-d00113-C, D, E needs updating.

**REQ-ENTRY — `EntryService` contract** (assertions A-I):
- A: `EntryService.record({entryType, aggregateId, eventType, answers, checkpointReason?, changeReason?})` SHALL be the sole write API invoked by widgets.
- B: `EntryService` SHALL assign `event_id`, `sequence_number`, `previous_event_hash`, `event_hash`, and the first `ProvenanceEntry` atomically before the write.
- C: `eventType` SHALL be one of `finalized`, `checkpoint`, `tombstone`. Any other value SHALL cause `EntryService.record` to throw `ArgumentError` before any I/O.
- D: `EntryService` SHALL perform the full write path (§7.2) in one `StorageBackend.transaction()`: append event, run materializer, upsert `diary_entries` row, for each matching destination transform and enqueue, increment sequence counter.
- E: A transform failure in step D SHALL abort the whole write — no event is appended if any destination transform throws.
- F: `EntryService.record` SHALL detect no-ops: if the computed content hash of `(event_type, canonical(answers), checkpoint_reason, change_reason)` equals the hash of the most recent event on the same aggregate, the call SHALL return successfully without writing.
- G: After a successful write, `EntryService` SHALL invoke `syncCycle()` fire-and-forget (`unawaited`). The caller MAY NOT rely on sync completion before returning.
- H: `EntryService` SHALL validate that `entryType` is registered in the `EntryTypeRegistry` before accepting the write.
- I: `EntryService` SHALL populate the event's migration-bridge top-level fields (`client_timestamp`, `device_id`, `software_version`) from `metadata.provenance[0]`.

**REQ-BOOTSTRAP — compile-time destination registration ABI** (assertions A-D):
- A: `bootstrapAppendOnlyDatastore({backend, entryTypes, destinations})` SHALL be the single entry point for initializing the datastore from an app's `main()`.
- B: The function SHALL register all supplied `EntryTypeDefinition` entries into the `EntryTypeRegistry` before any `Destination` is registered.
- C: The function SHALL register all supplied `Destination` instances into the `DestinationRegistry` and freeze the registry.
- D: Destinations with `id` collisions SHALL cause bootstrap to throw; the app SHALL NOT proceed to UI rendering.

**REQ-d00113 update — deletion handling via inbound path**:
Update the existing C, D, E assertions in `spec/dev-questionnaire.md` to reflect:
- C: The app SHALL NOT surface a submit-time error for `questionnaire_deleted`. `PrimaryDiaryServerDestination.send` SHALL translate `409 questionnaire_deleted` → `SendOk`.
- D: Upon receipt of a "tombstone entry X" instruction via `portalInboundPoll`, the app SHALL append a `tombstone` event for aggregate X, causing the diary_entries row to be marked `is_deleted = true`.
- E: The entry SHALL appear tombstoned in UI history (not absent — it stays as an audit fact). The home screen SHALL NOT offer the withdrawn questionnaire as a task.

- [ ] **Baseline**.
- [ ] **Create TASK_FILE**.
- [ ] **Write REQ-ENTRY, REQ-BOOTSTRAP** into `spec/dev-event-sourcing-mobile.md`.
- [ ] **Update REQ-d00113-C, D, E** in `spec/dev-questionnaire.md`.
- [ ] **Update `spec/INDEX.md`** with new REQs and content hashes.
- [ ] **Commit**: "Cutover spec: EntryService, bootstrap ABI, updated REQ-d00113 (CUR-1154)".

---

### Task 3: `EntryTypeRegistry`

**TASK_FILE**: `PHASE5_TASK_3.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/entry_type_registry.dart`
- Create: `apps/common-dart/append_only_datastore/test/entry_type_registry_test.dart`

**Applicable assertions:** REQ-d00116-A; REQ-BOOTSTRAP-B; REQ-MAT (consumer via `EntryTypeDefinitionLookup` interface).

- [ ] **Baseline**: green.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests**:
  - `register(def)` adds a definition; `lookup(id)` returns it.
  - Duplicate id registration throws.
  - Post-`freeze()`, further `register` calls throw.
  - `EntryTypeRegistry` implements `EntryTypeDefinitionLookup` (so it can be passed directly to `Materializer` callers).
- [ ] **Run tests**; failures expected.
- [ ] **Implement `EntryTypeRegistry implements EntryTypeDefinitionLookup`**. Per-method `// Implements:` markers.
- [ ] **Run tests**; pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "Add EntryTypeRegistry (CUR-1154)".

---

### Task 4: Bundled `EntryTypeDefinition` assets for all five entry types

**TASK_FILE**: `PHASE5_TASK_4.md`

**Files:**
- Create: `apps/common-dart/trial_data_types/assets/data/entry_type_definitions.json`
- Modify: `apps/common-dart/trial_data_types/pubspec.yaml` (add asset)
- Modify/create: `apps/common-dart/trial_data_types/lib/src/entry_type_definition_loader.dart`
- Create: `apps/common-dart/trial_data_types/test/entry_type_definition_loader_test.dart`

**Applicable assertions:** REQ-d00116-A, B, C, D, F, G.

- [ ] **Baseline**.
- [ ] **Create TASK_FILE**.
- [ ] **Write the JSON asset** with five entries, using the entry-type identifiers from the [README.md](README.md) naming table:

  ```json
  [
    {
      "id": "epistaxis_event",
      "version": "1.0.0",
      "name": "Nosebleed",
      "effective_date_path": "startTime",
      "widget_id": "epistaxis_form_v1",
      "widget_config": {}
    },
    {
      "id": "no_epistaxis_event",
      "version": "1.0.0",
      "name": "No Nosebleeds",
      "effective_date_path": "date",
      "widget_id": "epistaxis_form_v1",
      "widget_config": { "variant": "no_epistaxis" }
    },
    {
      "id": "unknown_day_event",
      "version": "1.0.0",
      "name": "Unknown Day",
      "effective_date_path": "date",
      "widget_id": "epistaxis_form_v1",
      "widget_config": { "variant": "unknown_day" }
    },
    {
      "id": "nose_hht_survey",
      "version": "1.0.0",
      "name": "NOSE HHT Questionnaire",
      "effective_date_path": null,
      "widget_id": "survey_renderer_v1",
      "widget_config": { /* existing QuestionnaireDefinition JSON for NOSE HHT */ }
    },
    {
      "id": "hht_qol_survey",
      "version": "1.0.0",
      "name": "HHT Quality of Life",
      "effective_date_path": null,
      "widget_id": "survey_renderer_v1",
      "widget_config": { /* existing QuestionnaireDefinition JSON for QoL */ }
    }
  ]
  ```

  Note: `epistaxis_form_v1` serves all three `_event` variants; the `widget_config.variant` field selects which sub-mode (full form / no-event marker / unknown marker) the widget renders.

- [ ] **Write failing test** for `loadEntryTypeDefinitionsFromAssets()` that:
  - Loads the JSON via `rootBundle.loadString`.
  - Parses into `List<EntryTypeDefinition>` with 3 items.
  - Each item's `id` is unique and matches expected values above.
- [ ] **Run test**; expect failure.
- [ ] **Write the loader**: async function returning `Future<List<EntryTypeDefinition>>`. Per-function `// Implements: REQ-d00116-A+B+C+F+G — load bundled entry-type definitions for the sponsor's enabled entry types.`
- [ ] **Run test**; pass.
- [ ] **Commit**: "Add bundled EntryTypeDefinition assets and loader (CUR-1154)".

---

### Task 5: `EntryService` with no-op detection and full write path

**TASK_FILE**: `PHASE5_TASK_5.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/entry_service.dart`
- Create: `apps/common-dart/append_only_datastore/test/entry_service_test.dart`

**Applicable assertions:** REQ-ENTRY-A, B, C, D, E, F, G, H, I; REQ-p01001-A, D, F, I; REQ-p00006-A, B, F; REQ-d00004-A, B, E, F, G; REQ-p00004-A, B, L.

- [ ] **Baseline**.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests**. Fixture: in-memory `SembastBackend`, `EntryTypeRegistry` with one test def, `DestinationRegistry.reset()` + register a `_FakeDestination` that matches everything:
  - `record({entryType, aggregateId, eventType: finalized, answers: {...}})` appends an event with correct `entry_type`, `event_type`, hash chain; populates `diary_entries` row (materializer invoked); enqueues a `FifoEntry` into the fake destination's FIFO. All in one transaction.
  - `eventType: "invalid"` throws `ArgumentError` before any write. Sembast state is unchanged. (REQ-ENTRY-C)
  - `entryType` not registered throws `ArgumentError` before any write. (REQ-ENTRY-H)
  - `_FakeDestination.transform` throwing aborts the whole write: no event, no view row, no FIFO entry. (REQ-ENTRY-E)
  - No-op detection: two identical `record()` calls produce exactly one event. The second returns without writing. (REQ-ENTRY-F)
  - No-op detection is granular: changing any of `event_type`, `answers`, `checkpoint_reason`, `change_reason` breaks the no-op.
  - After a successful write, a `syncCycle` call was scheduled (tested via a spy on the injected `SyncCycle`). (REQ-ENTRY-G)
  - Top-level `device_id`, `client_timestamp`, `software_version` on the event equal `metadata.provenance[0].identifier/received_at/software_version`. (REQ-ENTRY-I)
- [ ] **Run tests**; expect failures.
- [ ] **Implement `EntryService`**:
  - Constructor takes `{StorageBackend backend, EntryTypeRegistry registry, DestinationRegistry destinations, SyncCycle syncCycle, DeviceInfo deviceInfo, Clock clock}`.
  - `DeviceInfo` is a tiny typed record with `{deviceId, softwareVersion}`.
  - `record(...)` walks through the §7.2 write path.
  - No-op detection: canonical JSON serialization (keys sorted) for deterministic hashing; SHA-256 of `(event_type | canonical_answers | checkpoint_reason | change_reason)`.
  - Hash-chain computation factored into a shared helper reused with `EventRepository` — do not duplicate.
  - Per-method `// Implements:` citations, especially `record()` which implements most of REQ-ENTRY.
- [ ] **Run tests**; pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "Implement EntryService (CUR-1154)".

---

### Task 6: `bootstrapAppendOnlyDatastore()` entry point

**TASK_FILE**: `PHASE5_TASK_6.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/bootstrap.dart`
- Create: `apps/common-dart/append_only_datastore/test/bootstrap_test.dart`

**Applicable assertions:** REQ-BOOTSTRAP-A, B, C, D.

- [ ] **Baseline**.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests**:
  - Bootstrap with a backend, three entry types, and two destinations: registry has all three entry types, destination registry has both destinations, destination registry is frozen.
  - Duplicate destination id throws; no partial state (either all destinations registered or none). Verify via `DestinationRegistry.all()` being empty after the throw (test resets registry between cases).
  - Calling `bootstrap` twice throws (registry is frozen).
- [ ] **Run tests**; failures expected.
- [ ] **Implement `bootstrapAppendOnlyDatastore`** as a top-level function. Per-function `// Implements: REQ-BOOTSTRAP-A+B+C+D — single entry point, types-then-destinations order, collision rejection.`
- [ ] **Run tests**; pass.
- [ ] **Commit**: "Add bootstrapAppendOnlyDatastore entry point (CUR-1154)".

---

### Task 7: `PrimaryDiaryServerDestination` with REQ-d00113 translation

**TASK_FILE**: `PHASE5_TASK_7.md`

**Files:**
- Create: `apps/daily-diary/clinical_diary/lib/destinations/primary_diary_server_destination.dart`
- Create: `apps/daily-diary/clinical_diary/test/destinations/primary_diary_server_destination_test.dart`

**Applicable assertions:** REQ-DEST-A, B, C, D, E; REQ-d00113-A, B, C (updated); REQ-p01001-B, E, M.

- [ ] **Baseline**.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests** using a `http` package `MockClient`:
  - `transform(event)` produces a `WirePayload` with JSON-encoded bytes, `content_type: application/json`, `transform_version: "v1"`.
  - `send(payload)` with HTTP 200 response → `SendOk`.
  - `send(payload)` with HTTP 500 → `SendTransient` with error message.
  - `send(payload)` with HTTP 404 → `SendPermanent`.
  - `send(payload)` with HTTP 409 and body containing `"error": "questionnaire_deleted"` → `SendOk` (the key REQ-d00113 translation).
  - `send(payload)` with HTTP 409 and any other body → `SendPermanent` (generic conflict, fall through to default 4xx rule).
  - Network timeout → `SendTransient` with timeout error.
  - `filter` allows all `entry_type` and `event_type` (the primary destination receives everything for audit).
- [ ] **Run tests**; failures expected.
- [ ] **Implement `PrimaryDiaryServerDestination`**:
  - Constructor takes `{http.Client client, Uri baseUrl, EnrollmentService enrollmentService}` for authentication headers.
  - Per-method `// Implements:` markers.
  - The 409 translation is a separate private method `_translate4xx(response)`; document the REQ-d00113-C-specific branch inline.
- [ ] **Run tests**; pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "Implement PrimaryDiaryServerDestination (CUR-1154)".

---

### Task 8: `portalInboundPoll()` — tombstone inbound path

**TASK_FILE**: `PHASE5_TASK_8.md`

**Files:**
- Create: `apps/daily-diary/clinical_diary/lib/destinations/portal_inbound_poll.dart`
- Create: `apps/daily-diary/clinical_diary/test/destinations/portal_inbound_poll_test.dart`

**Applicable assertions:** REQ-d00113-D, E; REQ-p01001-B (connectivity triggers).

- [ ] **Baseline**.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests**:
  - Poll receives 200 with body `{"messages": []}` → no side effects.
  - Poll receives a `{"type": "tombstone", "entry_id": "<uuid>"}` message → `EntryService.record` is called with `eventType: tombstone` and matching `aggregateId`.
  - Poll with multiple messages processes all of them in order.
  - Poll with 500 error → logs and returns (no exception propagated to `syncCycle`).
  - Poll idempotency: receiving the same tombstone twice writes only one event due to `EntryService` no-op detection.
- [ ] **Run tests**; failures expected.
- [ ] **Implement `portalInboundPoll(EntryService entryService, http.Client client, Uri baseUrl)`**. Per-function `// Implements: REQ-d00113-D+E — portal pushes tombstones via polled inbound channel; mobile materializes as tombstone events.`
- [ ] **Update `SyncCycle.portalInboundPoll()`** (stubbed in Phase 4) to call this function. Move the field from stub to a real injection: `SyncCycle` constructor now takes a `PortalInboundPoller` function parameter.
- [ ] **Run tests**; pass.
- [ ] **Commit**: "Implement portalInboundPoll and wire into SyncCycle (CUR-1154)".

---

### Task 9: Widget registry + `EpistaxisFormWidget`

**TASK_FILE**: `PHASE5_TASK_9.md`

**Files:**
- Create: `apps/daily-diary/clinical_diary/lib/entry_widgets/registry.dart`
- Create: `apps/daily-diary/clinical_diary/lib/entry_widgets/epistaxis_form_widget.dart`
- Create: `apps/daily-diary/clinical_diary/test/entry_widgets/epistaxis_form_widget_test.dart`

Note: Dart class is `EpistaxisFormWidget` (matches the data-model entry_type). User-facing UI text remains "Nosebleed".

**Applicable assertions:** REQ-p00006-A, B, F; REQ-d00004-E, F, G; REQ-p01067-A, B, C (nosebleed UI).

- [ ] **Baseline**.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing widget tests** using `pumpWidget`:
  - Widget displays start-time picker, end-time picker, intensity slider, notes field (mirror the existing NosebleedService recording UX).
  - Tapping "Save" as a checkpoint (incomplete form) calls `EntryService.record(eventType: checkpoint)` with the partial answers and a fresh `aggregateId`.
  - Tapping "Save" as finalized (complete form) calls `EntryService.record(eventType: finalized)` with full answers.
  - Editing an existing entry calls `EntryService.record(eventType: finalized, aggregateId: existingId, changeReason: "user-edit")`.
  - Delete action calls `EntryService.record(eventType: tombstone, aggregateId: existingId, changeReason: "<user reason>")`.
- [ ] **Run tests**; failures.
- [ ] **Implement `registry.dart`** as a `Map<String, WidgetBuilder>` keyed by `widget_id`, with test-only `register` / `reset` methods.
- [ ] **Implement `EpistaxisFormWidget`** absorbing the recording UX logic currently in `recording_screen.dart` + `simple_recording_screen.dart` + `NosebleedService.addRecord`/`updateRecord`/`deleteRecord`. Use `EntryService.record` for all writes; no direct `EventRepository` calls. Use UUIDs for new `aggregateId`s (no more `diary-YYYY-M-D` pattern for events written via this widget).
- [ ] The widget SHALL honor `widget_config.variant` with three values: absent/null = full nosebleed form; `"no_epistaxis"` = marker-only display; `"unknown_day"` = marker-only display. Two widget tests per variant cover the rendering differences.
- [ ] **Register the widget** under `widget_id: "epistaxis_form_v1"` in `registry.dart`.
- [ ] **Run tests**; pass.
- [ ] **Commit**: "Add EpistaxisFormWidget and widget registry (CUR-1154)".

---

### Task 10: `SurveyRendererWidget`

**TASK_FILE**: `PHASE5_TASK_10.md`

**Files:**
- Create: `apps/daily-diary/clinical_diary/lib/entry_widgets/survey_renderer_widget.dart`
- Create: `apps/daily-diary/clinical_diary/test/entry_widgets/survey_renderer_widget_test.dart`

**Applicable assertions:** REQ-p01067-A, B, C, D, E, G, H, I (nose-hht questionnaire); REQ-p01068-A, B, C, D, E, F, G, H (QoL); REQ-p00006-A, B.

- [ ] **Baseline**.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests**:
  - Renders a questionnaire from a `QuestionnaireDefinition` supplied as `widget_config`.
  - On each question answered, a `checkpoint` event is recorded (so unfinished work survives app suspension).
  - Final submit tap records a `finalized` event with all answers.
  - After finalization, further changes are blocked (REQ-p01067-H, REQ-p01068-G).
  - Tombstone state (after portal deletion arrives) shows a "withdrawn" banner; questionnaire fields are read-only.
- [ ] **Run tests**; failures expected.
- [ ] **Implement `SurveyRendererWidget`**. Ingest the existing `QuestionnaireDefinition` shape from `widget_config`. Call `EntryService.record` for each checkpoint and the final finalization.
- [ ] **Register** under `widget_id: "survey_renderer_v1"`.
- [ ] **Run tests**; pass.
- [ ] **Commit**: "Add SurveyRendererWidget (CUR-1154)".

---

### Task 11: `DiaryEntryReader` read-only facade

**TASK_FILE**: `PHASE5_TASK_11.md`

**Files:**
- Create: `apps/daily-diary/clinical_diary/lib/services/diary_entry_reader.dart`
- Create: `apps/daily-diary/clinical_diary/test/services/diary_entry_reader_test.dart`

**Applicable assertions:** REQ-p00013-A, B, E (view reflects full history for screens that need it); REQ-p00004-E+L (view is derived from event log, updated as events arrive).

- [ ] **Baseline**.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests**:
  - `entriesForDate(date, entryType: ...)` returns only rows where `effective_date == date` and not `is_deleted`.
  - `entriesForDateRange(from, to)` applies the range.
  - `incompleteEntries(entryType: ...)` returns rows with `is_complete == false` and not `is_deleted`.
  - `hasEntriesForYesterday()` — used by the home-screen prompt.
  - `dayStatus(date)` — returns a `DayStatus` enum (`recorded | no_nosebleeds | unknown | empty`) derived from the rows present for that date. This preserves existing `NosebleedService.getDayStatus` behavior.
- [ ] **Run tests**; failures.
- [ ] **Implement `DiaryEntryReader`** as a thin wrapper over `StorageBackend.findEntries`. Per-method `// Implements:` markers.
- [ ] **Run tests**; pass.
- [ ] **Commit**: "Add DiaryEntryReader read-only facade (CUR-1154)".

---

### Task 12: Wire triggers — `clinical_diary/lib/services/triggers.dart`

**TASK_FILE**: `PHASE5_TASK_12.md`

**Files:**
- Create: `apps/daily-diary/clinical_diary/lib/services/triggers.dart`
- Create: `apps/daily-diary/clinical_diary/test/services/triggers_test.dart`
- Modify: `apps/daily-diary/clinical_diary/lib/services/notification_service.dart` (re-route FCM callbacks to trigger sync_cycle)

**Applicable assertions:** REQ-SYNC-D; REQ-p01001-B, J; REQ-p00049-A (FCM triggers).

- [ ] **Baseline**.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests**:
  - `AppLifecycleState.resumed` calls `syncCycle()`.
  - Foreground `Timer.periodic(SyncPolicy.periodicInterval)` calls `syncCycle()`; pausing the app stops the timer.
  - `connectivity_plus` offline→online event triggers `syncCycle()`; online→offline does not.
  - `FirebaseMessaging.onMessage` and `onMessageOpenedApp` each trigger `syncCycle()`.
  - No background isolate is registered (assert no call to `WorkManager.registerTask` or equivalent — the current codebase has no such calls; confirm in test that after running `triggers.install()` none are added).
- [ ] **Run tests**; failures.
- [ ] **Implement `triggers.dart`** exposing `Future<void> installTriggers(SyncCycle syncCycle)` that subscribes to each source.
- [ ] **Update `notification_service.dart`**: current FCM callbacks are hooked into the old nosebleed-sync path. Rewire them to call `syncCycle()` instead.
- [ ] **Run tests**; pass.
- [ ] **Commit**: "Wire sync_cycle triggers (CUR-1154)".

---

### Task 13: Boot-time wiring in `main.dart` and `entry_service_bootstrap.dart`

**TASK_FILE**: `PHASE5_TASK_13.md`

**Files:**
- Modify: `apps/daily-diary/clinical_diary/lib/main.dart`
- Create: `apps/daily-diary/clinical_diary/lib/services/entry_service_bootstrap.dart`

**Applicable assertions:** REQ-BOOTSTRAP-A, B, C.

- [ ] **Baseline**.
- [ ] **Create TASK_FILE**.
- [ ] **Implement `entry_service_bootstrap.dart`**:
  - Function `bootstrapClinicalDiary(EnrollmentService enrollmentService)` that:
    - Opens a `SembastBackend` at the app-documents path.
    - Loads entry types via `loadEntryTypeDefinitionsFromAssets()`.
    - Builds the `PrimaryDiaryServerDestination` (and any sponsor-specific destinations — for now, only the primary).
    - Calls `bootstrapAppendOnlyDatastore(backend, entryTypes, destinations)`.
    - Creates and returns the `EntryService`, `DiaryEntryReader`, `SyncCycle` trio wired together.
    - Registers widget builders in `entry_widgets/registry.dart`.
    - Calls `installTriggers(syncCycle)`.
  - Per-function `// Implements: REQ-BOOTSTRAP-A — sole entry point; delegates to package bootstrap.`
- [ ] **Modify `main.dart`** to call `bootstrapClinicalDiary` in the startup sequence. Replace the existing `NosebleedService` initialization.
- [ ] **Manual smoke test**: run the app; confirm it boots, renders home screen, and `_FakeDestination` → replace with `PrimaryDiaryServerDestination` — a nosebleed records an event and enqueues it in the primary FIFO. Use the dev environment's backend.
- [ ] **Commit**: "Bootstrap clinical_diary app with EntryService (CUR-1154)".

---

### Task 14: Migrate `recording_screen.dart` and `simple_recording_screen.dart`

**TASK_FILE**: `PHASE5_TASK_14.md`

**Files:**
- Modify: `apps/daily-diary/clinical_diary/lib/screens/recording_screen.dart`
- Modify: `apps/daily-diary/clinical_diary/lib/screens/simple_recording_screen.dart`
- Modify: corresponding tests in `test/screens/`

**Applicable assertions:** REQ-p00006-A, B, C, D, E; REQ-d00004-E, F, G.

- [ ] **Baseline**.
- [ ] **Create TASK_FILE**.
- [ ] **Rewrite the screens** to embed `EpistaxisFormWidget` from the widget registry. Remove direct `NosebleedService` references (lines 448, 462 in `recording_screen.dart`; 206, 215 in `simple_recording_screen.dart`).
- [ ] **Update screen tests** to verify `EntryService.record` is called with the right parameters.
- [ ] **Run `flutter test`** in `clinical_diary`; expect green.
- [ ] **Manual smoke test**: open each screen; add, edit, delete an entry; confirm event log grows; confirm view reflects changes.
- [ ] **Commit**: "Migrate recording screens to EntryService (CUR-1154)".

---

### Task 15: Migrate `calendar_screen.dart` and `home_screen.dart`

**TASK_FILE**: `PHASE5_TASK_15.md`

**Files:**
- Modify: `apps/daily-diary/clinical_diary/lib/screens/calendar_screen.dart` (lines 198, 204, 250)
- Modify: `apps/daily-diary/clinical_diary/lib/screens/home_screen.dart` (lines 246, 287, 611, 642, 657, 688, 703)
- Modify: corresponding tests

**Applicable assertions:** REQ-p00006-D, G, H; REQ-p01001-L (sync status indicator).

- [ ] **Baseline**.
- [ ] **Create TASK_FILE**.
- [ ] **Update `calendar_screen.dart`**:
  - Date selection reads from `DiaryEntryReader.entriesForDate(date)`.
  - `markNoNosebleeds(date)` → `EntryService.record(entryType: "no_epistaxis_event", eventType: finalized, answers: {date: ...})`.
  - `markUnknown(date)` → `EntryService.record(entryType: "unknown_day_event", eventType: finalized, answers: {date: ...})`.
  - `deleteRecord(id, reason)` → `EntryService.record(entryType: <original>, aggregateId: id, eventType: tombstone, changeReason: reason)`.
- [ ] **Update `home_screen.dart`**:
  - Similar replacements for lines 246, 287, 642, 657, 688, 703.
  - Line 611 (`questionnaireService.submitResponses`) → submit now flows through the `SurveyRendererWidget` in the task screen — this line should be removed as the screen no longer does submit directly.
  - Add a sync-status indicator that queries `backend.anyFifoExhausted()`; when true, show a "data not syncing — please update" banner (per REQ-p01001-L and design §12.1).
- [ ] **Update screen tests**.
- [ ] **Run `flutter test`** in `clinical_diary`; green.
- [ ] **Manual smoke test**: cover each button on both screens.
- [ ] **Commit**: "Migrate calendar and home screens to EntryService (CUR-1154)".

---

### Task 16: Delete `NosebleedService` and `QuestionnaireService`

**TASK_FILE**: `PHASE5_TASK_16.md`

**Files:**
- Delete: `apps/daily-diary/clinical_diary/lib/services/nosebleed_service.dart`
- Delete: `apps/daily-diary/clinical_diary/lib/services/questionnaire_service.dart`
- Delete: `apps/daily-diary/clinical_diary/test/services/nosebleed_service_test.dart`
- Remove: any `import` of the deleted files across the codebase.
- Modify: `apps/common-dart/append_only_datastore/lib/src/infrastructure/repositories/event_repository.dart` — remove `getUnsyncedEvents`, `markEventsSynced`, `getUnsyncedCount`, and the `syncedAt` field on `StoredEvent`.

- [ ] **Baseline**: all tests pass; triggers installed; every call site migrated per Tasks 9-15. If ANY call site still references the old services, stop and go back to the relevant task.
- [ ] **Create TASK_FILE**.
- [ ] **Grep verification**: `grep -rn 'NosebleedService\|QuestionnaireService' apps/` — expect zero hits. If non-zero, enumerate and migrate before proceeding.
- [ ] **Delete the two service files**.
- [ ] **Delete `nosebleed_service_test.dart`** — its behaviors are now covered by `entry_service_test.dart`, `epistaxis_form_widget_test.dart`, and screen tests.
- [ ] **Remove `getUnsyncedEvents`, `markEventsSynced`, `getUnsyncedCount`** from `EventRepository`. Grep `apps/` for each name — expect zero remaining callers.
- [ ] **Remove `syncedAt` field** from `StoredEvent`. Update `toJson`/`fromJson`.
- [ ] **Run `flutter test`** in both `append_only_datastore` and `clinical_diary`; expect green.
- [ ] **Run `flutter analyze`**; expect clean.
- [ ] **Commit**: "Delete NosebleedService, QuestionnaireService, and per-event sync markers (CUR-1154)".

---

### Task 17: End-to-end integration tests

**TASK_FILE**: `PHASE5_TASK_17.md`

**Files:**
- Create: `apps/daily-diary/clinical_diary/integration_test/event_sourcing_cutover_test.dart`

**Applicable assertions:** REQ-p00004-E, L; REQ-p00006-A, B, F, H; REQ-p01001-A, B, D, G, N; REQ-d00113-C, D, E.

- [ ] **Baseline**.
- [ ] **Create TASK_FILE**.
- [ ] **Write integration tests** using `integration_test` package + a mock HTTP server for the primary diary server:
  - **E2E nosebleed flow**: open app, tap "Add Nosebleed" from home, fill form, submit. Verify: one event in event_log, one FifoEntry in primary FIFO, after `syncCycle()` the entry is marked `sent`.
  - **E2E edit flow**: create nosebleed, then edit it. Verify: two events on the same aggregate_id, view row reflects latest answers, FIFO holds two entries both marked `sent` after sync.
  - **E2E delete flow**: create, then delete. Verify: tombstone event, view row has `is_deleted = true`, UI doesn't show the entry in active list, audit view shows it.
  - **E2E questionnaire flow**: open QoL questionnaire, answer each question (checkpoints created), submit (finalized). Verify: one aggregate with N+1 events, last is finalized, FIFO drains.
  - **E2E REQ-d00113 tombstone inbound**: prime the mock server's inbound endpoint with `{type: tombstone, entry_id: X}`. Trigger `syncCycle`. Verify: tombstone event for X is appended, view row marked deleted, UI reflects deletion.
  - **E2E 409 translation**: submit a questionnaire whose mock server responds with `409 questionnaire_deleted`. Verify: FIFO entry is marked `sent`, event remains in event_log, UI does not surface a submit-time error.
  - **E2E FIFO wedge**: force a `SendPermanent` (non-409) from the mock server. Verify: FIFO is wedged (head = exhausted), `anyFifoExhausted()` returns true, the banner is shown on home screen.
  - **E2E offline→online**: disable connectivity in the test harness, create two entries (events enqueued but not sent), re-enable connectivity, verify both entries sync.
- [ ] **Run integration tests**: `(cd apps/daily-diary/clinical_diary && flutter test integration_test/event_sourcing_cutover_test.dart)`; expect green.
- [ ] **Commit**: "Add cutover integration tests (CUR-1154)".

---

### Task 18: Version bumps + CHANGELOGs

**TASK_FILE**: `PHASE5_TASK_18.md`

- [ ] **Bump `append_only_datastore`** minor version (new public surface: `EntryService`, `EntryTypeRegistry`, `bootstrapAppendOnlyDatastore`).
- [ ] **Bump `trial_data_types`** patch version (new bundled asset, new loader).
- [ ] **Bump `clinical_diary`** app version (user-visible: deleted services, new widget paths).
- [ ] **Update each CHANGELOG.md** accordingly.
- [ ] **Full verification**:
  - `flutter test` in all touched packages
  - `flutter analyze` in all touched packages
  - `flutter test integration_test/` in `clinical_diary`
- [ ] **Commit**: "Bump versions and changelogs for Phase 5 (CUR-1154)".

---

### Task 19: Phase-boundary squash and request final phase review

**TASK_FILE**: `PHASE5_TASK_19.md`

- [ ] **Rebase onto main** in case main moved: `git fetch origin main && git rebase origin/main`. Resolve conflicts carefully — this phase touches screen files that see frequent churn. Four prior phase commits remain.
- [ ] **Full verification**:
  - `flutter test` across all touched packages
  - `flutter analyze` across all touched packages
  - `flutter test integration_test/` in `clinical_diary`
- [ ] **Interactive rebase to squash Phase 5 commits**: `git rebase -i origin/main` — keep Phases 1-4 `pick`, squash all Phase 5 commits into one with message:

  ```
  [CUR-1154] Phase 5: Cutover — EntryService, widgets, delete old services

  The behavior-changing phase. Introduces:
  - EntryService.record() as the single write API (no-op detection, atomic
    multi-store write per design §7.2)
  - EntryTypeRegistry + bundled JSON assets for 5 entry types
  - PrimaryDiaryServerDestination with 409 questionnaire_deleted → SendOk
    translation (updates REQ-d00113-C,D,E)
  - portalInboundPoll() materializing portal-sent tombstones as events
  - EpistaxisFormWidget + SurveyRendererWidget + widget registry
  - DiaryEntryReader read-only facade; screens now read from diary_entries
  - Triggers: app-lifecycle, periodic timer, connectivity, FCM → sync_cycle
  - FIFO-wedge banner on home screen

  Deletes:
  - NosebleedService, QuestionnaireService
  - EventRepository per-event sync markers and StoredEvent.syncedAt
  - diary-YYYY-M-D aggregate_id pattern (UUIDs only)

  spec/dev-event-sourcing-mobile.md: REQ-ENTRY, REQ-BOOTSTRAP
  spec/dev-questionnaire.md: REQ-d00113-C,D,E updated
  ```

- [ ] **Force-push with lease**: `git push --force-with-lease`.
- [ ] **Comment on PR**: "Phase 5 ready for review — commit `<sha>`. This is the behavior-changing phase. Review focus: EntryService atomicity, REQ-d00113 translation path (both inbound poll and 409 outbound translation), widget migration correctness, end-to-end integration tests. FDA 21 CFR Part 11 reviewer attention requested."
- [ ] **Wait for phase review**. Address feedback via fixups + in-place rebase.
- [ ] **Record Phase 5 completion SHA** in TASK_FILE.

---

### Task 20: Mark PR ready-for-review and handle overall review

**TASK_FILE**: `PHASE5_TASK_20.md`

- [ ] **Convert draft PR to ready-for-review**: `gh pr ready <PR-number>`.
- [ ] **Update PR body** to its final form:
  - Summary of all 5 phases with commit SHAs and one-line summaries.
  - Behavior changes (questionnaire submit no longer errors on deleted questionnaires; FIFO wedge banner; unified write path).
  - Explicit callout: this PR deletes `NosebleedService` and `QuestionnaireService`. Revert strategy: the 5 phase commits on `main` provide per-phase rollback granularity — reverting Phase 5's commit alone leaves Phases 1-4's machinery intact.
  - Test plan: `flutter test` across packages, `flutter test integration_test/` in `clinical_diary`.
- [ ] **Request reviewers**: at least one with regulatory context (FDA 21 CFR Part 11 implications of the audit-trail changes), plus whoever is the normal reviewer for mobile changes.
- [ ] **Address overall review feedback**. Feedback that belongs to a specific phase gets committed as a fixup and folded into that phase's squashed commit via interactive rebase (not a new commit on top). Feedback that spans phases — decide case-by-case whether to re-split across phases or add a small "Phase 5 follow-up" commit.

---

### Task 21: Rebase-merge to main

**TASK_FILE**: `PHASE5_TASK_21.md`

- [ ] **Verify the branch has exactly 5 commits ahead of main**: `git log --oneline origin/main..HEAD` returns exactly 5 lines, one per phase, each with subject starting `[CUR-1154] Phase N: `. If not, go back and fix the squash state before merging.
- [ ] **Verify CI is green** on the PR.
- [ ] **Verify rebase-merge is enabled** on the repo: `gh repo view --json rebaseMergeAllowed`. Expected: `true`.
- [ ] **Rebase-merge**: `gh pr merge <PR-number> --rebase` (or via the GitHub UI, selecting "Rebase and merge"). This places the 5 phase commits linearly on `main`.
- [ ] **Verify on `main`**: `git fetch origin main && git log --oneline -n 6 origin/main` — the 5 newest commits are the 5 phase commits in order.
- [ ] **Clean up the branch and worktree** (worktree-aware procedure — do not just `git branch -D` while the worktree is active):
  - From outside the worktree (e.g., from the main repo at `~/cure-hht/hht_diary/`): `git worktree remove ~/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/`
  - Then delete the branch: `git branch -D mobile-event-sourcing-refactor`
  - Then delete remote: `git push origin --delete mobile-event-sourcing-refactor`
  - Check with user before running these — they may want to preserve the worktree for follow-up work (deferred items in `memory/project_event_sourcing_refactor_out_of_scope.md` such as portal ingestion).
- [ ] **Record the 5 commit SHAs on main** in TASK_FILE.

---

## Recovery

1. Read this file.
2. Read [README.md](README.md) and design doc §6-§11.
3. Find first unchecked box.
4. Read matching `PHASE5_TASK_N.md`.

Archive procedure is whole-ticket — see [README.md](README.md) Archive section (runs after Task 21 completes).
