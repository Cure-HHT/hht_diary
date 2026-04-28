# CUR-1169 — Mobile Daily-Diary Cutover to `event_sourcing_datastore`

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The clinical_diary mobile app writes every patient event — nosebleeds *and questionnaires* — through `EntryService.record()` from the `event_sourcing_datastore` library and reads from the materialized `diary_entries` view. `NosebleedService` and `QuestionnaireService` are deleted.

**The questionnaire change is the bigger correction.** Today nosebleeds persist locally (in a bespoke append-only store) but questionnaires don't — `QuestionnaireService.submitResponses` POSTs straight to the server and returns success/error to the UI, with no local audit trail, no checkpoint persistence, no offline queueing. Post-cutover both kinds of patient input share one path: write to the local event log first, materialize to the `diary_entries` view, then drain to the server through the FIFO. Network failure no longer loses answers; app suspension no longer loses partial work; questionnaire submissions inherit the same hash-chained provenance as every other event.

**Five entry types share one write path:**

| `id` | Widget | Purpose |
| --- | --- | --- |
| `epistaxis_event` | `EpistaxisFormWidget` (full form) | Recorded nosebleed |
| `no_epistaxis_event` | `EpistaxisFormWidget` (marker variant) | "No nosebleeds today" marker |
| `unknown_day_event` | `EpistaxisFormWidget` (marker variant) | "Don't remember" marker |
| `nose_hht_survey` | `SurveyRendererWidget` | NOSE-HHT questionnaire |
| `hht_qol_survey` | `SurveyRendererWidget` | HHT Quality of Life questionnaire |

**Architecture:** A per-app bootstrap (`bootstrapClinicalDiary`) constructs a `SembastBackend`, registers the 5 entry types and the `PrimaryDiaryServerDestination`, and returns a runtime that exposes `EntryService`, the diary view reader, the `SyncCycle`, and trigger handles. Screens dispatch on `widget_id` via a switch (no registry). Inbound tombstone polling runs after each `SyncCycle`.

**Tech stack:** Dart, Flutter, Sembast (mobile storage via `event_sourcing_datastore`'s `SembastBackend`), `event_sourcing_datastore` library (CUR-1154, on `main`), `trial_data_types` package (questionnaire JSON assets).

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

These are the library APIs this plan depends on. No deferred "if X doesn't exist, adapt" branches: every signature has been verified against the source.

| Surface | Where | Shape |
| --- | --- | --- |
| `bootstrapAppendOnlyDatastore({backend, source, entryTypes, destinations, materializers, initialViewTargetVersions, syncCycleTrigger?})` | `lib/src/bootstrap.dart:84` | Returns `Future<AppendOnlyDatastore>` exposing `eventStore`, `entryTypes`, `destinations`, `securityContexts` |
| `EntryService({backend, entryTypes: EntryTypeRegistry, syncCycleTrigger, deviceInfo, clock?, uuid?})` | `lib/src/entry_service.dart:70` | Construct after bootstrap; pass `datastore.entryTypes` |
| `EntryService.record({entryType, aggregateId, eventType, answers, checkpointReason?, changeReason?})` | `lib/src/entry_service.dart:143` | Returns `Future<StoredEvent?>`. Sets `aggregateType: 'DiaryEntry'` internally |
| `EntryTypeDefinition({id, registeredVersion, name, widgetId, widgetConfig, effectiveDatePath?, destinationTags?, materialize?})` | `lib/src/entry_type_definition.dart:21` | Const-constructible |
| `Destination` (abstract) | `lib/src/destinations/destination.dart:36` | Override `id`, `filter`, `wireFormat`, `maxAccumulateTime`, `canAddToBatch`, `transform`, `send`. Defaults: `allowHardDelete = false`, `serializesNatively = false` |
| `WirePayload({bytes: Uint8List, contentType, transformVersion: String?})` | `lib/src/destinations/wire_payload.dart:22` | No `.json()` factory; canonical constructor only |
| `SendOk()` const, `SendTransient({error, httpStatus?})` const, `SendPermanent({error})` const | `lib/src/destinations/send_result.dart:18` | Sealed hierarchy |
| `SyncCycle({backend, registry, clock?, policy?, policyResolver?})` | `lib/src/sync/sync_cycle.dart:28` | No `afterDrain` callback. Inbound poll wires as a follow-up after each tick (Task 11) |
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
- `apps/daily-diary/clinical_diary/lib/entry_widgets/build_entry_widget.dart` (switch dispatch)
- `apps/daily-diary/clinical_diary/lib/entry_widgets/epistaxis_form_widget.dart`
- `apps/daily-diary/clinical_diary/lib/entry_widgets/survey_renderer_widget.dart`
- `apps/daily-diary/clinical_diary/lib/services/clinical_diary_bootstrap.dart`
- `apps/daily-diary/clinical_diary/lib/services/triggers.dart`
- `apps/daily-diary/clinical_diary/lib/services/diary_entry_reader.dart`
- Mirror tests under `apps/daily-diary/clinical_diary/test/`.

**Modified:**
- `apps/daily-diary/clinical_diary/pubspec.yaml`
- `apps/daily-diary/clinical_diary/lib/main.dart`
- `apps/daily-diary/clinical_diary/lib/screens/{home,recording,simple_recording,calendar}_screen.dart`
- `apps/daily-diary/clinical_diary/lib/services/{notification,data_export}_service.dart`
- `spec/dev-questionnaire.md` (REQ-d00113 assertions C/D/E/F rewrite)
- `spec/dev-event-sourcing-mobile.md` (append REQ-d00155/156/157)
- `spec/INDEX.md` (content-hash refresh + new REQ entries)

**Deleted:**
- `apps/daily-diary/clinical_diary/lib/services/nosebleed_service.dart`
- `apps/daily-diary/clinical_diary/lib/services/questionnaire_service.dart`
- `apps/daily-diary/clinical_diary/test/services/nosebleed_service_test.dart`

---

## Plan

### Phase 1 — Baseline

#### Task 1: Verify location and run baseline tests

**Files:** none (verification only).

Working directory: `/home/metagamer/cure-hht/hht_diary-worktrees/diary1`. Branch: `diary1`.

- [ ] **Confirm location**:

```bash
git rev-parse --show-toplevel
git branch --show-current
git log --oneline -3
```

Expected: toplevel ends in `hht_diary-worktrees/diary1`, branch is `diary1`, HEAD includes the CUR-1154 squash commit.

- [ ] **Verify CUR-1154 is upstream**:

```bash
git log --oneline main | grep -E "^[0-9a-f]+ \[CUR-1154\]"
```

Expected: one line.

- [ ] **Baseline tests** (must be green before any change):

```bash
(cd apps/common-dart/event_sourcing_datastore && dart test) && \
(cd apps/daily-diary/clinical_diary && flutter test)
```

Expected: PASS in both. If red, stop and surface — pre-existing breakage isn't in scope.

- [ ] **Manual smoke baseline** (so the cutover replicates the UX):
  - Run `clinical_diary` in an emulator.
  - Record a nosebleed. Mark a "no-nosebleeds" day. Open the QoL questionnaire and submit it.
  - Note which screens these flows touch.

- [ ] **Commit nothing.** Verification only.

---

### Phase 2 — REQ updates and pubspec

#### Task 2: Update REQ-d00113 and claim REQ-d00155/156/157

**Files:**
- Modify: `spec/dev-questionnaire.md`
- Modify: `spec/dev-event-sourcing-mobile.md`
- Modify: `spec/INDEX.md`

- [ ] **Discover existing applicable REQs** via the `elspais` MCP:

```
discover_requirements(query: "primary diary server destination 409 questionnaire deleted tombstone")
discover_requirements(query: "mobile sync trigger app lifecycle FCM connectivity periodic timer")
discover_requirements(query: "portal inbound poll tombstone diary mobile")
```

Record matches in the TASK_FILE so later tasks can cite them.

- [ ] **Claim next REQ-d numbers** (highest currently used: REQ-d00154):
  - **REQ-d00155** — `PrimaryDiaryServerDestination` contract (transform produces `json-v1`; classification table for 2xx/4xx/5xx including the 409 `questionnaire_deleted` → `SendOk` translation).
  - **REQ-d00156** — `portalInboundPoll` tombstone path (HTTP shape, idempotency via `EntryService.record` no-op, error handling).
  - **REQ-d00157** — clinical_diary sync triggers (lifecycle resumed, periodic timer while foreground, connectivity restored, FCM `onMessage` and `onMessageOpenedApp`, no background isolate).

  Run `mutate_add_requirement` for each with assertions A, B, C, … as drafted in the TASK_FILE.

- [ ] **Update REQ-d00113 in `spec/dev-questionnaire.md`**. Replace assertions C, D, E, F:

```markdown
C. `PrimaryDiaryServerDestination.send` SHALL translate an HTTP 409 response with body containing `"error": "questionnaire_deleted"` to `SendOk`. The submitted event remains in the local event log as the audit fact.

D. The portal inbound-poll endpoint SHALL deliver `{"type": "tombstone", "entry_id": "<uuid>", "entry_type": "<type>"}` messages for entries withdrawn server-side. On receipt, the app SHALL invoke `EntryService.record(entryType: <type>, aggregateId: <entry_id>, eventType: 'tombstone', answers: {}, changeReason: 'portal-withdrawn')`.

E. After a tombstone event materializes, the entry SHALL appear in the materialized `diary_entries` view with `is_deleted = true`. The home screen SHALL NOT offer the entry as an actionable task. The audit history view SHALL still show the entry.

F. Withdrawal becomes visible to the patient via the entry's tombstoned state in their history; submit-time error dialogs are not used.
```

- [ ] **Refresh REQ-d00113 content hash** at the end of the section.

- [ ] **Append REQ-d00155/156/157** to `spec/dev-event-sourcing-mobile.md` using the format of existing entries.

- [ ] **Update `spec/INDEX.md`** with the three new REQs and the REQ-d00113 hash change.

- [ ] **Run spec validation**: `tools/requirements/` if there is a script; otherwise `git diff --check`.

- [ ] **Commit**:

```bash
git add spec/
git commit -m "Update REQ-d00113 and add REQ-d00155/156/157 for clinical_diary cutover"
```

---

#### Task 3: Add `event_sourcing_datastore` dep

**Files:**
- Modify: `apps/daily-diary/clinical_diary/pubspec.yaml`

- [ ] **Add dependency** under `dependencies:`:

```yaml
  event_sourcing_datastore:
    path: ../../common-dart/event_sourcing_datastore
```

(Do NOT add `provenance` — `Source`/`DeviceInfo` are exported by `event_sourcing_datastore`.)

- [ ] **Run** `(cd apps/daily-diary/clinical_diary && flutter pub get && flutter analyze)`. Expect: pub get succeeds, analyzer clean.

- [ ] **Commit**: `git commit -m "Add event_sourcing_datastore dep to clinical_diary"`.

---

### Phase 3 — Build the new shape

Each task in this phase is TDD: failing test → implementation → green test → commit. The new code stands on its own; the old code is still present (and still wired) but no new code references it. Old code is deleted in Phase 4.

#### Task 4: Entry types

**Files:**
- Create: `lib/entry_types/clinical_diary_entry_types.dart`
- Create: `test/entry_types/clinical_diary_entry_types_test.dart`

Async loader. The three nosebleed types are static. **Survey types are derived from `questionnaires.json` at boot** — adding a new questionnaire is a JSON-only change with no Dart edit required.

**Public surface:**

```dart
Future<List<EntryTypeDefinition>> loadClinicalDiaryEntryTypes();
```

**Composition:**

| Source | Count | Shape |
| --- | --- | --- |
| static (nosebleed) | 3 | see table below |
| derived from `packages/trial_data_types/assets/data/questionnaires.json` | N | one `EntryTypeDefinition` per questionnaire definition; `id = '${qDef.id}_survey'`, `widgetId = 'survey_renderer_v1'`, `widgetConfig = qDef.toJson()` |

Static nosebleed types:

| `id` | `widgetId` | `widgetConfig` | `effectiveDatePath` |
| --- | --- | --- | --- |
| `epistaxis_event` | `epistaxis_form_v1` | `{}` | `startTime` |
| `no_epistaxis_event` | `epistaxis_form_v1` | `{'variant': 'no_epistaxis'}` | `date` |
| `unknown_day_event` | `epistaxis_form_v1` | `{'variant': 'unknown_day'}` | `date` |

Survey types: `effectiveDatePath` unset (falls back to `client_timestamp` — submission time, which the user confirmed is correct).

**Header:**

```dart
// Implements: REQ-d00115, REQ-d00116, REQ-d00128 — clinical_diary entry type
//   set: three static nosebleed variants plus one survey type per
//   questionnaire definition in questionnaires.json. New questionnaires are
//   added by editing the JSON only.
```

**Tests:**
- Three static nosebleed types are present with the ids and configs above.
- Every questionnaire definition in `questionnaires.json` produces exactly one survey entry type with `widgetId == 'survey_renderer_v1'`.
- Adding a fixture questionnaire to a test-only JSON path yields one extra entry type — proves the loader is data-driven, not hardcoded.
- All entry-type ids are unique across nosebleed + survey sets.

- [ ] Write tests; expect FAIL.
- [ ] Implement using `rootBundle.loadString('packages/trial_data_types/assets/data/questionnaires.json')` and `jsonDecode`. Iterate all questionnaire definitions; do not hardcode specific questionnaire ids.
- [ ] Run tests; expect PASS.
- [ ] Commit: `git commit -m "Define clinical_diary entry types (surveys derived from questionnaires.json)"`.

---

#### Task 5: `PrimaryDiaryServerDestination`

**Files:**
- Create: `lib/destinations/primary_diary_server_destination.dart`
- Create: `test/destinations/primary_diary_server_destination_test.dart`

Mirrors the existing diary HTTP shape (see `lib/services/nosebleed_service.dart` for the URL/headers/body the diary endpoint expects today). The cutover preserves the wire shape so the server doesn't change.

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

**Header:**

```dart
// Implements: REQ-d00155-A+B+C+D+E (destination contract); REQ-d00113-C
//   (409 questionnaire_deleted → SendOk so the FIFO drains; the locally
//   recorded event remains the audit fact).
```

**Classification:**

| HTTP | Body | Result |
| --- | --- | --- |
| 2xx | any | `SendOk()` |
| 409 | `{"error":"questionnaire_deleted"}` | `SendOk()` |
| 409 | other | `SendPermanent(error: ...)` |
| 4xx | any | `SendPermanent(error: ...)` |
| 5xx | any | `SendTransient(error: ..., httpStatus: code)` |
| network/timeout | — | `SendTransient(error: ...)` |

**Tests** (with `MockClient`):
- `transform` produces `WirePayload(contentType: 'application/json', transformVersion: 'v1', bytes: <utf8 of json>)`.
- 200 → `SendOk`.
- 500 → `SendTransient`.
- 404 → `SendPermanent`.
- 409 + `questionnaire_deleted` → `SendOk` (REQ-d00113-C).
- 409 + other body → `SendPermanent`.
- `ClientException` / `TimeoutException` → `SendTransient`.

- [ ] Write tests; expect FAIL.
- [ ] Implement.
- [ ] Run tests + `flutter analyze`; expect PASS / clean.
- [ ] Commit: `git commit -m "Add PrimaryDiaryServerDestination with REQ-d00113-C 409 translation"`.

---

#### Task 6: `portalInboundPoll`

**Files:**
- Create: `lib/destinations/portal_inbound_poll.dart`
- Create: `test/destinations/portal_inbound_poll_test.dart`

A free function called by the runtime after each `SyncCycle()` tick. Translates server-driven tombstone messages into `EntryService.record(eventType: 'tombstone', ...)` calls so the materialized view converges through the same write path user-driven deletions take.

**Public surface:**

```dart
Future<void> portalInboundPoll({
  required EntryService entryService,
  required http.Client client,
  required Uri baseUrl,
});
```

GETs `{baseUrl}/inbound`. Expected body: `{"messages": [{"type":"tombstone", "entry_id":"...", "entry_type":"..."}, ...]}`. Each tombstone message → one `entryService.record(entryType, aggregateId: entry_id, eventType: 'tombstone', answers: {}, changeReason: 'portal-withdrawn')`.

**Header:**

```dart
// Implements: REQ-d00113-D, REQ-d00156-A+B+C+D — portal-driven tombstones
//   converge through the same write path local deletions take. Idempotency
//   relies on EntryService.record's no-op-on-duplicate behavior.
```

**Tests:**
- Empty `messages` → no `record` calls.
- One tombstone → one `record(eventType: 'tombstone', changeReason: 'portal-withdrawn')` call.
- Multiple messages → preserves order.
- 5xx response → no calls, no exception.
- Unknown `type` → skipped.
- Network exception → no calls, no exception.

- [ ] Write tests; expect FAIL.
- [ ] Implement (use a real `EntryService` constructed against an in-memory `SembastBackend` for the test, or pass through to a thin spy if the library boundary is awkward — `EntryService` is not designed to be subclassed but a fake is fine in a test).
- [ ] Run tests; expect PASS.
- [ ] Commit: `git commit -m "Add portalInboundPoll for tombstone inbound path"`.

---

#### Task 7: `EpistaxisFormWidget` (3 variants)

**Files:**
- Create: `lib/entry_widgets/epistaxis_form_widget.dart`
- Create: `test/entry_widgets/epistaxis_form_widget_test.dart`
- Create: `test/entry_widgets/fake_entry_service.dart`

Three variants gated on `widgetConfig['variant']`:

| `variant` | UX |
| --- | --- |
| absent | full form: start time, end time, intensity, notes |
| `'no_epistaxis'` | marker-only: date + confirm button → `finalized` |
| `'unknown_day'` | marker-only: same shape with different copy → `finalized` |

**Public surface:**

```dart
class EntryWidgetContext {
  const EntryWidgetContext({
    required this.entryType,
    required this.aggregateId,
    required this.widgetConfig,
    required this.initialAnswers,
    required this.entryService,
  });
  final String entryType;
  final String aggregateId;
  final Map<String, Object?> widgetConfig;
  final Map<String, Object?>? initialAnswers;
  final EntryService entryService;
}

class EpistaxisFormWidget extends StatefulWidget {
  const EpistaxisFormWidget(this.ctx, {super.key});
  final EntryWidgetContext ctx;
}
```

**Header:**

```dart
// Implements: REQ-p00006-A+B (offline-first patient data entry);
//   REQ-d00004-E+F+G (local-first writes via EntryService);
//   REQ-p01067-A+B+C (nosebleed UI). Three variants gated on
//   widgetConfig['variant']: absent = full form, 'no_epistaxis' /
//   'unknown_day' = marker-only.
```

**Tests** (using `pumpWidget` + `WidgetTester` + `FakeEntryService`):
- Full-form variant renders all fields.
- Save with full form → one `record(eventType: 'finalized', entryType: 'epistaxis_event')` call.
- `no_epistaxis` variant: marker UI, confirm → one `record(eventType: 'finalized', entryType: 'no_epistaxis_event')` call.
- `unknown_day` variant: same with `unknown_day_event`.
- Edit existing entry: `record(aggregateId: existingId, eventType: 'finalized', changeReason: <reason>)`.
- Delete: `record(eventType: 'tombstone', changeReason: <reason>)`.

Move the form-construction, validation, and save logic from `recording_screen.dart` and `simple_recording_screen.dart`. Replace every former `nosebleedService.addRecord/updateRecord/deleteRecord` call with `ctx.entryService.record(...)`.

- [ ] Write tests; expect FAIL.
- [ ] Implement.
- [ ] Run tests; expect PASS.
- [ ] Commit: `git commit -m "Add EpistaxisFormWidget (3 variants)"`.

---

#### Task 8: `SurveyRendererWidget`

**Files:**
- Create: `lib/entry_widgets/survey_renderer_widget.dart`
- Create: `test/entry_widgets/survey_renderer_widget_test.dart`

This widget is where the questionnaire-persistence correction lands. Renders a `QuestionnaireDefinition` from `widgetConfig`. Each answered question records a `checkpoint` event with the cumulative answer map so partial work survives any app exit. Final submit records a `finalized` event with all answers. Once finalized: read-only. Tombstoned aggregate (`is_deleted = true` on view): "withdrawn" banner; fields read-only. Resumed mid-questionnaire (the patient quit and reopened): `initialAnswers` is the latest checkpoint's answer map, and the widget pre-fills accordingly so the patient continues where they stopped.

**Cycle stamping.** Each survey instance is associated with a sponsor-supplied `cycle` identifier (e.g. `"week-3"`) that arrives via the FCM message that prompted the survey. The launching surface (FCM handler / home screen / wherever) seeds the widget by passing `initialAnswers: {'cycle': '<value>', ...any-existing-answers}`. The widget treats `cycle` as immutable seed metadata: it never displays it as a question, but every checkpoint and the finalized event carries it forward in the cumulative answer map, so cycle is part of the aggregate's identity from the very first event. (FCM survey-prompt routing itself is out of scope for this ticket — the data model supports it; the trigger handler comes in a follow-up.)

**Header:**

```dart
// Implements: REQ-p01067, REQ-p01068 (survey questionnaires);
//   REQ-d00004-E+F+G (local-first writes); REQ-p00006-A+B (offline-first).
//   Each answered question → checkpoint with cumulative answers; final
//   submit → finalized. Resume reads initialAnswers from view. cycle is
//   carried verbatim from initialAnswers into every recorded event.
```

**Tests:**
- Renders all questions from `widgetConfig`.
- Answering question 1 records a `checkpoint` whose `answers` contains question 1's answer.
- Answering question 2 records a `checkpoint` whose `answers` contains BOTH question 1 and question 2 (cumulative).
- Final submit records `finalized` with all answers; UI flips to read-only.
- Resume: `initialAnswers != null` (mid-questionnaire) → questions 1..N pre-filled from `initialAnswers`, questions N+1.. unanswered, focus on the first unanswered.
- **Cycle stamping**: launching with `initialAnswers: {'cycle': 'week-3'}` and answering one question records a checkpoint whose `answers.cycle == 'week-3'`. Final submit's answers also carries `cycle: 'week-3'`.
- **Cycle is not rendered as a question** — UI shows only the questionnaire's defined questions.
- Tombstoned `initialAnswers` shape (the view row carries `is_deleted: true`) → renders read-only with "withdrawn" banner; no submit button.

Reuse the question-rendering logic from `questionnaire_service.dart` (extract the rendering parts; the `submitResponses` HTTP path is gone — every save is `EntryService.record`).

- [ ] Write tests; expect FAIL.
- [ ] Implement.
- [ ] Run tests; expect PASS.
- [ ] Commit: `git commit -m "Add SurveyRendererWidget"`.

---

#### Task 9: `DiaryEntryReader`

**Files:**
- Create: `lib/services/diary_entry_reader.dart`
- Create: `test/services/diary_entry_reader_test.dart`

A slim wrapper around `backend.findEntries(...)` that adds the diary-shaped `dayStatus` derivation. `findEntries` is already typed; this class earns its keep with `dayStatus` and the date-range conveniences.

**Public surface:**

```dart
enum DayStatus { recorded, noNosebleeds, unknown, empty }

class DiaryEntryReader {
  DiaryEntryReader({required SembastBackend backend});
  Future<List<DiaryEntry>> entriesForDate(DateTime date, {String? entryType});
  Future<List<DiaryEntry>> entriesForDateRange(DateTime from, DateTime to);
  Future<List<DiaryEntry>> incompleteEntries({String? entryType});
  Future<bool> hasEntriesForYesterday();
  Future<DayStatus> dayStatus(DateTime date);
}
```

**Header:**

```dart
// Implements: REQ-p00013-A+B+E (full history view);
//   REQ-p00004-E+L (event-derived view).
```

**Tests** (using an in-memory `SembastBackend`):
- `entriesForDate` returns only entries whose effective date matches.
- `entriesForDateRange` returns entries in `[from, to]`.
- `incompleteEntries` returns entries with `is_complete = false`.
- `hasEntriesForYesterday` returns true iff at least one entry exists for yesterday.
- `dayStatus`:
  - Date with `epistaxis_event` → `recorded`.
  - Date with only `no_epistaxis_event` → `noNosebleeds`.
  - Date with only `unknown_day_event` → `unknown`.
  - Date with no entries → `empty`.

- [ ] Write tests; expect FAIL.
- [ ] Implement using `backend.findEntries(...)` filtering.
- [ ] Run tests; expect PASS.
- [ ] Commit: `git commit -m "Add DiaryEntryReader"`.

---

#### Task 10: Trigger wiring

**Files:**
- Create: `lib/services/triggers.dart`
- Create: `test/services/triggers_test.dart`

Foreground only. No background isolate (per design §11 decision 11).

**Public surface:**

```dart
class TriggerHandles {
  TriggerHandles({required this.dispose});
  final Future<void> Function() dispose;
}

Future<TriggerHandles> installTriggers({
  required Future<void> Function() onTrigger,
  Duration periodicInterval = const Duration(minutes: 15),
});
```

`onTrigger` is the callback that runs `syncCycle()` and `portalInboundPoll(...)` in sequence — it's passed in by `bootstrapClinicalDiary` (Task 11) so triggers don't depend on lib types beyond `Duration`.

**Header:**

```dart
// Implements: REQ-d00157-A+B+C+D+E — clinical_diary sync triggers.
//   Lifecycle resumed, periodic timer (foreground only), connectivity
//   restored, FCM onMessage and onMessageOpenedApp. No background isolate.
```

**Tests:**
- `AppLifecycleState.resumed` → 1 trigger call.
- `Timer.periodic` while foreground fires at `periodicInterval` → calls accumulate.
- Lifecycle paused stops the timer; resumed restarts it.
- `connectivity_plus` offline→online → 1 call. online→offline → 0 calls.
- `FirebaseMessaging.onMessage` and `onMessageOpenedApp` each → 1 call.
- `dispose()` removes all observers / cancels all subscriptions.

- [ ] Write tests; expect FAIL.
- [ ] Implement.
- [ ] Run tests; expect PASS.
- [ ] Commit: `git commit -m "Wire clinical_diary sync triggers"`.

---

#### Task 11: `bootstrapClinicalDiary` and entry-widget switch

**Files:**
- Create: `lib/services/clinical_diary_bootstrap.dart`
- Create: `lib/entry_widgets/build_entry_widget.dart`
- Create: `test/services/clinical_diary_bootstrap_test.dart`

Composes all the new pieces into one `ClinicalDiaryRuntime`. The widget dispatch is a switch (no registry):

```dart
// lib/entry_widgets/build_entry_widget.dart
Widget buildEntryWidget(EntryWidgetContext ctx) {
  // Implements: REQ-d00115 — widget_id → widget dispatch.
  return switch (ctx.widgetConfig.containsKey('questions') ? 'survey_renderer_v1' : 'epistaxis_form_v1') {
    'epistaxis_form_v1' => EpistaxisFormWidget(ctx),
    'survey_renderer_v1' => SurveyRendererWidget(ctx),
    final id => throw ArgumentError('Unknown widget_id: $id'),
  };
}
```

(The dispatch key is the entry type's `widgetId` from its `EntryTypeDefinition`. The switch above resolves it directly; if a screen has the `EntryTypeDefinition` in scope, it passes `widgetId` through. Pick whichever shape reads cleanest in the screen call sites.)

**Public surface of bootstrap:**

```dart
class ClinicalDiaryRuntime {
  final EntryService entryService;
  final DiaryEntryReader reader;
  final SyncCycle syncCycle;
  final TriggerHandles triggerHandles;
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
});
```

**Wiring sequence inside bootstrap:**

```text
1. SembastBackend(database: sembastDatabase)
2. loadClinicalDiaryEntryTypes() -> List<EntryTypeDefinition>
3. PrimaryDiaryServerDestination(...)
4. bootstrapAppendOnlyDatastore(...) -> AppendOnlyDatastore
5. EntryService(backend, datastore.entryTypes, syncCycleTrigger, deviceInfo)
6. SyncCycle(backend: backend, registry: datastore.destinations)
7. DiaryEntryReader(backend)
8. installTriggers(onTrigger: () async { await syncCycle(); await portalInboundPoll(entryService: entryService, client: client, baseUrl: primaryDiaryServerBaseUrl); })
9. return ClinicalDiaryRuntime(...)
```

**Header:**

```dart
// Implements: REQ-d00134-A — single bootstrap entry point composing
//   SembastBackend, bootstrapAppendOnlyDatastore, EntryService, SyncCycle,
//   DiaryEntryReader, and triggers. Inbound poll runs after each tick.
```

**Tests** (in-memory Sembast + `MockClient`):
- `bootstrapClinicalDiary` returns a runtime whose `entryService.record(...)` writes a row that `reader.entriesForDate(today)` finds.
- `runtime.syncCycle()` drains the FIFO (mock returns 200) and the inbound poll runs after.
- `runtime.dispose()` cancels triggers cleanly.

- [ ] Write tests; expect FAIL.
- [ ] Implement.
- [ ] Run tests + `flutter analyze`; expect PASS / clean.
- [ ] Commit: `git commit -m "Add clinical_diary bootstrap"`.

---

### Phase 4 — Rip and replace

#### Task 12: Delete old services and rewire all callers

This is one task. Greenfield: the old code goes the moment all the new pieces exist. The compiler tells us every caller; we fix them all and ship.

**Files modified:**
- `lib/main.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/recording_screen.dart`
- `lib/screens/simple_recording_screen.dart`
- `lib/screens/calendar_screen.dart`
- `lib/services/notification_service.dart`
- `lib/services/data_export_service.dart`
- All matching tests under `test/`.

**Files deleted:**
- `lib/services/nosebleed_service.dart`
- `lib/services/questionnaire_service.dart`
- `test/services/nosebleed_service_test.dart`
- `test/services/questionnaire_service_test.dart` (if it exists)

**Step 1: delete the old services and tests.**

```bash
rm apps/daily-diary/clinical_diary/lib/services/nosebleed_service.dart \
   apps/daily-diary/clinical_diary/lib/services/questionnaire_service.dart \
   apps/daily-diary/clinical_diary/test/services/nosebleed_service_test.dart
[ -f apps/daily-diary/clinical_diary/test/services/questionnaire_service_test.dart ] && \
   rm apps/daily-diary/clinical_diary/test/services/questionnaire_service_test.dart
```

The build is now broken across `main.dart` and four screens. Good — the compiler is the migration checklist.

**Step 2: rewire `main.dart`.**

Replace the `NosebleedService` construction with:

```dart
late final ClinicalDiaryRuntime _runtime;
_runtime = await bootstrapClinicalDiary(
  sembastDatabase: await databaseFactoryIo.openDatabase('${appDocumentsDir.path}/diary.db'),
  authToken: _enrollmentService.currentAuthToken,
  deviceId: await _readOrMintInstallUuid(),
  softwareVersion: 'clinical-diary@${packageInfo.version}+${packageInfo.buildNumber}',
  userId: await _enrollmentService.currentUserId(),
  primaryDiaryServerBaseUrl: Uri.parse(diaryServerBaseUrl),
);
```

Pass `_runtime.entryService`, `_runtime.reader`, `_runtime.syncCycle` down through screen constructors.

**Step 3: rewire each screen.** The replacement table:

| Old call | New call |
| --- | --- |
| `nosebleedService.addRecord/updateRecord/deleteRecord` | `EpistaxisFormWidget` UI handles the writes; screens just instantiate it via `buildEntryWidget(ctx)` |
| `nosebleedService.markNoNosebleeds(date)` | `entryService.record(entryType: 'no_epistaxis_event', aggregateId: Uuid().v7(), eventType: 'finalized', answers: {'date': date.toIso8601String()})` |
| `nosebleedService.markUnknown(date)` | same with `'unknown_day_event'` |
| `nosebleedService.deleteRecord(id, reason)` | `entryService.record(entryType: <originalType>, aggregateId: id, eventType: 'tombstone', answers: {}, changeReason: reason)` |
| `nosebleedService.getLocalMaterializedRecords()` | `reader.entriesForDate(...)` / `reader.entriesForDateRange(...)` |
| `nosebleedService.hasRecordsForYesterday()` | `reader.hasEntriesForYesterday()` |
| `nosebleedService.getRecordsForStartDate(date)` | `reader.entriesForDate(date)` |
| `nosebleedService.getDayStatusRange(from, to)` | loop `reader.dayStatus(date)` over the range |
| `nosebleedService.getDayStatus(date)` | `reader.dayStatus(date)` |
| `nosebleedService.getDeviceUuid()` | `deviceId` (passed through bootstrap) |
| `nosebleedService.getAllLocalRecords()` (for export) | `reader.entriesForDateRange(<earliest>, <now>)` |
| `QuestionnaireService(...).getDefinition(...)` + `submitResponses(...)` | `buildEntryWidget(ctx)` resolves to `SurveyRendererWidget`; the widget owns submission via `EntryService.record` |
| `NotificationService` calling legacy sync | inject `runtime.syncCycle` (or a `Future<void> Function()` wrapping it); FCM callbacks call it |

**Step 4: add the FIFO-wedge banner** on `home_screen.dart` (per design §12.1):

```dart
FutureBuilder<bool>(
  future: backend.anyFifoExhausted(),
  builder: (_, snap) => snap.data == true
      ? const _SyncWedgedBanner()
      : const SizedBox.shrink(),
),
```

A one-line `Container` with text "Some data is not syncing — please update the app." Visible state is in scope; UX polish is out.

**Step 4b: incomplete-survey modal routing.** On home-screen build (and on app foreground via the lifecycle observer), check `reader.incompleteEntries()` for any survey-typed entries. If one exists, push the `SurveyRendererWidget` for it as a modal route — `Navigator.push` with `PageRoute` whose `WillPopScope` (or `PopScope` on newer Flutter) blocks back navigation, no other tabs accessible until `finalized`. The widget reads `initialAnswers` from the view row so prior checkpoints (including any seeded `cycle` value) are preserved.

This is the current UX requirement and is subject to change — keep the routing logic isolated in one place (a `_maybePushIncompleteSurvey()` method on the home-screen state) so revising the modality is a one-file change.

**Step 5: rewire screen tests.** The screen tests previously injected `NosebleedService` / `QuestionnaireService`. They now inject `EntryService` (or a fake) and `DiaryEntryReader`. Cover at minimum:
- Render with empty / some entries.
- Each "mark" button → `record` call with correct args.
- Delete action → tombstone `record` call.
- Tap a saved entry → opens the entry widget (`EpistaxisFormWidget` or `SurveyRendererWidget`).

**Step 6: verify clean.**

```bash
(cd apps/daily-diary/clinical_diary && flutter test && flutter analyze)
```

Expected: PASS / clean.

```bash
grep -rn 'NosebleedService\|nosebleedService\|QuestionnaireService\|questionnaireService' \
  apps/daily-diary/clinical_diary/
```

Expected: zero hits.

**Step 7: manual smoke test.** Every flow from Task 1's baseline (add nosebleed, mark no-nosebleeds, mark unknown, fill questionnaire, edit past entry, delete past entry, calendar navigation). Confirm visible behavior matches the baseline.

- [ ] **Commit**: `git commit -m "Cut clinical_diary over to event_sourcing_datastore; delete legacy services"`.

---

### Phase 5 — Integration tests

#### Task 13: End-to-end flow tests

**Files:**
- Create: `apps/daily-diary/clinical_diary/test/integration/cutover_flow_test.dart`

Widget tests under `test/integration/` (NOT `integration_test/` — those run on a real device and HTTP mocking is awkward). Use `WidgetTester`, `MockClient`, in-memory `SembastBackend`.

**Scenarios:**

1. **Nosebleed add** — boot app with mock backend → tap "Add Nosebleed" → fill → submit. Assert: 1 event in event log, 1 FIFO row pending; after `syncCycle()` the row is `sent`.
2. **Nosebleed edit** — create → edit → save. Assert: 2 events on same `aggregate_id`, view row reflects latest answers, both FIFO rows reach `sent`.
3. **Nosebleed delete** — create → delete. Assert: tombstone event, view row `is_deleted = true`, UI hides the entry.
4. **Questionnaire (QoL)** — open → answer each question (checkpoints accumulate) → submit. Assert: N+1 events on the `aggregate_id`, last is `finalized`, FIFO drains.
5. **Questionnaire resume modal** — pre-seed an aggregate with one checkpoint (one answered question + `cycle: 'week-3'`), boot the app, mount home. Assert: home does not render normally; the modal `SurveyRendererWidget` is on top, the answered question is pre-filled, the unanswered questions are pending, back navigation is blocked. Submit; assert home renders normally afterward.
6. **Cycle stamping** — launch survey with `initialAnswers: {'cycle': 'week-3'}`, answer one question, submit. Assert: every event for the aggregate carries `data.answers.cycle == 'week-3'` (one checkpoint plus one finalized).
7. **REQ-d00113 tombstone inbound** — prime mock server's inbound endpoint with `{"type":"tombstone","entry_id":"X","entry_type":"nose_hht_survey"}`. Trigger `syncCycle`. Assert: tombstone event for X, view row `is_deleted = true`, UI reflects deletion.
8. **REQ-d00113-C 409 translation** — mock server returns `409 questionnaire_deleted`. Assert: FIFO row `sent`, no submit-time error dialog.
9. **FIFO-wedge banner** — force a non-409 `SendPermanent`. Assert: `anyFifoExhausted()` returns true; banner appears on home.
10. **Offline → online** — disable connectivity, create 2 entries (queued), re-enable. Assert: both sync.
11. **New questionnaire arrives via JSON** — fixture `questionnaires.json` carrying an extra questionnaire definition; assert `loadClinicalDiaryEntryTypes()` includes it as an entry type and the `SurveyRendererWidget` renders it correctly. Confirms the data-driven loader path.

- [ ] Write tests.
- [ ] Run: `(cd apps/daily-diary/clinical_diary && flutter test test/integration/)`. Expected: PASS.
- [ ] Commit: `git commit -m "Add cutover end-to-end tests"`.

---

### Phase 6 — Version and CHANGELOG

#### Task 14: Bump version, write CHANGELOG entry

**Files:**
- Modify: `apps/daily-diary/clinical_diary/pubspec.yaml`
- Modify: `apps/daily-diary/clinical_diary/CHANGELOG.md` (or repo CHANGELOG)

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

- [ ] **Final verification**:

```bash
(cd apps/daily-diary/clinical_diary && flutter test && flutter analyze)
```

Expected: PASS / clean.

- [ ] Commit: `git commit -m "Bump clinical_diary version and update CHANGELOG"`.

---

### Phase 7 — Pull request

#### Task 15: Open PR

- [ ] Pull latest main:

```bash
git fetch origin main && git rebase origin/main
```

Resolve conflicts via manual edits. Do not skip work commits.

- [ ] Push:

```bash
git push -u origin diary1
```

- [ ] Open PR:

```bash
gh pr create --title "[CUR-1169] Mobile daily-diary cutover to event_sourcing_datastore" --body "$(cat <<'EOF'
## Summary
- All patient writes (nosebleed, questionnaires, no-nosebleeds, unknown-day) flow through `EntryService.record()`.
- `NosebleedService` and `QuestionnaireService` are deleted.
- REQ-d00113 updated: 409 `questionnaire_deleted` translates to `SendOk`; tombstoning happens via portal inbound poll.
- New REQs: REQ-d00155 (PrimaryDiaryServerDestination), REQ-d00156 (portalInboundPoll), REQ-d00157 (clinical_diary triggers).
- FIFO-wedge banner appears on home when any destination is exhausted.

## Test plan
- [x] Unit + widget tests: clinical_diary `flutter test`
- [x] End-to-end tests: `flutter test test/integration/`
- [ ] Manual smoke: nosebleed add/edit/delete; questionnaire fill/submit; offline → online sync; portal-tombstone arrives during foreground.

## Reviewers
Mobile + regulatory.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] Verify CI green.
- [ ] Hand off to user for merge — do not self-merge.

---

## Self-review checklist (run before announcing the plan complete)

- [ ] Library API contract section's signatures all match `apps/common-dart/event_sourcing_datastore/lib/src/...` source.
- [ ] No mention of `provenance` package as a dep (Source/DeviceInfo are in `event_sourcing_datastore`).
- [ ] No mention of `WirePayload.json(...)` factory (canonical constructor only).
- [ ] No mention of `SyncCycle.afterDrain` (inbound poll wires via `installTriggers`' `onTrigger`).
- [ ] `Source(hopId: ...)` everywhere, never `Source(hop: ...)`.
- [ ] No `EntryWidgetRegistry` (replaced by `buildEntryWidget` switch).
- [ ] No "if X doesn't exist on the library, adapt" branches anywhere.
- [ ] No "boot but don't exercise screens" intermediate state; old code stays wired right up until Task 12 deletes it.
- [ ] Phase 3 task count matches what's needed (no separate task per screen).
- [ ] Spec coverage: every section of `2026-04-21-mobile-event-sourcing-refactor-design.md` §6, §7.2, §9, §10, §11 maps to a task here OR is already covered by merged CUR-1154 work.
