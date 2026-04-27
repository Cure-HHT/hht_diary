# Master Plan Phase 4.6: Demo app

**Branch**: `mobile-event-sourcing-refactor` (shared)
**Ticket**: CUR-1154
**Phase**: 4.6 of 5 (inserted after 4.3, before 5)
**Status**: Not Started
**Depends on**: Phase 4.3 squashed and phase-reviewed (library additions, dynamic destinations, batch FIFO, EntryService/EntryTypeRegistry/bootstrap, SyncPolicy value-object retrofit)

## Scope

Build a Flutter Linux-desktop sandbox at `apps/common-dart/append_only_datastore/example/` that exercises every library feature shipped in Phase 4 + 4.3 end-to-end through live UI controls. The demo is a developer review tool; reviewers walk nine `USER_JOURNEYS.md` scenarios and confirm each *Expected Outcome* by eye. The design lives in `docs/superpowers/2026-04-22-dynamic-destinations-and-demo-design.md` §7.

**Produces:**
- `example/` directory scaffolded via `flutter create --platforms=linux --org com.example --project-name append_only_datastore_demo .`, with hand-written `lib/` contents per design §7.2.
- `lib/main.dart`, `lib/app.dart`, `lib/app_state.dart`, `lib/demo_types.dart`, `lib/demo_destination.dart`, `lib/demo_sync_policy.dart`.
- `lib/widgets/`: `top_action_bar.dart`, `sync_policy_bar.dart`, `materialized_panel.dart`, `event_stream_panel.dart`, `fifo_panel.dart`, `add_destination_dialog.dart`, `detail_panel.dart`, `styles.dart`.
- `test/app_state_test.dart` (plus small unit tests for `demo_destination.dart`, `demo_sync_policy.dart`, `demo_types.dart`, `styles.dart`).
- A signed-off walk of **all nine journeys** in `apps/common-dart/append_only_datastore/example/USER_JOURNEYS.md`.

**Does not produce:**
- Widget tests, golden tests, integration tests. (Non-goal per design §4.2; manual visual acceptance only.)
- CI automation for the demo (Linux-desktop CI is separate infra work; not on this ticket).
- Packaging, installers, distribution.
- Sponsor-specific destinations, real network destinations, FCM, connectivity-plus, AppLifecycle — these are Phase 5.
- New REQ assertions. The demo is a consumer of existing REQs; it introduces none.
- Widget registry, form widgets, screen updates in `clinical_diary` — Phase 5.

## Execution Rules

Read [README.md](README.md) for:
- TDD cadence (§"TDD cadence (applies to every task in every phase)") — every implementation file gets unit tests first, failing, then implementation; `// Implements:` / `// Verifies:` markers with REQ citations.
- Phase-boundary squash procedure (§"Phase-boundary squash procedure") — all intra-phase commits squashed to one at phase end with subject `[CUR-1154] Phase 4.6: Demo app`.
- Cross-phase invariants (§"Cross-phase invariants") — at the end of this phase, `dart test` / `flutter test` / `flutter analyze` must be clean on every touched package.
- REQ citation convention (§"REQ citation convention") — per-function comments, not file headers.

Read design doc §7 in full before Task 1. Pay particular attention to §7.4 (palette), §7.6 (DemoDestination), §7.7 (SyncPolicy defaults). Read `apps/common-dart/append_only_datastore/example/USER_JOURNEYS.md` before Task 15.

Widget-heavy tasks (10-13) have **no unit tests by design** — design non-goal §4.2 explicitly rejects widget tests for the demo. A per-task "Test skip rationale" line documents this so reviewers don't mistake it for missed TDD.

---

## Applicable REQ assertions

The demo validates existing REQs from Phases 4 and 4.3 via the nine acceptance journeys. It does not introduce new assertions.

| REQ | Topic | Validated via |
| --- | --- | --- |
| REQ-p00004 | Immutable audit trail via event sourcing | JNY-01, JNY-02, JNY-06 |
| REQ-p00006 | Offline-first data entry | JNY-01 |
| REQ-p00013 | Complete data change history | JNY-01, JNY-06 |
| REQ-p01001 | Offline event queue w/ automatic sync | JNY-03, JNY-04 |
| REQ-d00004 | Local-first data entry implementation | JNY-01 |
| REQ-d00133 | EntryService.record Contract | JNY-01, JNY-02 |
| REQ-d00134 | bootstrapAppendOnlyDatastore Contract | All journeys (boot path) |
| REQ-d00126 | SyncPolicy Injectable Value Object | JNY-04, JNY-05 |
| REQ-d00125 | sync_cycle() Orchestrator and Trigger Contract | JNY-01, JNY-02 |
| REQ-d00122 | Destination Contract for Per-Destination Sync | JNY-02, JNY-03 |
| REQ-d00129 | Dynamic Destination Lifecycle (addDestination / setStartDate / setEndDate / deleteDestination) | JNY-03, JNY-07, JNY-08, JNY-09 |
| REQ-d00130 | Historical Replay on Past startDate | JNY-07 |
| REQ-d00129-I | Time-window filtering clause of Dynamic Destination Lifecycle | JNY-08 |
| REQ-d00128 | Batch Shape: canAddToBatch, maxAccumulateTime, transform(List&lt;StoredEvent&gt;) | JNY-03, JNY-07 |
| REQ-d00119 | Per-Destination FIFO Queue Semantics | JNY-01, JNY-03, JNY-04 |
| REQ-d00131 | Unjam Destination Operation | JNY-09 |
| REQ-d00132 | Rehabilitate Exhausted FIFO Row | JNY-09 |
| REQ-d00127 | markFinal and appendAttempt Tolerate Missing FIFO Row | JNY-09 (race with delete/unjam) |

REQ-d number substitution performed at Task 1 against `spec/dev-event-sourcing-mobile.md` and library REQ-citation headers. Mapping table recorded in `PHASE_4.6_WORKLOG.md` Task 1 section.

---

## Plan

### Task 1: Baseline verification

**TASK_FILE**: `PHASE4.6_TASK_1.md`

- [ ] **Confirm Phase 4.3 complete**: `git log --oneline origin/main..HEAD` shows `[CUR-1154] Phase 4.3: ...` as the current HEAD (or immediately behind any review-feedback fixups). If not, stop and complete Phase 4.3 first.
- [ ] **Stay on shared branch** `mobile-event-sourcing-refactor` (no new branch).
- [ ] **Rebase onto main**: `git fetch origin main && git rebase origin/main`. Resolve conflicts if any; Phase 4.3 rebase conflicts would surface first.
- [ ] **Baseline tests — all green**:
  - `(cd apps/common-dart/append_only_datastore && flutter test && flutter analyze)`
  - `(cd apps/daily-diary/clinical_diary && flutter test && flutter analyze)`
- [ ] **Confirm library surface expected for this phase** is exported from `package:append_only_datastore/append_only_datastore.dart` — `bootstrapAppendOnlyDatastore`, `EntryService`, `EntryTypeRegistry`, `EntryTypeDefinition`, `Destination`, `SubscriptionFilter`, `DestinationRegistry`, `Event`, `WirePayload`, `SendOk`, `SendTransient`, `SendPermanent`, `SyncPolicy`, `syncCycle`, `rebuildMaterializedView`, `UnjamResult`, `SetEndDateResult`. If any symbol is missing, stop — Phase 4.3 is incomplete.
- [ ] **Substitute actual REQ-d numbers** into the "Applicable REQ assertions" table above, replacing the topic-name placeholders (`REQ-ENTRY`, `REQ-DYNDEST`, etc.) with the numbers claimed in Phase 4.3's spec work. Record a one-line mapping in TASK_FILE.
- [ ] **Create TASK_FILE** with baseline output, Phase 4.3 completion SHA, and the REQ-topic-to-REQ-d mapping.

---

### Task 2: Scaffold the `example/` Flutter Linux-desktop app

**TASK_FILE**: `PHASE4.6_TASK_2.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/example/` (everything under here via `flutter create`)
- Delete: the auto-generated `example/test/widget_test.dart`
- Modify: `apps/common-dart/append_only_datastore/.gitignore` (add `example/build/`, `example/linux/flutter/ephemeral/`, standard Flutter ignores if not already covered)

**No applicable REQs** — pure scaffolding.

- [ ] **Baseline**: green from Task 1.
- [ ] **Create TASK_FILE**.
- [ ] **Scaffold the app** from inside the example directory:

  ```bash
  (cd apps/common-dart/append_only_datastore && \
    mkdir -p example && \
    cd example && \
    flutter create --platforms=linux --org com.example \
      --project-name append_only_datastore_demo --overwrite .)
  ```

  `--overwrite` is safe here because `USER_JOURNEYS.md` is the only pre-existing file in `example/` and `flutter create` will not overwrite it (different path).
- [ ] **Delete the auto-generated widget_test.dart**: `rm apps/common-dart/append_only_datastore/example/test/widget_test.dart`. Non-goal §4.2 excludes widget tests.
- [ ] **Delete the auto-generated `lib/main.dart` stub content** — leave the file but empty it to a one-line comment (`// Rewritten in Task 9.`). This keeps `flutter analyze` happy between Task 2 and Task 9.
- [ ] **Verify scaffold builds**: `(cd apps/common-dart/append_only_datastore/example && flutter pub get && flutter analyze)`. Expected: zero errors (one placeholder warning about empty main.dart is acceptable and goes away in Task 9).
- [ ] **Add `example/.gitignore` entries** for `build/`, `linux/flutter/ephemeral/`, `.dart_tool/`, `.flutter-plugins*`, and `.packages` if not already in the generated one. (Most will be there.)
- [ ] **Commit**: "Scaffold example Flutter Linux desktop app (CUR-1154)".

---

### Task 3: Wire `example/pubspec.yaml` to parent package

**TASK_FILE**: `PHASE4.6_TASK_3.md`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/example/pubspec.yaml`
- Modify (if needed): `apps/common-dart/append_only_datastore/example/analysis_options.yaml` — inherit the project-root analysis options.

**No applicable REQs** — wiring only.

- [ ] **Baseline**: green from Task 2.
- [ ] **Create TASK_FILE**.
- [ ] **Set `publish_to: none`** at the top of the pubspec (confirm `flutter create` already wrote it; it does).
- [ ] **Declare path dependency on the parent package**:

  ```yaml
  dependencies:
    flutter:
      sdk: flutter
    append_only_datastore:
      path: ../
  ```

  Do not add other runtime dependencies — the demo relies only on what the parent package transitively pulls in (`sembast`, `path_provider`, etc.). `path_provider` is already a dep of `append_only_datastore` per its pubspec.
- [ ] **dev_dependencies**: keep the `flutter_test` entry that `flutter create` generated; remove `flutter_lints` unless the root already uses it (it does via `append_only_datastore/analysis_options.yaml`).
- [ ] **Set `analysis_options.yaml`** in `example/` to:

  ```yaml
  include: ../analysis_options.yaml
  ```

  (Inherit the parent package's lint config so the demo is held to the same bar as the library.)
- [ ] **Run `flutter pub get`** inside the example. Expected: resolves cleanly.
- [ ] **Run `flutter analyze`** inside the example. Expected: zero errors.
- [ ] **Commit**: "Wire example pubspec to parent package (CUR-1154)".

---

### Task 4: `styles.dart` — palette tripwire

**TASK_FILE**: `PHASE4.6_TASK_4.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/example/lib/widgets/styles.dart`
- Create: `apps/common-dart/append_only_datastore/example/test/styles_test.dart`

**Applicable REQs**: none directly. This task is a tripwire unit test that guards the locked palette from accidental drift — the design doc §7.4 explicitly locks the 12%-below-max brightness palette because the state cues depend on it (green = sent, red = retrying, magenta = exhausted, yellow = draining head, blue = cross-panel selection).

- [ ] **Baseline**: green from Task 3.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests** (`styles_test.dart`):
  - `DemoColors.bg == 0xFF000000`
  - `DemoColors.fg == 0xFFFFFFFF`
  - `DemoColors.accent == 0xFFE0E000`   // yellow — section headers, draining head
  - `DemoColors.sent == 0xFF00E000`     // green
  - `DemoColors.pending == 0xFFAAAAAA`  // grey
  - `DemoColors.retrying == 0xFFE00000` // red — head in transient retry
  - `DemoColors.exhausted == 0xFFE000E0`// magenta — exhausted row, inert
  - `DemoColors.selected == 0xFF0044AA` // blue — cross-panel selection
  - `DemoColors.border == 0xFFFFFFFF`
  - Action button colors: `red == 0xFFE00000`, `green == 0xFF00E000`, `blue == 0xFF005AE0`.
  - `DemoText.bodyFontSize == 20` (monospace)
  - `DemoText.headerFontSize` in range `[24, 28]`
  - `demoBorder.width == 3.0`, `demoBorder.color == DemoColors.border`, `demoBorder` has no borderRadius (rectangular).

  Each test with `// Verifies:` prose citing "design §7.4 palette lock". (No REQ number since the palette is a design-local lock, not a REQ.)
- [ ] **Run tests**; expect failures (undefined symbols).
- [ ] **Implement `styles.dart`**:
  - `class DemoColors { static const bg = Color(0xFF000000); ... }` — all nine state colors + three action colors as `static const Color`.
  - `class DemoText { static const bodyFontSize = 20.0; static const headerFontSize = 24.0; static const fontFamilyMonospace = 'monospace'; static const TextStyle body = ...; static const TextStyle header = ...; }`
  - `final demoBorder = Border.all(color: DemoColors.border, width: 3.0);`
  - Per-class header comment: `// Design: §7.4 palette lock. Tripwire test in styles_test.dart asserts every hex value.`
- [ ] **Run tests**; expect pass.
- [ ] **Lint**: `flutter analyze` clean.
- [ ] **Commit**: "Demo styles with palette-tripwire unit test (CUR-1154)".

---

### Task 5: `demo_types.dart` — entry type definitions

**TASK_FILE**: `PHASE4.6_TASK_5.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/example/lib/demo_types.dart`
- Create: `apps/common-dart/append_only_datastore/example/test/demo_types_test.dart`

**Applicable REQs**: REQ-BOOTSTRAP (entry type registration), REQ-ENTRY (EntryService consults registry), plus the aggregate_type CQRS discriminator validated in JNY-02.

- [ ] **Baseline**: green from Task 4.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests** (`demo_types_test.dart`):
  - `demoNoteType.id == 'demo_note'`; `demoNoteType.aggregateType == 'DiaryEntry'`; `demoNoteType.effectiveDatePath == 'date'`; `demoNoteType.widgetId == 'demo_note_widget_v1'` (widgetId not actually used by the demo but is part of the EntryTypeDefinition contract).
  - `redButtonType.id == 'red_button_pressed'`; `redButtonType.aggregateType == 'RedButtonPressed'`.
  - `greenButtonType.id == 'green_button_pressed'`; `greenButtonType.aggregateType == 'GreenButtonPressed'`.
  - `blueButtonType.id == 'blue_button_pressed'`; `blueButtonType.aggregateType == 'BlueButtonPressed'`.
  - `allDemoEntryTypes` list contains all four and has unique `id`s (no dupes).
  - All three action-button aggregateTypes are != `'DiaryEntry'` (CQRS discriminator for JNY-02).
  - Each `// Verifies:` cites the Phase-4.3 REQ-d number claimed for EntryTypeDefinition + JNY-02 aggregate_type discriminator.
- [ ] **Run tests**; expect failures.
- [ ] **Implement `demo_types.dart`**:

  ```dart
  // Implements: REQ-BOOTSTRAP — entry types registered at bootstrap.
  // Validated by: JNY-01 (demo_note lifecycle), JNY-02 (CQRS via action types).
  final demoNoteType = EntryTypeDefinition(
    id: 'demo_note',
    aggregateType: 'DiaryEntry',
    effectiveDatePath: 'date',
    widgetId: 'demo_note_widget_v1',
    answerSchema: {
      // title: string, body: string, mood: int, date: ISO8601 date-only string
    },
  );

  final redButtonType = EntryTypeDefinition(
    id: 'red_button_pressed',
    aggregateType: 'RedButtonPressed',
    effectiveDatePath: null,  // no answer-derived date; action is point-in-time
    widgetId: 'action_button_v1',
    answerSchema: {},
  );
  // green_button_pressed, blue_button_pressed analogous.

  final allDemoEntryTypes = [
    demoNoteType, redButtonType, greenButtonType, blueButtonType,
  ];
  ```

  Exact field names must match `EntryTypeDefinition`'s actual Dart constructor as shipped in Phase 1/4.3 — adjust casing if the library uses snake_case or camelCase (Dart convention is camelCase; confirm by reading `provenance/lib/src/entry_type_definition.dart` before typing).
- [ ] **Run tests**; expect pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "Demo entry types: demo_note + red/green/blue action events (CUR-1154)".

---

### Task 6: `demo_destination.dart` — DemoDestination class

**TASK_FILE**: `PHASE4.6_TASK_6.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/example/lib/demo_destination.dart`
- Create: `apps/common-dart/append_only_datastore/example/test/demo_destination_test.dart`

**Applicable REQs**: REQ-DEST (Destination interface), REQ-BATCH (canAddToBatch, maxAccumulateTime, transform(List<Event>)), REQ-DYNDEST (allowHardDelete flag).

- [ ] **Baseline**: green from Task 5.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests** (`demo_destination_test.dart`). Use `fakeAsync` from `package:fake_async` if already transitively available via `flutter_test`, otherwise use real `Future.delayed` for latency tests with short durations.

  Test cases:
  - **Connection.ok with latency**: `connection.value = Connection.ok`, `sendLatency.value = Duration(milliseconds: 50)`. Call `send(payload)`. Assert: awaits ~50ms, returns `SendOk`. (REQ-DEST)
  - **Connection.broken returns SendTransient**: connection set to broken. `send()` returns `SendTransient` immediately (no latency). `error` message equals `"simulated disconnect"`. (REQ-DEST + REQ-p01001)
  - **Connection.rejecting returns SendPermanent**: connection set to rejecting. `send()` returns `SendPermanent`. `error` equals `"simulated rejection"`. (REQ-DEST + JNY-03)
  - **canAddToBatch respects batchSize = 1**: `batchSize.value = 1`. `canAddToBatch([event1], event2)` returns `false` (batch is full). (REQ-BATCH)
  - **canAddToBatch respects batchSize = 5**: `batchSize.value = 5`. `canAddToBatch([e1,e2,e3,e4], e5)` returns `true`. `canAddToBatch([e1..e5], e6)` returns `false`.
  - **canAddToBatch always true for empty batch** (implicit — fillBatch always takes at least one; test that calling `canAddToBatch([], event)` returns `true` regardless of batchSize).
  - **maxAccumulateTime reads from notifier**: `maxAccumulateTimeN.value = Duration(seconds: 3)`, then `maxAccumulateTime == Duration(seconds: 3)`.
  - **transform produces JSON payload**: `transform([event1, event2])` returns a `WirePayload` with `contentType == 'application/json'`, `transformVersion == 'demo-v1'`, `bytes` decoding to `{"batch": [{...event1...}, {...event2...}]}`.
  - **allowHardDelete default false**: `DemoDestination(id: 'x').allowHardDelete == false`.
  - **allowHardDelete opt-in**: `DemoDestination(id: 'x', allowHardDelete: true).allowHardDelete == true`.
  - **SubscriptionFilter.any()**: the filter accepts all events regardless of aggregate_type.
  - **wireFormat == 'demo-json-v1'**.

  Each test gets `// Verifies:` with REQ-d topic (substituted in Task 1).
- [ ] **Run tests**; expect failures.
- [ ] **Implement `demo_destination.dart`** per design §7.6. Full class body inline (copy-paste from design, with ValueNotifier wiring made explicit):

  ```dart
  enum Connection { ok, broken, rejecting }

  // Implements: REQ-DEST — Destination interface impl.
  // Implements: REQ-BATCH — canAddToBatch, maxAccumulateTime, transform(List<Event>).
  // Implements: REQ-DYNDEST — allowHardDelete opt-in.
  class DemoDestination implements Destination {
    DemoDestination({
      required this.id,
      this.allowHardDelete = false,
      Duration initialSendLatency = const Duration(seconds: 10),
      int initialBatchSize = 1,
      Duration initialAccumulate = Duration.zero,
      Connection initialConnection = Connection.ok,
    })  : connection = ValueNotifier(initialConnection),
          sendLatency = ValueNotifier(initialSendLatency),
          batchSize = ValueNotifier(initialBatchSize),
          maxAccumulateTimeN = ValueNotifier(initialAccumulate);

    @override final String id;
    @override final bool allowHardDelete;
    @override SubscriptionFilter get filter => SubscriptionFilter.any();
    @override String get wireFormat => 'demo-json-v1';

    final ValueNotifier<Connection> connection;
    final ValueNotifier<Duration>   sendLatency;
    final ValueNotifier<int>        batchSize;
    final ValueNotifier<Duration>   maxAccumulateTimeN;

    @override Duration get maxAccumulateTime => maxAccumulateTimeN.value;

    @override
    bool canAddToBatch(List<Event> currentBatch, Event candidate) =>
        currentBatch.length < batchSize.value;

    @override
    Future<WirePayload> transform(List<Event> batch) async => WirePayload(
          bytes: utf8.encode(jsonEncode({
            'batch': batch.map((e) => e.toJson()).toList(),
          })),
          contentType: 'application/json',
          transformVersion: 'demo-v1',
        );

    @override
    Future<SendResult> send(WirePayload p) async {
      switch (connection.value) {
        case Connection.ok:
          await Future.delayed(sendLatency.value);
          return SendOk();
        case Connection.broken:
          return SendTransient(error: 'simulated disconnect');
        case Connection.rejecting:
          return SendPermanent(error: 'simulated rejection');
      }
    }
  }
  ```

  Exact field and method names must match the Phase-4.3-shipped `Destination` interface — confirm by reading `append_only_datastore/lib/src/destinations/destination.dart` before implementing.
- [ ] **Run tests**; expect pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "DemoDestination with ValueNotifier-bound connection/latency/batch (CUR-1154)".

---

### Task 7: `demo_sync_policy.dart` — demo defaults + notifier

**TASK_FILE**: `PHASE4.6_TASK_7.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/example/lib/demo_sync_policy.dart`
- Create: `apps/common-dart/append_only_datastore/example/test/demo_sync_policy_test.dart`

**Applicable REQs**: REQ-SYNCPOLICY (injectable value object).

- [ ] **Baseline**: green from Task 6.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests** (`demo_sync_policy_test.dart`):
  - `demoDefaultSyncPolicy.initialBackoff == Duration(seconds: 1)`.
  - `demoDefaultSyncPolicy.backoffMultiplier == 1.0`.
  - `demoDefaultSyncPolicy.maxBackoff == Duration(seconds: 10)`.
  - `demoDefaultSyncPolicy.jitterFraction == 0.0`.
  - `demoDefaultSyncPolicy.maxAttempts == 1000000`.
  - `demoPolicyNotifier` is a `ValueNotifier<SyncPolicy>` initialized to `demoDefaultSyncPolicy`.
  - Mutating `demoPolicyNotifier.value = newPolicy` notifies listeners.
  - Each test references design §7.7 and the Phase-4.3 REQ-SYNCPOLICY assertion (substituted in Task 1).
- [ ] **Run tests**; expect failures.
- [ ] **Implement `demo_sync_policy.dart`**:

  ```dart
  // Implements: REQ-SYNCPOLICY — SyncPolicy is a value object; demo defaults
  //   per design §7.7 (short backoff so retry behavior is observable live).
  const demoDefaultSyncPolicy = SyncPolicy(
    initialBackoff: Duration(seconds: 1),
    backoffMultiplier: 1.0,
    maxBackoff: Duration(seconds: 10),
    jitterFraction: 0.0,
    maxAttempts: 1000000,
  );

  final demoPolicyNotifier = ValueNotifier<SyncPolicy>(demoDefaultSyncPolicy);
  ```

  Confirm field names match the Phase-4.3 `SyncPolicy` const constructor.
- [ ] **Run tests**; expect pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "DemoSyncPolicy defaults + ValueNotifier (CUR-1154)".

---

### Task 8: `app_state.dart` — ChangeNotifier with selection + destination registry

**TASK_FILE**: `PHASE4.6_TASK_8.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/example/lib/app_state.dart`
- Create: `apps/common-dart/append_only_datastore/example/test/app_state_test.dart`

**Applicable REQs**: none directly — pure UI state. Tests exercise the plumbing that the subsequent widget tasks rely on.

- [ ] **Baseline**: green from Task 7.
- [ ] **Create TASK_FILE**.
- [ ] **Write failing tests** (`app_state_test.dart`) covering:
  - **Selection state**: `AppState` has `selectedAggregateId`, `selectedEventId`, `selectedFifoRowId` (all nullable strings). Setters notify listeners. Setting any one clears the others (selections are mutually exclusive across panels per design §7.3 "cross-panel selection blue-tint").
  - **Destination registry binding**: `AppState.destinations` exposes the current list of `DemoDestination` pulled from the `DestinationRegistry`. `addDestination(DemoDestination)` calls the registry's method and notifies.
  - **Policy notifier exposure**: `AppState.policyNotifier` returns the global `demoPolicyNotifier`.
  - **Connection-state subscriptions**: providing a destination lets the UI listen to its `connection`, `sendLatency`, `batchSize`, `maxAccumulateTimeN` notifiers via `AppState.destinationAt(index)`.
  - **clearSelection()** resets all three selection fields and notifies once.
  - Each test `// Verifies:` cites "app_state selection plumbing (no REQ; UI-local)".

  Build the tests against a minimal fake `DestinationRegistry` stub (register the registry type from `append_only_datastore` and pass a test double). NO widget tests.
- [ ] **Run tests**; expect failures.
- [ ] **Implement `app_state.dart`**:

  ```dart
  class AppState extends ChangeNotifier {
    AppState({required this.registry, required this.policyNotifier});

    final DestinationRegistry registry;
    final ValueNotifier<SyncPolicy> policyNotifier;

    String? _selectedAggregateId;
    String? _selectedEventId;
    String? _selectedFifoRowId;

    String? get selectedAggregateId => _selectedAggregateId;
    String? get selectedEventId => _selectedEventId;
    String? get selectedFifoRowId => _selectedFifoRowId;

    void selectAggregate(String? id) {
      _selectedAggregateId = id;
      _selectedEventId = null;
      _selectedFifoRowId = null;
      notifyListeners();
    }
    // parallel setters for event and fifo row.

    void clearSelection() {
      _selectedAggregateId = null;
      _selectedEventId = null;
      _selectedFifoRowId = null;
      notifyListeners();
    }

    List<DemoDestination> get destinations =>
        registry.all.whereType<DemoDestination>().toList();

    void addDestination(DemoDestination d) {
      registry.addDestination(d);
      notifyListeners();
    }
  }
  ```

  Exact `DestinationRegistry.all` / `.addDestination` method names must match Phase 4.3 surface; adjust if needed.
- [ ] **Run tests**; expect pass.
- [ ] **Lint**: clean.
- [ ] **Commit**: "AppState: selection + destination registry binding (CUR-1154)".

---

### Task 9: `main.dart` + `app.dart` — bootstrap and root widget

**TASK_FILE**: `PHASE4.6_TASK_9.md`

**Files:**
- Rewrite: `apps/common-dart/append_only_datastore/example/lib/main.dart`
- Create: `apps/common-dart/append_only_datastore/example/lib/app.dart`

**Test skip rationale**: `main.dart` is a boot-sequence driver; `app.dart` is a widget tree. Non-goal §4.2 excludes widget tests. Smoke-tested via `flutter run` in Task 14.

**Applicable REQs**: REQ-BOOTSTRAP (bootstrap sequence), REQ-SYNCCYCLE (1-second Timer.periodic).

- [ ] **Baseline**: green from Task 8.
- [ ] **Create TASK_FILE**.
- [ ] **Implement `main.dart`**:

  ```dart
  // Implements: REQ-BOOTSTRAP — single init point; registers entry types,
  //   then destinations. Implements: REQ-SYNCCYCLE — 1-second timer tick.
  Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();
    final appSupportDir = await getApplicationSupportDirectory();
    final demoDir = Directory(p.join(appSupportDir.path, 'append_only_datastore_demo'));
    await demoDir.create(recursive: true);
    final dbPath = p.join(demoDir.path, 'demo.db');
    stdout.writeln('[demo] storage: $dbPath');

    final backend = SembastBackend(
      factory: databaseFactoryIo,
      path: dbPath,
    );

    final primary = DemoDestination(id: 'Primary', allowHardDelete: false);
    final secondary = DemoDestination(id: 'Secondary', allowHardDelete: true);

    final datastore = await bootstrapAppendOnlyDatastore(
      backend: backend,
      entryTypes: allDemoEntryTypes,
      destinations: [primary, secondary],
    );

    final appState = AppState(
      registry: datastore.destinationRegistry,
      policyNotifier: demoPolicyNotifier,
    );

    // Set both destinations active from boot (setStartDate = now so any new
    // events flow immediately; JNY-07 tests past-startDate replay on a
    // separately-added destination).
    final now = DateTime.now();
    datastore.destinationRegistry.setStartDate('Primary', now);
    datastore.destinationRegistry.setStartDate('Secondary', now);

    Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        await syncCycle(datastore, policy: demoPolicyNotifier.value);
      } catch (e, s) {
        stderr.writeln('[demo] syncCycle error: $e\n$s');
      }
    });

    runApp(DemoApp(datastore: datastore, appState: appState));
  }
  ```

  - Path logging at boot per design §7.8.
  - `path_provider` already a dep of parent package; transitively available.
  - If `bootstrapAppendOnlyDatastore` exposes a different shape (e.g., returns a record or a `DatastoreHandle` object), follow the actual Phase-4.3 API; the shape above is a best-effort template.
- [ ] **Implement `app.dart`** — root `DemoApp` widget:
  - `MaterialApp` with `theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: DemoColors.bg)`.
  - Scaffold body: a `Column` with `[TopActionBar, SyncPolicyBar, Expanded(ObservationGrid), DetailPanel]` — placeholder widgets for now, real implementations land in Tasks 10-13.
  - Provide `appState` and `datastore` via constructor; child widgets read via `Provider.of` OR plain constructor pass-through. Pick constructor pass-through to avoid adding `provider` as a dep (keep dep count minimal per Task 3 rule).
- [ ] **Implement `[Reset all]` sequence** as a method on `DemoApp`:
  ```dart
  Future<void> resetAll() async {
    timer.cancel();
    await datastore.backend.close();
    await File(dbPath).delete().catchError((_) {});
    // then re-run bootstrap; replace datastore + appState in state.
  }
  ```
  Wire the actual button in Task 12; the plumbing lives here in Task 9 so it's ready when the button widget is built. Storing `dbPath` in a top-level `late final String _dbPath` is acceptable.
- [ ] **Flutter pub get** and **flutter analyze**: clean.
- [ ] **Commit**: "Demo main.dart + app.dart bootstrap (CUR-1154)".

---

### Task 10: Read-only observation panels — materialized + event stream

**TASK_FILE**: `PHASE4.6_TASK_10.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/example/lib/widgets/materialized_panel.dart`
- Create: `apps/common-dart/append_only_datastore/example/lib/widgets/event_stream_panel.dart`

**Test skip rationale**: Pure read-only list widgets. Non-goal §4.2 excludes widget tests. Correctness verified visually in Task 15 (JNY-01, JNY-02, JNY-06 all exercise these panels).

**Applicable REQs**: REQ-p00013 (materialized view is a projection; JNY-06 validates rebuild idempotence), REQ-p00004 (event log is source of truth; JNY-01 validates event order + hash chain).

- [ ] **Baseline**: green from Task 9.
- [ ] **Create TASK_FILE**.
- [ ] **Implement `materialized_panel.dart`**:
  - Stateful widget. Holds a `Timer.periodic(Duration(milliseconds: 500))` that calls `datastore.backend.findEntries(entryType: 'demo_note')` and stores the list in state.
  - Listens to `appState` for selection highlighting.
  - Header row: "MATERIALIZED" in `DemoText.header`.
  - Rows: `agg-<short> [ok|ptl|del]` per design §7.5. Tinted blue when `app_state.selectedAggregateId` matches.
  - Tap a row → `appState.selectAggregate(row.entryId)`.
  - Header annotation: `// Validated by: JNY-01 materialized lifecycle; JNY-06 rebuild idempotence.`
- [ ] **Implement `event_stream_panel.dart`**:
  - Stateful widget. `Timer.periodic(500ms)` calls `datastore.backend.findAllEvents(limit: 500)` and stores the list in state.
  - Shows every event regardless of `aggregate_type` (JNY-02 requires action events to be visible here).
  - Row format per design §7.5: `#<seq> <short_event_type> <aggregate_type> <short_aggregate_id>`.
  - Tap → `appState.selectEvent(row.eventId)`.
  - Header annotation: `// Validated by: JNY-01 event order; JNY-02 CQRS (aggregate_type variety).`
- [ ] **Register both panels** in `app.dart`'s placeholder column slots (replace placeholders).
- [ ] **Lint**: clean.
- [ ] **Commit**: "Materialized + event stream read panels (CUR-1154)".

---

### Task 11: `fifo_panel.dart` — per-destination column with header stack + ops drawer

**TASK_FILE**: `PHASE4.6_TASK_11.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/example/lib/widgets/fifo_panel.dart`

**Test skip rationale**: Widget-heavy (schedule editors, sliders, collapsible drawer). Non-goal §4.2 excludes widget tests. Correctness verified visually across JNY-03, JNY-04, JNY-07, JNY-08, JNY-09.

**Applicable REQs**: REQ-FIFO (row rendering with pending/draining/retrying/exhausted/sent states), REQ-DYNDEST (schedule state + end-date editor), REQ-BATCH (batchSize + maxAccumulateTime sliders), REQ-UNJAM (Unjam button), REQ-REHAB (Rehabilitate all button, per-row rehabilitate), REQ-DEST (connection dropdown + allowHardDelete gate on Delete button).

- [ ] **Baseline**: green from Task 10.
- [ ] **Create TASK_FILE**.
- [ ] **Implement `fifo_panel.dart`** as a Stateful widget with constructor params `(DemoDestination destination, Datastore datastore, AppState appState)`. Structure:

  **Column header stack** (top-down):
  1. **Column title**: `destination.id.toUpperCase()` in `DemoText.header` yellow.
  2. **Schedule state label**: derived from `datastore.destinationRegistry.scheduleStateOf(destination.id)`. One of: `DORMANT` / `SCHEDULED until HH:MM:SS` / `ACTIVE` / `CLOSED` / `CLOSED @ (Nm ago)`. Rendered in `DemoColors.accent`.
  3. **Start-date editor** (visible ONLY while state is `DORMANT` or `SCHEDULED`): a text field + Confirm button. On confirm → `registry.setStartDate(id, parsedDate)`. Field disappears once startDate is set.
  4. **End-date editor** (always visible): text field + Confirm button + [Clear] button. On confirm → `registry.setEndDate(id, parsedDate)`. Surfaces the `SetEndDateResult` (closed / scheduled / applied) as a transient info banner for 2 seconds.
  5. **Connection dropdown**: 3 options bound to `destination.connection` ValueNotifier.
  6. **sendLatency slider**: 0s - 30s, bound to `destination.sendLatency`.
  7. **sendBatchSize slider**: 1 - 50, bound to `destination.batchSize`.
  8. **maxAccumulateTime slider**: 0s - 30s, bound to `destination.maxAccumulateTimeN`.
  9. **Ops drawer** (collapsible; collapsed by default):
     - `[Unjam]` button — calls `await registry.unjamDestination(destination.id)`; shows `UnjamResult` (deletedPending, rewoundTo) in an info banner. Disabled if destination is not deactivated (library throws on active — guard client-side too).
     - `[Rehabilitate all exhausted]` button — calls `await registry.rehabilitateAllExhausted(destination.id)`; shows count in banner.
     - `[Delete destination]` button — visible ONLY if `destination.allowHardDelete == true`. Calls `registry.deleteDestination(id)`; the column disappears from the grid on the next rebuild.

  **FIFO row list** (scrolling):
  - `Timer.periodic(500ms)` calls `datastore.backend.listFifo(destination.id, limit: 500)` (or equivalent Phase-4.3 API — confirm actual name) and stores in state.
  - Renders per design §7.5:
    - `[pend]  #<seq>   events: <count>` (white)
    - `> #<seq>    DRAINING  events: <count>` (yellow, with `>` prefix; this row is currently the drain head AND being processed)
    - `> #<seq>    RETRYING  events: <count>` (red, retrying head)
    - `[exh]   #<seq>   events: <count>` (magenta, inert)
    - `[SENT]  #<seq>   events: <count>` (green)
  - The `>` marker logic: the first `pending` row in sequence order IS the drain head. If its latest attempt is within `initialBackoff` window and attempts.length > 0, render as RETRYING; else DRAINING once a send is in flight; else `[pend]` if no attempts yet. (Demo approximation — actual drain state isn't surfaced by library; deriving from attempts[] is adequate.)
  - **Tap a row** → `appState.selectFifoRow(entryId)`. A per-row Rehabilitate button appears inline for exhausted rows.

  All controls and buttons use `DemoColors` and `DemoText`. Borders from `demoBorder`.

- [ ] **Wire into `app.dart`**: the observation grid iterates `appState.destinations` and renders one `FifoPanel` per destination. Column layout uses `Expanded` children so columns resize to fit.
- [ ] **Lint**: clean.
- [ ] **Commit**: "FIFO panel with header stack, sliders, ops drawer (CUR-1154)".

---

### Task 12: `top_action_bar.dart` + `sync_policy_bar.dart`

**TASK_FILE**: `PHASE4.6_TASK_12.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/example/lib/widgets/top_action_bar.dart`
- Create: `apps/common-dart/append_only_datastore/example/lib/widgets/sync_policy_bar.dart`

**Test skip rationale**: Widget-heavy, button-wired to services. Non-goal §4.2 excludes widget tests. Correctness verified visually in every journey (the top bar is the primary input surface).

**Applicable REQs**: REQ-ENTRY (EntryService.record called from lifecycle buttons), REQ-DYNDEST (Add destination button), REQ-p00013 (Rebuild view button), REQ-SYNCPOLICY (policy sliders mutate the notifier).

- [ ] **Baseline**: green from Task 11.
- [ ] **Create TASK_FILE**.
- [ ] **Implement `top_action_bar.dart`** — two rows:

  **Row 1 — demo_note lifecycle:**
  - Label: "demo_note".
  - Text fields for `title`, `body`, `mood` (numeric).
  - `[Start]` button: calls `entryService.record(entryType: 'demo_note', aggregateId: uuid(), eventType: 'checkpoint', answers: {...})`. Selects the new aggregate.
  - `[Complete]` button: calls `entryService.record(... eventType: 'finalized', aggregateId: appState.selectedAggregateId, ...)`. Disabled when no aggregate is selected.
  - `[Edit selected]` button: loads current answers from the materialized row into the fields; `[Complete]` then records a new finalized event with a `change_reason`.
  - `[Delete selected]` button: calls `entryService.record(... eventType: 'tombstone' ...)`.

  **Row 2 — actions and system:**
  - Label: "actions".
  - `[RED]`, `[GREEN]`, `[BLUE]` buttons: each calls `entryService.record(entryType: '<color>_button_pressed', aggregateId: uuid(), eventType: 'finalized', answers: {'pressed_at': DateTime.now().toIso8601String()})`. New aggregate every press (per JNY-02 spec).
  - Spacer.
  - Label: "system".
  - `[Add destination]` button: opens `AddDestinationDialog` (Task 13).
  - `[Rebuild view]` button: calls `await rebuildMaterializedView(datastore.backend, datastore.entryTypeLookup)`. Shows count in banner for 2s.
  - `[Reset all]` button: calls `DemoApp.resetAll()` (from Task 9). Confirms via modal first.

  Button colors for RED/GREEN/BLUE come from `DemoColors.red/green/blue` (action-button subset). Other buttons use white fg on black bg with `demoBorder`.

- [ ] **Implement `sync_policy_bar.dart`** — five horizontal sliders:
  - `initialBackoff` (0s - 30s)
  - `backoffMultiplier` (1.0 - 5.0)
  - `maxBackoff` (1s - 120s)
  - `jitterFraction` (0.0 - 1.0)
  - `maxAttempts` (1 - 1,000,000, log-scaled)
  - Each slider has a label showing current value. On change → construct a new `SyncPolicy` value object and set `demoPolicyNotifier.value = newPolicy`.
- [ ] **Wire both into `app.dart`** replacing their Task-9 placeholders.
- [ ] **Lint**: clean.
- [ ] **Commit**: "Top action bar + sync policy bar (CUR-1154)".

---

### Task 13: `add_destination_dialog.dart` + `detail_panel.dart`

**TASK_FILE**: `PHASE4.6_TASK_13.md`

**Files:**
- Create: `apps/common-dart/append_only_datastore/example/lib/widgets/add_destination_dialog.dart`
- Create: `apps/common-dart/append_only_datastore/example/lib/widgets/detail_panel.dart`

**Test skip rationale**: Widget-heavy modal + detail renderer. Non-goal §4.2 excludes widget tests. Correctness verified in JNY-07 (Add destination with past startDate) and all journeys that exercise the detail panel (01, 03, 04, 05, 09).

**Applicable REQs**: REQ-DYNDEST (runtime add), REQ-REPLAY (optional initial startDate triggers replay).

- [ ] **Baseline**: green from Task 12.
- [ ] **Create TASK_FILE**.
- [ ] **Implement `add_destination_dialog.dart`**:
  - Modal dialog with fields:
    - `id` (text input, required; rejected if collides with existing destination).
    - `allowHardDelete` (checkbox).
    - `initialStartDate` (date+time input, optional; blank = leave dormant).
  - `[Cancel]` / `[Add]` buttons.
  - On `[Add]`:
    ```dart
    final d = DemoDestination(id: idField.value, allowHardDelete: hardDeleteField.value);
    appState.addDestination(d);
    if (startField.value != null) {
      registry.setStartDate(d.id, startField.value!);
    }
    Navigator.pop(context);
    ```
  - Validation: empty id → inline error; id collision handled by catching the registry's throw.
- [ ] **Implement `detail_panel.dart`**:
  - Rightmost column; width ~25% of grid.
  - Header: "DETAIL" in `DemoText.header` yellow.
  - Body content depends on `appState` selection:
    - `selectedAggregateId != null` → render the materialized row (entry_id, entry_type, current_answers as pretty JSON, is_complete, is_deleted, updated_at).
    - `selectedEventId != null` → render the event (event_id, sequence_number, aggregate_id, aggregate_type, entry_type, event_type, client_timestamp, event_hash, previous_event_hash, data).
    - `selectedFifoRowId != null` → render the FIFO row (entry_id, sequence_in_queue, event_ids list, wire_format, transform_version, enqueued_at, attempts[] full list, final_status, sent_at).
    - None selected → render "no selection" + a live summary: `anyFifoExhausted()` boolean, total events, total aggregates, current `SyncPolicy` values.
- [ ] **Wire the dialog** to the [Add destination] button in `top_action_bar.dart` (from Task 12).
- [ ] **Wire the detail panel** into `app.dart` as the rightmost grid column.
- [ ] **Lint**: clean.
- [ ] **Commit**: "Add-destination dialog + detail panel (CUR-1154)".

---

### Task 14: `flutter run` smoke test

**TASK_FILE**: `PHASE4.6_TASK_14.md`

**No code changes — validation only.**

- [ ] **Baseline**: green from Task 13.
- [ ] **Create TASK_FILE**.
- [ ] **Run**: `(cd apps/common-dart/append_only_datastore/example && flutter run -d linux)`.
- [ ] **Confirm app boots** without a runtime error. Capture stdout — the storage path log line should appear: `[demo] storage: /home/<user>/.local/share/append_only_datastore_demo/demo.db` (or similar; exact resolved path).
- [ ] **Click-once sanity**:
  - Type a title into demo_note and click [Start]. Confirm a new aggregate row appears in MATERIALIZED and a checkpoint event appears in EVENTS.
  - Click [Complete] on the selected aggregate. Confirm a finalized event appears.
  - Click [RED] once. Confirm an event appears in EVENTS with `aggregate_type = RedButtonPressed` but NOT in MATERIALIZED.
  - Click a row in EVENTS. Confirm the DETAIL panel populates.
  - Flip Primary's connection dropdown to `broken` and back to `ok`.
  - Drag the `initialBackoff` slider. Confirm the numeric label updates.
  - Click [Add destination], fill id = "test", submit. Confirm a new column appears.
  - Click [Rebuild view]. Confirm the MATERIALIZED column briefly empties then repopulates.
  - Click [Reset all] (with confirm). Confirm all panels empty.
- [ ] **Record any runtime exceptions** in stderr. If any, diagnose root cause (per CLAUDE.md rule #6) — do not suppress. Fix and re-smoke before proceeding to Task 15.
- [ ] **Commit any bugfixes** from smoke as individual commits (intra-phase granular commits).

---

### Task 15: Acceptance — walk all nine USER_JOURNEYS

**TASK_FILE**: `PHASE4.6_TASK_15.md`

**No code changes during walking. Any bug found becomes a blocker; fix it as a dedicated sub-task and re-walk from that journey.**

This is the single sign-off gate for Phase 4.6. Reviewers (and the implementer self-checking before squash) run the journeys in order against a fresh `flutter run` session.

- [ ] **Baseline**: green from Task 14. `flutter run -d linux` launches cleanly.
- [ ] **Create TASK_FILE** with a 9-item checklist, one per journey.
- [ ] **Read `apps/common-dart/append_only_datastore/example/USER_JOURNEYS.md` front-to-back** before starting. Re-read each journey's *Expected Outcome* immediately before following its *Steps*.
- [ ] **JNY-01 — Exercising the full demo_note lifecycle**
  - Follow Steps 1-6 exactly.
  - Confirm Expected Outcome: 4 events in order (checkpoint, finalized, finalized, tombstone); materialized row progresses `[ptl] → [ok] → [ok] → [del]`; both FIFOs drain each event (pending → sent) independently; hash-chain linkage visible in DETAIL.
  - Check box or log blocker.
- [ ] **JNY-02 — Confirming the CQRS invariant**
  - Follow Steps 1-5.
  - Confirm: 6 new events with RGB aggregate_types; materialized view row count unchanged; FIFOs drain the 6 action events; DETAIL shows `aggregate_type != DiaryEntry` for any action event.
  - Check box or log blocker.
- [ ] **JNY-03 — Per-destination isolation under rejection storm**
  - Follow Steps 1-4 with `batchSize = 1` on both destinations.
  - Confirm: Secondary accumulates 3 magenta `[exh]` rows; Primary drains 3 green `[SENT]`; `anyFifoExhausted()` surfaces true in DETAIL (no selection); subsequent events keep flowing — no wedge.
  - Check box or log blocker.
- [ ] **JNY-04 — Transient disconnect and recovery**
  - Follow Steps 1-5 with default policy.
  - Confirm: Primary head shows RETRYING with growing attempts[] during broken window; no exhaustion; Secondary unaffected; on reconnect, events drain in order.
  - Check box or log blocker.
- [ ] **JNY-05 — Tuning sync policy via sliders**
  - Follow Steps 1-7.
  - Confirm: attempt spacing matches 2x-growth-capped-at-maxBackoff curve; after maxAttempts=3, the second event exhausts after exactly 3 attempts.
  - Check box or log blocker.
- [ ] **JNY-06 — Rebuilding the materialized view**
  - Follow Steps 1-4.
  - Confirm: MATERIALIZED empties then refills byte-identical; EVENTS, Primary FIFO, Secondary FIFO unchanged.
  - Check box or log blocker.
- [ ] **JNY-07 — Add destination with past startDate triggers historical replay**
  - Follow Steps 1-4 (past startDate = 30 days ago).
  - Confirm: new BACKUP column, initially DORMANT then ACTIVE; burst of ceil(N/5) pending rows appear in a single transaction; first row's event_ids covers #1-#5 etc; other columns unchanged.
  - Check box or log blocker.
- [ ] **JNY-08 — setEndDate closed vs scheduled return semantics**
  - Follow Steps 1-7.
  - Confirm: step 1 returns `scheduled`; step 2 returns `closed`; step 3-4 events enqueue to Primary only (Secondary's window is closed); step 5-7 Red event enqueues to neither (both closed) but appears in EVENTS.
  - Check box or log blocker.
- [ ] **JNY-09 — Unjam + rehabilitate**
  - Follow Steps 1-8. Note this journey needs a "transform_version toggle" in Secondary's ops drawer — if not already exposed by Task 11, add it as a dev-only button ("Bump transform_version to demo-v2") in a small follow-up commit. This is a journey-specific affordance called out in the journey's Step 4.
  - Confirm: UnjamResult has `deletedPending = M` and `rewoundTo = <last sent seq>`; exhausted rows preserved; new `demo-v2` pending rows appear covering the re-batched events; after rehabilitate, the chosen exhausted row flips to pending with attempts[] appended (not rewritten).
  - Check box or log blocker.
- [ ] **If any journey logged a blocker**: fix root cause (per CLAUDE.md rule #6), commit the fix, return to the blocked journey and re-walk from Step 1. Repeat until all nine journeys are clean.
- [ ] **Final state of TASK_FILE**: all nine boxes checked, zero open blockers.
- [ ] **Commit** (if any fixes during journey walks): granular commits per bug. If no fixes needed, no commit from this task — just the TASK_FILE.

---

### Task 16: Phase-boundary squash and request phase review

**TASK_FILE**: `PHASE4.6_TASK_16.md`

- [ ] **Rebase onto main** in case main moved: `git fetch origin main && git rebase origin/main`. Conflicts extremely unlikely (everything is under `example/`, which main does not touch).
- [ ] **Full verification across all touched packages**:
  - `(cd apps/common-dart/append_only_datastore && flutter test && flutter analyze)` — green (library unchanged by this phase)
  - `(cd apps/common-dart/append_only_datastore/example && flutter test && flutter analyze)` — green (demo unit tests + lint clean)
  - `(cd apps/daily-diary/clinical_diary && flutter test && flutter analyze)` — green (unaffected by this phase; sanity only)
- [ ] **Final `flutter run -d linux` smoke** — confirm the app still launches cleanly after any Task-15 fixes. If not, fix before squashing.
- [ ] **Interactive rebase to squash Phase 4.6 commits**: `git rebase -i origin/main` — leave Phase 1-4.3 squashed commits as `pick`, squash every Task-2 through Task-15 commit into one with message:

  ```
  [CUR-1154] Phase 4.6: Demo app

  - example/: Flutter Linux-desktop sandbox for append_only_datastore
  - Bootstraps via bootstrapAppendOnlyDatastore; 1-second Timer.periodic
    drives syncCycle with live SyncPolicy from sliders
  - DemoDestination with live-mutable connection/latency/batchSize/
    accumulateTime; two boot destinations (Primary FDA, Secondary utility)
  - UI: top action bar, sync policy bar, materialized + event stream +
    per-destination FIFO panels, add-destination dialog, detail panel
  - Unit tests on styles palette, demo types, demo destination, demo
    sync policy, app state selection plumbing
  - Acceptance: nine USER_JOURNEYS walked and signed off

  No widget tests, no integration tests, no CI — per design §4.2
  non-goals. Demo is a developer review tool; acceptance is visual.
  ```

- [ ] **Force-push with lease**: `git push --force-with-lease`.
- [ ] **Comment on PR**: "Phase 4.6 ready for review — commit `<sha>`. Range from Phase 4.3 end: `<phase4.3_sha>..<sha>`. Review focus: the nine USER_JOURNEYS walk (Task 15 TASK_FILE), the DemoDestination/DemoSyncPolicy shapes, and the collapsible ops drawer in fifo_panel.dart. Demo is unwired from production; zero behavior change to `clinical_diary`."
- [ ] **Wait for phase review**. Address feedback via fixup commits + in-place rebase.
- [ ] **Record phase-completion SHA** in TASK_FILE before starting Phase 5.

---

## Recovery

After `/clear` or context compaction:

1. Read this file.
2. Read [README.md](README.md) for conventions (TDD cadence, REQ citation, squash procedure).
3. Read design doc §7 (`docs/superpowers/2026-04-22-dynamic-destinations-and-demo-design.md`) for demo shape.
4. Read `apps/common-dart/append_only_datastore/example/USER_JOURNEYS.md` before Task 15.
5. Find the first unchecked box above.
6. Read the matching `PHASE4.6_TASK_N.md` in `task_files/`.

Archive procedure is whole-ticket (after rebase-merge) — see [README.md](README.md) Archive section.
