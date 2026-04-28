# CUR-1169 — Mobile Daily-Diary Cutover to `event_sourcing_datastore`

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The clinical_diary mobile app writes every patient event — nosebleeds *and questionnaires* — through `EntryService.record()` from the `event_sourcing_datastore` library and reads from the materialized `diary_entries` view. `NosebleedService` and `QuestionnaireService` are deleted.

**The questionnaire change is the bigger correction.** Today nosebleeds persist locally (in a bespoke append-only store) but questionnaires don't — `QuestionnaireService.submitResponses` POSTs straight to the server and returns success/error to the UI, with no local audit trail, no checkpoint persistence, no offline queueing. Post-cutover both kinds of patient input share one path: write to the local event log first, materialize to the `diary_entries` view, then drain to the server through the FIFO. Network failure no longer loses answers; app suspension no longer loses partial work; questionnaire submissions inherit the same hash-chained provenance as every other event.

**Five entry types share one write path:**

| `id` | UX surface | Purpose |
| --- | --- | --- |
| `epistaxis_event` | `recording_screen.dart` (full form) | Recorded nosebleed |
| `no_epistaxis_event` | `simple_recording_screen.dart` (marker) | "No nosebleeds today" marker |
| `unknown_day_event` | `simple_recording_screen.dart` (marker) | "Don't remember" marker |
| `nose_hht_survey` | `eq.QuestionnaireFlowScreen` | NOSE-HHT questionnaire |
| `hht_qol_survey` | `eq.QuestionnaireFlowScreen` | HHT Quality of Life questionnaire |

**Architecture:** A per-app bootstrap (`bootstrapClinicalDiary`) constructs a `SembastBackend`, registers the 5 entry types and the `PrimaryDiaryServerDestination`, and returns a `ClinicalDiaryRuntime` with 6 fields: `backend`, `entryService`, `reader`, `syncCycle`, `triggerHandles`, `destinations`. Screens push the appropriate UX directly: recording screens for nosebleed variants, `eq.QuestionnaireFlowScreen` for surveys. Inbound tombstone polling runs after each `SyncCycle` tick.

**Tech stack:** Dart, Flutter, Sembast (mobile storage via `event_sourcing_datastore`'s `SembastBackend`), `event_sourcing_datastore` library (CUR-1154, on `main`), `trial_data_types` package (questionnaire JSON assets), `eq` package (questionnaire flow screen).

**Ticket:** [CUR-1169](https://linear.app/cure-hht-diary/issue/CUR-1169) — branch `diary1`, worktree `/home/metagamer/cure-hht/hht_diary-worktrees/diary1`.

**Design source:** `docs/superpowers/2026-04-21-mobile-event-sourcing-refactor-design.md` §6, §7.2, §9, §10, §11. Library contract: `apps/common-dart/event_sourcing_datastore/README.md` and `apps/common-dart/event_sourcing_datastore/example/README.md`.

**Greenfield posture:** Mobile and portal are both greenfield (never deployed). There is no in-flight user data, no parallel-running old code, no migration. The cutover is a *reshape*: build the new code, rip the old code, fix the compiler errors. No "both shapes alive" intermediate state.

---

## Constraints carried into every task

- **Final-state spec voice.** REQ wording is greenfield prose — no "previously / used to / replaces" framing.
- **Stay in scope.** Diary mobile app only. No portal, no server, no library edits. Library bugs → file a follow-up ticket and stub around them.
- **CUR-XXX in PR title only.** Commit messages don't need it. PR title is `[CUR-1169] …`.
- **Per-class implementation citations.** Every new file gets a `// Implements: REQ-… — short prose` header. Every new test gets `// Verifies: REQ-…-X` near each test case.
- **No new background isolates.** Sync triggers are foreground-only per design §11 decision 11.

---

## Library API contract — pinned

These are the library APIs this plan depends on. Every signature has been verified against the source.

| Surface | Where | Shape |
| --- | --- | --- |
| `bootstrapAppendOnlyDatastore({backend, source, entryTypes, destinations, materializers, initialViewTargetVersions, syncCycleTrigger?})` | `lib/src/bootstrap.dart:84` | Returns `Future<AppendOnlyDatastore>` exposing `eventStore`, `entryTypes`, `destinations`, `securityContexts` |
| `EntryService({backend, entryTypes: EntryTypeRegistry, syncCycleTrigger, deviceInfo, clock?, uuid?})` | `lib/src/entry_service.dart:70` | Construct after bootstrap; pass `datastore.entryTypes` |
| `EntryService.record({entryType, aggregateId, eventType, answers, checkpointReason?, changeReason?})` | `lib/src/entry_service.dart:143` | Returns `Future<StoredEvent?>`. Sets `aggregateType: 'DiaryEntry'` internally |
| `EntryTypeDefinition({id, registeredVersion, name, widgetId, widgetConfig, effectiveDatePath?, destinationTags?, materialize?})` | `lib/src/entry_type_definition.dart:21` | Const-constructible |
| `Destination` (abstract) | `lib/src/destinations/destination.dart:36` | Override `id`, `filter`, `wireFormat`, `maxAccumulateTime`, `canAddToBatch`, `transform`, `send`. Defaults: `allowHardDelete = false`, `serializesNatively = false` |
| `WirePayload({bytes: Uint8List, contentType, transformVersion: String?})` | `lib/src/destinations/wire_payload.dart:22` | No `.json()` factory; canonical constructor only |
| `SendOk()` const, `SendTransient({error, httpStatus?})` const, `SendPermanent({error})` const | `lib/src/destinations/send_result.dart:18` | Sealed hierarchy |
| `SyncCycle({backend, registry, clock?, policy?, policyResolver?})` | `lib/src/sync/sync_cycle.dart:28` | No `afterDrain` callback. Inbound poll wires as a follow-up in `installTriggers`' `onTrigger` |
| `SyncPolicy.defaults` (with `periodicInterval: Duration(minutes: 15)`) | `lib/src/sync/sync_policy.dart:63` | Default tuning |
| `Source({hopId, identifier, softwareVersion})` | `lib/src/storage/source.dart` | Exported by `event_sourcing_datastore`, NOT `provenance`. Use `hopId: 'mobile-device'` |
| `DeviceInfo({deviceId, softwareVersion, userId})` | `lib/src/entry_service.dart` | Exported by `event_sourcing_datastore` |
| `SembastBackend({database})` | `lib/src/storage/sembast_backend.dart:60` | Caller opens the Sembast `Database` and passes it in |
| `backend.findEntries({entryType?, ...})` | `lib/src/storage/storage_backend.dart` | Typed view query — returns `List<DiaryEntry>` |
| `DiaryEntriesMaterializer(promoter: identityPromoter)` | exported | Use both verbatim from the library |
| `SubscriptionFilter({entryTypes?, eventTypes?, predicate?, includeSystemEvents = false})` | `lib/src/destinations/subscription_filter.dart:39` | `const SubscriptionFilter()` matches every user entry-type / event-type, excludes system events |

Questionnaire definitions are not Dart constants. They live in `packages/trial_data_types/assets/data/questionnaires.json` and are loaded via `rootBundle.loadString(...)` at boot. The clinical_diary entry-type list is therefore an **async** loader, not a `const` list.

`provenance` package is NOT a dep we add. `Source` and `DeviceInfo` come from `event_sourcing_datastore`.

---

## File map

**New (clinical_diary):**
- `apps/daily-diary/clinical_diary/lib/entry_types/clinical_diary_entry_types.dart`
- `apps/daily-diary/clinical_diary/lib/destinations/primary_diary_server_destination.dart`
- `apps/daily-diary/clinical_diary/lib/destinations/portal_inbound_poll.dart`
- `apps/daily-diary/clinical_diary/lib/services/clinical_diary_bootstrap.dart`
- `apps/daily-diary/clinical_diary/lib/services/diary_entry_reader.dart`
- `apps/daily-diary/clinical_diary/lib/services/diary_export_service.dart`
- `apps/daily-diary/clinical_diary/lib/services/triggers.dart`
- `apps/daily-diary/clinical_diary/lib/widgets/nosebleed_intensity.dart` (UI-only enum)
- Mirror tests under `apps/daily-diary/clinical_diary/test/`.

**Modified:**
- `apps/daily-diary/clinical_diary/pubspec.yaml` (add `event_sourcing_datastore` + `path_provider`; remove `append_only_datastore`)
- `apps/daily-diary/clinical_diary/lib/main.dart` (bootstrap runtime; activate destination)
- `apps/daily-diary/clinical_diary/lib/screens/{home,recording,simple_recording,calendar,date_records}_screen.dart`
- `apps/daily-diary/clinical_diary/lib/services/notification_service.dart` (keep FCM; remove legacy sync-trigger subscriptions)
- `apps/daily-diary/clinical_diary/lib/widgets/{event_list_item,calendar_overlay,overlap_warning}.dart`
- `spec/dev-questionnaire.md` (REQ-d00113 assertions C/D/E/F rewrite)
- `spec/dev-event-sourcing-mobile.md` (REQ-d00155/156/157 appended)
- `spec/INDEX.md` (content-hash refresh + new REQ entries)

**Deleted (pre-cutover):**
- `apps/daily-diary/clinical_diary/lib/services/nosebleed_service.dart`
- `apps/daily-diary/clinical_diary/lib/services/questionnaire_service.dart`
- `apps/daily-diary/clinical_diary/test/services/nosebleed_service_test.dart`

---

## Plan

### Phase 1 — Baseline

#### Task 1: Verify location and run baseline tests [x]

**Files:** none (verification only).

- [x] Confirm location, branch, and that CUR-1154 is upstream.
- [x] Run baseline tests (`flutter test` in `clinical_diary`, `dart test` in `event_sourcing_datastore`). Both green before any change.
- [x] Manual smoke baseline: record a nosebleed, mark "no nosebleeds", open the QoL questionnaire and submit it.

---

### Phase 2 — REQ updates and pubspec

#### Task 2: Update REQ-d00113 and claim REQ-d00155/156/157 [x]

**Files:** `spec/dev-questionnaire.md`, `spec/dev-event-sourcing-mobile.md`, `spec/INDEX.md`.

- [x] Discover existing applicable REQs via the `elspais` MCP.
- [x] Claim REQ-d00155 (PrimaryDiaryServerDestination contract), REQ-d00156 (portalInboundPoll tombstone path), REQ-d00157 (clinical_diary sync triggers).
- [x] Rewrite REQ-d00113 assertions C/D/E/F:

  C. `PrimaryDiaryServerDestination.send` SHALL translate an HTTP 409 response with body containing `"error": "questionnaire_deleted"` to `SendOk`. The submitted event remains in the local event log as the audit fact.

  D. The portal inbound-poll endpoint SHALL deliver `{"type": "tombstone", "entry_id": "<uuid>", "entry_type": "<type>"}` messages for entries withdrawn server-side. On receipt, the app SHALL invoke `EntryService.record(entryType: <type>, aggregateId: <entry_id>, eventType: 'tombstone', answers: {}, changeReason: 'portal-withdrawn')`.

  E. After a tombstone event materializes, the entry SHALL appear in the materialized `diary_entries` view with `is_deleted = true`. The home screen SHALL NOT offer the entry as an actionable task. The audit history view SHALL still show the entry.

  F. Withdrawal becomes visible to the patient via the entry's tombstoned state in their history; submit-time error dialogs are not used.

- [x] Append REQ-d00155/156/157 to `spec/dev-event-sourcing-mobile.md`.
- [x] Update `spec/INDEX.md` with new REQs and refreshed REQ-d00113 hash.
- [x] Commit: `git commit -m "Update REQ-d00113 and add REQ-d00155/156/157 for clinical_diary cutover"`.

---

#### Task 3: Add `event_sourcing_datastore` dep [x]

**Files:** `apps/daily-diary/clinical_diary/pubspec.yaml`.

- [x] Add `event_sourcing_datastore: path: ../../common-dart/event_sourcing_datastore` and `path_provider`. Remove `append_only_datastore`.
- [x] Run `flutter pub get && flutter analyze`. Expect: pub get succeeds, analyzer clean.
- [x] Commit: `git commit -m "Add event_sourcing_datastore dep to clinical_diary"`.

---

### Phase 3 — Build the new shape

Each task in this phase is TDD: failing test → implementation → green test → commit. The new code stands on its own; the old code is still present but no new code references it.

#### Task 4: Entry types [x]

**Files:** `lib/entry_types/clinical_diary_entry_types.dart`, `test/entry_types/clinical_diary_entry_types_test.dart`.

**Public surface:**

```dart
Future<List<EntryTypeDefinition>> loadClinicalDiaryEntryTypes();
```

Three static nosebleed types:

| `id` | `widgetId` | `widgetConfig` | `effectiveDatePath` |
| --- | --- | --- | --- |
| `epistaxis_event` | `epistaxis_form_v1` | `{}` | `startTime` |
| `no_epistaxis_event` | `epistaxis_form_v1` | `{'variant': 'no_epistaxis'}` | `date` |
| `unknown_day_event` | `epistaxis_form_v1` | `{'variant': 'unknown_day'}` | `date` |

Survey types derived from `questionnaires.json`: one `EntryTypeDefinition` per questionnaire; `id = '${qDef.id}_survey'`, `widgetId = 'survey_renderer_v1'`. `effectiveDatePath` unset (falls back to `client_timestamp`). Adding a new questionnaire is a JSON-only change.

**Header:** `// Implements: REQ-d00115, REQ-d00116, REQ-d00128`

- [x] Write tests; implement; run tests (PASS).
- [x] Commit: `git commit -m "Define clinical_diary entry types (surveys derived from questionnaires.json)"`.

---

#### Task 5: `PrimaryDiaryServerDestination` [x]

**Files:** `lib/destinations/primary_diary_server_destination.dart`, `test/destinations/primary_diary_server_destination_test.dart`.

**Public surface:**

```dart
class PrimaryDiaryServerDestination extends Destination {
  PrimaryDiaryServerDestination({
    required http.Client client,
    required Uri baseUrl,
    required Future<String?> Function() authToken,
  });
}
```

`id = 'primary_diary_server'`, `wireFormat = 'json-v1'`, `filter = const SubscriptionFilter()`, `maxAccumulateTime = Duration.zero`, `canAddToBatch(...) => false`.

HTTP classification:

| HTTP | Body | Result |
| --- | --- | --- |
| 2xx | any | `SendOk()` |
| 409 | `{"error":"questionnaire_deleted"}` | `SendOk()` |
| 409 | other | `SendPermanent(error: ...)` |
| 4xx | any | `SendPermanent(error: ...)` |
| 5xx | any | `SendTransient(error: ..., httpStatus: code)` |
| network/timeout | — | `SendTransient(error: ...)` |

**Header:** `// Implements: REQ-d00155-A+B+C+D+E; REQ-d00113-C`

- [x] Write tests; implement; run tests (PASS).
- [x] Commit: `git commit -m "Add PrimaryDiaryServerDestination with REQ-d00113-C 409 translation"`.

---

#### Task 6: `portalInboundPoll` [x]

**Files:** `lib/destinations/portal_inbound_poll.dart`, `test/destinations/portal_inbound_poll_test.dart`.

**Public surface:**

```dart
Future<void> portalInboundPoll({
  required EntryService entryService,
  required http.Client client,
  required Uri baseUrl,
  required Future<String?> Function() authToken,
});
```

GETs `{baseUrl}/inbound`. Body: `{"messages": [{"type":"tombstone", "entry_id":"...", "entry_type":"..."}, ...]}`. Each tombstone message → one `entryService.record(eventType: 'tombstone', changeReason: 'portal-withdrawn')` call. Network errors and non-200 responses are swallowed. Unknown message types are skipped.

**Header:** `// Implements: REQ-d00113-D, REQ-d00156-A+B+C+D`

- [x] Write tests; implement; run tests (PASS).
- [x] Commit: `git commit -m "Add portalInboundPoll for tombstone inbound path"`.

---

#### Task 7: `DiaryEntryReader` [x]

**Files:** `lib/services/diary_entry_reader.dart`, `test/services/diary_entry_reader_test.dart`.

**Public surface:**

```dart
enum DayStatus { nosebleed, noNosebleed, unknown, incomplete, notRecorded }

class DiaryEntryReader {
  DiaryEntryReader({required SembastBackend backend});
  Future<List<DiaryEntry>> entriesForDate(DateTime date, {String? entryType});
  Future<List<DiaryEntry>> entriesForDateRange(DateTime from, DateTime to);
  Future<List<DiaryEntry>> incompleteEntries({String? entryType});
  Future<bool> hasEntriesForYesterday();
  Future<DayStatus> dayStatus(DateTime date);
  Future<Map<DateTime, DayStatus>> dayStatusRange(DateTime from, DateTime to);
}
```

`DayStatus` precedence: `nosebleed` > `noNosebleed` > `unknown` > `incomplete` > `notRecorded`. Tombstoned entries (`isDeleted == true`) are excluded from every category. Questionnaire entries do not affect day status.

**Header:** `// Implements: REQ-p00013-A+B+E; REQ-p00004-E+L`

- [x] Write 13 tests (in-memory `SembastBackend`); implement; run tests (PASS).
- [x] Commit: `git commit -m "Add DiaryEntryReader (diary-shaped queries + dayStatus)"`.

---

#### Task 8: Trigger wiring [x]

**Files:** `lib/services/triggers.dart`, `test/services/triggers_test.dart`.

**Public surface:**

```dart
class TriggerHandles {
  TriggerHandles({required this.dispose});
  final Future<void> Function() dispose;
}

Future<TriggerHandles> installTriggers({
  required Future<void> Function() onTrigger,
  Duration periodicInterval = const Duration(minutes: 15),
  // @visibleForTesting factory overrides for lifecycle, timer, connectivity, FCM
});
```

Foreground only. No background isolate (per design §11 decision 11). `onTrigger` is passed in by `bootstrapClinicalDiary` — triggers don't depend on lib types beyond `Duration`. Trigger sources: `AppLifecycleState.resumed`, `Timer.periodic` while foreground, connectivity restored, FCM `onMessage` and `onMessageOpenedApp`. `dispose()` cancels all.

**Header:** `// Implements: REQ-d00157-A+B+C+D+E`

- [x] Write tests; implement; run tests (PASS).
- [x] Commit: `git commit -m "Wire clinical_diary sync triggers (foreground-only)"`.

---

#### Task 9: `bootstrapClinicalDiary` [x]

**Files:** `lib/services/clinical_diary_bootstrap.dart`, `test/services/clinical_diary_bootstrap_test.dart`.

**Public surface:**

```dart
class ClinicalDiaryRuntime {
  final SembastBackend backend;
  final EntryService entryService;
  final DiaryEntryReader reader;
  final SyncCycle syncCycle;
  final TriggerHandles triggerHandles;
  final DestinationRegistry destinations;
  Future<void> dispose();
}

Future<ClinicalDiaryRuntime> bootstrapClinicalDiary({
  required Database sembastDatabase,
  required Future<String?> Function() authToken,
  required String deviceId,
  required String softwareVersion,
  required String userId,
  required Uri primaryDiaryServerBaseUrl,
  http.Client? httpClient,
  // @visibleForTesting trigger factory overrides
});
```

Wiring sequence:

```text
1. SembastBackend(database: sembastDatabase)
2. loadClinicalDiaryEntryTypes()
3. PrimaryDiaryServerDestination(...)
4. bootstrapAppendOnlyDatastore(...) -> AppendOnlyDatastore
5. EntryService(backend, datastore.entryTypes, syncCycleTrigger, deviceInfo)
6. SyncCycle(backend, datastore.destinations)
7. DiaryEntryReader(backend)
8. installTriggers(onTrigger: () async {
     await syncCycle();
     await portalInboundPoll(entryService, client, baseUrl, authToken);
   })
9. return ClinicalDiaryRuntime(backend, entryService, reader,
       syncCycle, triggerHandles, datastore.destinations)
```

`backend` is exposed on the runtime so callers (e.g. the home screen wedge banner) can call `backend.anyFifoWedged()` without re-wrapping the database.

**Header:** `// Implements: REQ-d00134-A`

- [x] Write 4 tests (in-memory Sembast + `MockClient`); implement; run tests (PASS).
- [x] Commit: `git commit -m "Add clinical_diary bootstrap (composes runtime)"`.


---

#### Task 10: `DiaryExportService` [x]

**Files:** `lib/services/diary_export_service.dart`, `test/services/diary_export_service_test.dart`.

`DiaryExportService.exportAll()` dumps the full local event log as JSON. Returns a `DiaryExportResult` with a suggested filename and a JSON-encodable map.

**Header:** `// Implements: REQ-d00004`

- [x] Write 5 tests; implement; run tests (PASS). (Implemented as part of Phase 3 alongside bootstrap.)

---

### Phase 4 — Cut over screens and main.dart

#### Task 11: Delete old services and rewire all callers [x]

This is one task. The compiler is the migration checklist.

**Files deleted:**
- `lib/services/nosebleed_service.dart`
- `lib/services/questionnaire_service.dart`
- `test/services/nosebleed_service_test.dart`

**Files modified:** `lib/main.dart`, `lib/screens/{home,recording,simple_recording,calendar,date_records}_screen.dart`, `lib/services/notification_service.dart`, `lib/widgets/{event_list_item,calendar_overlay,overlap_warning}.dart`.

**`main.dart`** bootstraps the runtime:

```dart
late final ClinicalDiaryRuntime _runtime;
_runtime = await bootstrapClinicalDiary(
  sembastDatabase: await databaseFactoryIo.openDatabase('${appDocumentsDir.path}/diary.db'),
  authToken: _enrollmentService.currentAuthToken,
  deviceId: await _readOrMintInstallUuid(),
  softwareVersion: 'clinical-diary@${packageInfo.version}+${packageInfo.buildNumber}',
  userId: await _enrollmentService.currentUserId(),
  primaryDiaryServerBaseUrl: Uri.parse(diaryServerBaseUrl), // TODO: real URL from config
);
// Activate the primary destination once the start date is known.
runtime.destinations.setStartDate('primary_diary_server', enrollmentStartDate);
```

**Screen rewiring table:**

| Old call | New shape |
| --- | --- |
| `nosebleedService.addRecord/updateRecord` | `recording_screen.dart` form writes via `entryService.record(entryType: 'epistaxis_event', eventType: 'finalized', ...)` |
| `nosebleedService.markNoNosebleeds(date)` | `entryService.record(entryType: 'no_epistaxis_event', aggregateId: Uuid().v7(), eventType: 'finalized', answers: {'date': date.toIso8601String()})` |
| `nosebleedService.markUnknown(date)` | same with `'unknown_day_event'` |
| `nosebleedService.deleteRecord(id, reason)` | `entryService.record(entryType: <originalType>, aggregateId: id, eventType: 'tombstone', answers: {}, changeReason: reason)` |
| `nosebleedService.getLocalMaterializedRecords()` | `reader.entriesForDate(...)` / `reader.entriesForDateRange(...)` |
| `nosebleedService.hasRecordsForYesterday()` | `reader.hasEntriesForYesterday()` |
| `nosebleedService.getDayStatusRange(from, to)` | `reader.dayStatusRange(from, to)` |
| `nosebleedService.getDayStatus(date)` | `reader.dayStatus(date)` |
| `nosebleedService.getAllLocalRecords()` (for export) | `DiaryExportService.exportAll()` |
| `QuestionnaireService(...).submitResponses(...)` | Push `eq.QuestionnaireFlowScreen`; wire `onSubmit` callback to `entryService.record(entryType: surveyId, eventType: 'finalized', answers: responses)` |

**Nosebleed UX:** `recording_screen.dart` (full form for `epistaxis_event`) and `simple_recording_screen.dart` (marker variants) retain their existing form-construction and validation logic. The data-write path is `entryService.record(...)`. Display widgets read fields directly off `DiaryEntry.data`. The UI-only `NosebleedIntensity` enum lives in `lib/widgets/nosebleed_intensity.dart`.

**Survey UX:** Screens push `eq.QuestionnaireFlowScreen` directly (no intermediary widget). The `onSubmit` callback writes through `entryService.record(eventType: 'finalized')`.

**FIFO-wedge banner** on `home_screen.dart`:

```dart
FutureBuilder<bool>(
  future: runtime.backend.anyFifoWedged(),
  builder: (_, snap) => snap.data == true
      ? const _SyncWedgedBanner()
      : const SizedBox.shrink(),
),
```

**Notification service:** FCM token/permissions retained. Legacy sync-trigger subscriptions removed (now handled by `installTriggers`).

- [x] Delete old services. Fix compiler errors screen by screen.
- [x] Verify: `flutter test && flutter analyze` — PASS / clean.
- [x] Verify: `grep -rn 'NosebleedService\|QuestionnaireService' apps/daily-diary/clinical_diary/` — zero hits.
- [x] Commit: `git commit -m "Cut clinical_diary over to event_sourcing_datastore"`.

---

#### Task 12: Tighten screen wiring; wire export service [x]

Screens and widgets consume `DiaryEntry` directly. `DiaryExportService` is wired into `data_export_service.dart`.

- [x] Update all screen and widget references to use `DiaryEntry` fields directly.
- [x] Wire `DiaryExportService.exportAll()` in `data_export_service.dart`.
- [x] Verify: `flutter test && flutter analyze` — PASS / clean.
- [x] Commit: `git commit -m "Tighten screen wiring; wire export service"`.

---

### Phase 5 — Screen-level tests

#### Task 12.5: Restore screen test coverage [x]

**Files:** `test/screens/{home,recording,simple_recording,calendar}_screen_test.dart`.

26 tests covering: render with empty/some entries; each mark button produces the correct `record(...)` call; delete action produces a tombstone; navigation to recording UX. Injected `EntryService` (or fake) and `DiaryEntryReader`.

- [x] Write and pass 26 tests.
- [x] Commit: `git commit -m "[CUR-1169] Restore screen test coverage (Phase 12.5)"`.

---

#### Task 12.7: Reconcile plan doc to final implementation [x]

- [x] Rewrite this plan document in final-state voice; remove references to intermediate abstractions that did not survive.
- [x] Commit: `git commit -m "[CUR-1169] Reconcile plan doc to final implementation"`.

---

### Phase 6 — End-to-end tests

#### Task 13: End-to-end flow tests [ ]

**Files:** `apps/daily-diary/clinical_diary/test/integration/cutover_flow_test.dart`.

Widget tests under `test/integration/` (NOT `integration_test/` — those run on a real device and HTTP mocking is awkward). Use `WidgetTester`, `MockClient`, in-memory `SembastBackend`.

**Scenarios:**

1. **Nosebleed add** — boot app with mock backend → tap "Add Nosebleed" → fill → submit. Assert: 1 event in event log, 1 FIFO row pending; after `syncCycle()` the row is `sent`.
2. **Nosebleed edit** — create → edit → save. Assert: 2 events on same `aggregate_id`, view row reflects latest answers, both FIFO rows reach `sent`.
3. **Nosebleed delete** — create → delete. Assert: tombstone event, view row `is_deleted = true`, UI hides the entry.
4. **Questionnaire (QoL)** — open → answer each question → submit. Assert: `finalized` event, FIFO drains.
5. **REQ-d00113 tombstone inbound** — prime mock server's inbound endpoint with a tombstone message. Trigger `syncCycle`. Assert: tombstone event recorded, view row `is_deleted = true`, UI reflects deletion.
6. **REQ-d00113-C 409 translation** — mock server returns `409 questionnaire_deleted`. Assert: FIFO row `sent`, no submit-time error dialog.
7. **FIFO-wedge banner** — force a non-409 `SendPermanent`. Assert: `anyFifoWedged()` returns true; banner appears on home.
8. **Offline → online** — disable connectivity, create 2 entries (queued), re-enable. Assert: both sync.
9. **New questionnaire arrives via JSON** — fixture `questionnaires.json` with an extra questionnaire definition; assert `loadClinicalDiaryEntryTypes()` includes it and the survey UX renders it correctly.
10. **Day status range** — seed entries of each type across 3 days; assert `reader.dayStatusRange(from, to)` returns the correct `DayStatus` per day.
11. **Export** — seed entries; call `DiaryExportService.exportAll()`; assert the payload contains all events.

- [ ] Write tests.
- [ ] Run: `(cd apps/daily-diary/clinical_diary && flutter test test/integration/)`. Expected: PASS.
- [ ] Commit: `git commit -m "Add cutover end-to-end tests"`.

---

### Phase 7 — Version and CHANGELOG

#### Task 14: Bump version, write CHANGELOG entry [ ]

**Files:** `apps/daily-diary/clinical_diary/pubspec.yaml`, `apps/daily-diary/clinical_diary/CHANGELOG.md`.

- [ ] Bump clinical_diary version (minor — user-visible behavior change).
- [ ] Add CHANGELOG entry under today's date:

```markdown
## [x.y.z] - 2026-04-27

### Changed
- All patient writes flow through `EntryService.record()` from the `event_sourcing_datastore` library.
- Withdrawn questionnaires materialize as tombstoned entries via portal inbound poll instead of a submit-time error.

### Removed
- `NosebleedService`, `QuestionnaireService`.
```

- [ ] Run final `flutter test && flutter analyze`. Expected: PASS / clean.
- [ ] Commit: `git commit -m "Bump clinical_diary version and update CHANGELOG"`.

---

### Phase 8 — Pull request

#### Task 15: Open PR [ ]

- [ ] Pull latest main: `git fetch origin main && git rebase origin/main`.
- [ ] Push: `git push -u origin diary1`.
- [ ] Open PR:

```bash
gh pr create --title "[CUR-1169] Mobile daily-diary cutover to event_sourcing_datastore" --body "$(cat <<'EOF'
## Summary
- All patient writes (nosebleed, questionnaires, no-nosebleeds, unknown-day) flow through EntryService.record().
- NosebleedService and QuestionnaireService are deleted.
- REQ-d00113 updated: 409 questionnaire_deleted translates to SendOk; tombstoning happens via portal inbound poll.
- New REQs: REQ-d00155 (PrimaryDiaryServerDestination), REQ-d00156 (portalInboundPoll), REQ-d00157 (clinical_diary triggers).
- FIFO-wedge banner appears on home when any destination is wedged.

## Test plan
- [x] Unit + widget tests: clinical_diary flutter test (all phases)
- [x] Screen tests: 26 tests across home, recording, simple_recording, calendar screens
- [ ] End-to-end tests: flutter test test/integration/
- [ ] Manual smoke: nosebleed add/edit/delete; questionnaire fill/submit; offline to online sync; portal-tombstone arrives during foreground.

## Reviewers
Mobile + regulatory.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] Verify CI green.
- [ ] Hand off to user for merge — do not self-merge.

---

## Self-review checklist

- [ ] Library API contract signatures all match `apps/common-dart/event_sourcing_datastore/lib/src/...` source.
- [ ] No mention of `provenance` package as a dep (Source/DeviceInfo are in `event_sourcing_datastore`).
- [ ] No mention of `WirePayload.json(...)` factory (canonical constructor only).
- [ ] No mention of `SyncCycle.afterDrain` (inbound poll wires via `installTriggers`' `onTrigger`).
- [ ] `Source(hopId: ...)` everywhere, never `Source(hop: ...)`.
- [ ] No "if X doesn't exist on the library, adapt" branches anywhere.
- [ ] Screens push UX directly: recording screens for nosebleed, `eq.QuestionnaireFlowScreen` for surveys.
- [ ] `ClinicalDiaryRuntime` has 6 fields: `backend`, `entryService`, `reader`, `syncCycle`, `triggerHandles`, `destinations`.
- [ ] `DayStatus` has 5 values: `nosebleed`, `noNosebleed`, `unknown`, `incomplete`, `notRecorded`.
- [ ] File map lists only files in final state; deleted section covers only pre-cutover deletions.
