// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-CAL-p00001: Old Entry Modification Justification
//   REQ-CAL-p00002: Short Duration Nosebleed Confirmation
//   REQ-CAL-p00003: Long Duration Nosebleed Confirmation
//   REQ-p01066-A+B+H+K: Nosebleed start/end time validation
//   REQ-p01069-A+E: Time picker / edit support
//
// Phase 12.5 (CUR-1169): Screen-level coverage for the multi-page
// RecordingScreen. Drives the screen with a recording-EntryService double
// that captures record() calls so tests can assert on the API contract
// without bringing up the full Sembast write path.

import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/widgets/intensity_picker.dart';
import 'package:clinical_diary/widgets/nosebleed_intensity.dart';
import 'package:clinical_diary/widgets/time_picker_dial.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/diary_entry_factory.dart';
import '../helpers/mock_enrollment_service.dart';
import '../helpers/test_helpers.dart';

EntryTypeDefinition _epistaxisDef() => const EntryTypeDefinition(
  id: 'epistaxis_event',
  registeredVersion: 1,
  name: 'Nosebleed',
  widgetId: 'epistaxis_form_v1',
  widgetConfig: <String, Object?>{},
  effectiveDatePath: 'startTime',
);

class _RecordedCall {
  _RecordedCall({
    required this.entryType,
    required this.aggregateId,
    required this.eventType,
    required this.answers,
    required this.changeReason,
  });
  final String entryType;
  final String aggregateId;
  final String eventType;
  final Map<String, Object?> answers;
  final String? changeReason;
}

class _CapturingEntryService extends EntryService {
  _CapturingEntryService._({
    required super.backend,
    required super.entryTypes,
    required super.deviceInfo,
  }) : super(syncCycleTrigger: _noop);

  static Future<void> _noop() async {}

  static Future<_CapturingEntryService> create() async {
    final db = await newDatabaseFactoryMemory().openDatabase(
      'recording-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final backend = SembastBackend(database: db);
    final registry = EntryTypeRegistry()..register(_epistaxisDef());
    return _CapturingEntryService._(
      backend: backend,
      entryTypes: registry,
      deviceInfo: const DeviceInfo(
        deviceId: 'device-test',
        softwareVersion: 'clinical_diary@0.0.0',
        userId: 'user-test',
      ),
    );
  }

  final List<_RecordedCall> calls = [];

  @override
  Future<StoredEvent?> record({
    required String entryType,
    required String aggregateId,
    required String eventType,
    required Map<String, Object?> answers,
    String? checkpointReason,
    String? changeReason,
  }) async {
    calls.add(
      _RecordedCall(
        entryType: entryType,
        aggregateId: aggregateId,
        eventType: eventType,
        answers: Map<String, Object?>.from(answers),
        changeReason: changeReason,
      ),
    );
    return null;
  }

  Future<void> dispose() => (backend as SembastBackend).close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecordingScreen', () {
    late _CapturingEntryService entryService;
    late MockEnrollmentService enrollment;
    late PreferencesService preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = PreferencesService();
      enrollment = MockEnrollmentService();
      entryService = await _CapturingEntryService.create();
      // Reset feature flags to known defaults.
      FeatureFlagService.instance.useReviewScreen = false;
      FeatureFlagService.instance.requireOldEntryJustification = false;
      FeatureFlagService.instance.enableShortDurationConfirmation = false;
      FeatureFlagService.instance.enableLongDurationConfirmation = false;
    });

    tearDown(() async {
      FeatureFlagService.instance.useReviewScreen = false;
      FeatureFlagService.instance.requireOldEntryJustification = false;
      FeatureFlagService.instance.enableShortDurationConfirmation = false;
      FeatureFlagService.instance.enableLongDurationConfirmation = false;
      await entryService.dispose();
    });

    Future<void> pumpScreen(
      WidgetTester tester, {
      DateTime? diaryEntryDate,
      DiaryEntry? existingEntry,
      List<DiaryEntry> allEntries = const [],
      Future<void> Function(String)? onDelete,
    }) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        wrapWithMaterialApp(
          RecordingScreen(
            entryService: entryService,
            enrollmentService: enrollment,
            preferencesService: preferences,
            diaryEntryDate: diaryEntryDate,
            existingEntry: existingEntry,
            allEntries: allEntries,
            onDelete: onDelete,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'initial render shows start time picker, summary bar, and date header',
      (tester) async {
        await pumpScreen(tester);

        expect(find.byType(TimePickerDial), findsOneWidget);
        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Max Intensity'), findsOneWidget);
        expect(find.text('End'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the Set Start Time confirm advances to the intensity step',
      (tester) async {
        await pumpScreen(tester);

        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        expect(find.byType(IntensityPicker), findsOneWidget);
      },
    );

    testWidgets(
      'completing all three steps records a finalized epistaxis_event '
      'with startTime, intensity, and endTime in answers',
      (tester) async {
        await pumpScreen(tester);

        // Step 1: confirm start time → moves to intensity.
        await tester.tap(find.text('Set Start Time'));
        await tester.pumpAndSettle();

        // Step 2: pick an intensity (Dripping). The IntensityPicker exposes
        // each intensity as a tappable card with its localized label.
        await tester.tap(
          find.descendant(
            of: find.byType(IntensityPicker),
            matching: find.text('Dripping'),
          ),
        );
        await tester.pumpAndSettle();

        // Step 3: confirm end time. With useReviewScreen=false, this saves
        // immediately.
        await tester.tap(find.text('Set End Time'));
        await tester.pump();

        expect(entryService.calls, hasLength(1));
        final call = entryService.calls.single;
        expect(call.entryType, 'epistaxis_event');
        expect(call.eventType, 'finalized');
        expect(call.answers['startTime'], isNotNull);
        expect(call.answers['endTime'], isNotNull);
        expect(call.answers['intensity'], 'dripping');
      },
    );

    testWidgets(
      'editing existing entry on the review screen records with the same '
      'aggregateId and a non-null changeReason',
      (tester) async {
        final start = DateTime.now().subtract(const Duration(hours: 2));
        final end = DateTime.now().subtract(const Duration(hours: 1));
        final existing = buildEpistaxisEntry(
          entryId: 'agg-edit-1',
          startTime: start,
          endTime: end,
          intensity: NosebleedIntensity.dripping,
        );

        FeatureFlagService.instance.useReviewScreen = true;
        await pumpScreen(
          tester,
          existingEntry: existing,
          onDelete: (_) async {},
        );

        // The complete step renders a "Save Changes" FilledButton.
        final saveButton = find.widgetWithText(FilledButton, 'Save Changes');
        expect(saveButton, findsOneWidget);
        await tester.tap(saveButton, warnIfMissed: false);
        await tester.pump();

        expect(entryService.calls, hasLength(1));
        final call = entryService.calls.single;
        expect(call.aggregateId, 'agg-edit-1');
        expect(call.changeReason, isNotNull);
        expect(call.changeReason, isNot('initial'));
      },
    );

    testWidgets(
      'delete from edit mode invokes onDelete with a non-empty reason',
      (tester) async {
        final start = DateTime.now().subtract(const Duration(hours: 2));
        final end = DateTime.now().subtract(const Duration(hours: 1));
        final existing = buildEpistaxisEntry(
          entryId: 'agg-del-1',
          startTime: start,
          endTime: end,
          intensity: NosebleedIntensity.spotting,
        );

        String? capturedReason;
        await pumpScreen(
          tester,
          existingEntry: existing,
          onDelete: (reason) async {
            capturedReason = reason;
          },
        );

        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Entered by mistake'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pump();

        expect(capturedReason, 'Entered by mistake');
      },
    );

    testWidgets(
      'editing entry that is missing intensity opens the intensity step '
      'instead of the start step',
      (tester) async {
        final start = DateTime.now().subtract(const Duration(hours: 1));
        final existing = DiaryEntry(
          entryId: 'agg-incomplete-1',
          entryType: 'epistaxis_event',
          effectiveDate: start,
          currentAnswers: <String, Object?>{
            'startTime': start.toUtc().toIso8601String(),
          },
          isComplete: false,
          isDeleted: false,
          latestEventId: 'evt-incomplete-1',
          updatedAt: start,
        );

        await pumpScreen(
          tester,
          existingEntry: existing,
          onDelete: (_) async {},
        );

        // Initial step for an entry missing intensity is the intensity step.
        expect(find.byType(IntensityPicker), findsOneWidget);
      },
    );

    testWidgets(
      'overlap warning appears when editing an entry that overlaps another',
      (tester) async {
        // Two complete entries with overlapping time windows. The screen
        // detects overlap on render via _getOverlappingEvents().
        final base = DateTime.now();
        final today1pm = DateTime(base.year, base.month, base.day, 13);
        final today2pm = DateTime(base.year, base.month, base.day, 14);
        final overlapEntry = buildEpistaxisEntry(
          entryId: 'agg-overlap-other',
          startTime: today1pm,
          endTime: today2pm,
          intensity: NosebleedIntensity.dripping,
        );

        final today130 = DateTime(base.year, base.month, base.day, 13, 30);
        final today145 = DateTime(base.year, base.month, base.day, 13, 45);
        final editing = buildEpistaxisEntry(
          entryId: 'agg-overlap-self',
          startTime: today130,
          endTime: today145,
          intensity: NosebleedIntensity.dripping,
        );

        FeatureFlagService.instance.useReviewScreen = true;
        await pumpScreen(
          tester,
          existingEntry: editing,
          allEntries: [overlapEntry],
          onDelete: (_) async {},
        );

        expect(find.text('Overlapping Events Detected'), findsOneWidget);
      },
    );
  });
}
