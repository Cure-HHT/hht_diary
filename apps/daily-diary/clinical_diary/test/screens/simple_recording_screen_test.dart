// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00001: Incomplete Entry Preservation (CUR-405)
//
// Phase 12.5 (CUR-1169): Screen-level coverage for SimpleRecordingScreen.
// Drives the screen with a recording-EntryService double that captures
// record() calls so tests can assert on the API contract without bringing
// up the full Sembast write path / Navigator pop.

import 'package:clinical_diary/screens/simple_recording_screen.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/utils/date_time_formatter.dart';
import 'package:clinical_diary/widgets/intensity_row.dart';
import 'package:clinical_diary/widgets/nosebleed_intensity.dart';
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

/// Snapshot of one EntryService.record(...) call.
class _RecordedCall {
  _RecordedCall({
    required this.entryType,
    required this.aggregateId,
    required this.eventType,
    required this.answers,
    required this.checkpointReason,
    required this.changeReason,
  });
  final String entryType;
  final String aggregateId;
  final String eventType;
  final Map<String, Object?> answers;
  final String? checkpointReason;
  final String? changeReason;
}

/// EntryService double that captures record() calls and returns
/// synchronously. Wraps a real EntryService so the constructor's
/// non-null fields stay populated, but the screen never sees a real
/// async write.
class _CapturingEntryService extends EntryService {
  _CapturingEntryService._({
    required super.backend,
    required super.entryTypes,
    required super.deviceInfo,
  }) : super(syncCycleTrigger: _noopSync);

  static Future<void> _noopSync() async {}

  static Future<_CapturingEntryService> create() async {
    final db = await newDatabaseFactoryMemory().openDatabase(
      'simple-recording-${DateTime.now().microsecondsSinceEpoch}.db',
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
        checkpointReason: checkpointReason,
        changeReason: changeReason,
      ),
    );
    // Return null — equivalent to the no-op-duplicate path. The screen
    // doesn't read the returned StoredEvent on the save path.
    return null;
  }

  Future<void> dispose() async {
    await (backend as SembastBackend).close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SimpleRecordingScreen', () {
    late _CapturingEntryService entryService;
    late MockEnrollmentService enrollment;
    late PreferencesService preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = PreferencesService();
      enrollment = MockEnrollmentService();
      entryService = await _CapturingEntryService.create();
    });

    tearDown(() async {
      await entryService.dispose();
    });

    Future<void> pumpScreen(
      WidgetTester tester, {
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
          SimpleRecordingScreen(
            entryService: entryService,
            enrollmentService: enrollment,
            preferencesService: preferences,
            existingEntry: existingEntry,
            allEntries: allEntries,
            onDelete: onDelete,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('initial render shows start, intensity, and end sections', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Nosebleed Start'), findsOneWidget);
      expect(find.text('Max Intensity'), findsOneWidget);
      expect(find.text('Nosebleed End'), findsOneWidget);
    });

    testWidgets(
      'tap save with default state records a finalized epistaxis_event '
      'with startTime in answers',
      (tester) async {
        await pumpScreen(tester);

        await tester.tap(find.byType(FilledButton), warnIfMissed: false);
        await tester.pump();

        expect(entryService.calls, hasLength(1));
        final call = entryService.calls.single;
        expect(call.entryType, 'epistaxis_event');
        expect(call.eventType, 'finalized');
        expect(call.answers['startTime'], isNotNull);
        expect(call.answers.containsKey('endTime'), isFalse);
        expect(call.answers.containsKey('intensity'), isFalse);
      },
    );

    testWidgets(
      'tap save after picking intensity records intensity in answers',
      (tester) async {
        await pumpScreen(tester);

        // The IntensityRow item label appends a trailing newline to align
        // single-word labels; matching by tooltip is robust to that.
        final intensityButton = find.descendant(
          of: find.byType(IntensityRow),
          matching: find.byTooltip('Dripping'),
        );
        expect(intensityButton, findsOneWidget);
        await tester.tap(intensityButton, warnIfMissed: false);
        await tester.pump();

        await tester.tap(find.byType(FilledButton), warnIfMissed: false);
        await tester.pump();

        expect(entryService.calls, hasLength(1));
        final call = entryService.calls.single;
        expect(call.answers['startTime'], isNotNull);
        expect(call.answers['intensity'], 'dripping');
      },
    );

    testWidgets(
      'editing existing entry pre-fills and saving records with the same '
      'aggregateId and a non-null changeReason',
      (tester) async {
        final start = DateTime.now().subtract(const Duration(hours: 1));
        final end = DateTime.now().subtract(const Duration(minutes: 30));
        final existing = buildEpistaxisEntry(
          entryId: 'agg-existing-1',
          startTime: start,
          endTime: end,
          intensity: NosebleedIntensity.dripping,
        );

        await pumpScreen(tester, existingEntry: existing);

        await tester.tap(find.byType(FilledButton), warnIfMissed: false);
        await tester.pump();

        expect(entryService.calls, hasLength(1));
        final call = entryService.calls.single;
        expect(call.aggregateId, 'agg-existing-1');
        expect(call.changeReason, isNotNull);
        expect(call.changeReason, isNot('initial'));
      },
    );

    testWidgets(
      'delete from edit mode invokes onDelete with the chosen reason',
      (tester) async {
        final start = DateTime.now().subtract(const Duration(hours: 2));
        final end = DateTime.now().subtract(const Duration(hours: 1));
        final existing = buildEpistaxisEntry(
          entryId: 'agg-delete-1',
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

        // Open delete confirmation dialog.
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Entered by mistake'));
        await tester.pumpAndSettle();

        final deleteButton = find.widgetWithText(FilledButton, 'Delete');
        expect(deleteButton, findsOneWidget);
        await tester.tap(deleteButton);
        await tester.pump();

        expect(capturedReason, 'Entered by mistake');
      },
    );

    testWidgets(
      'editing existing partial entry: saving keeps aggregateId stable',
      (tester) async {
        final start = DateTime.now().subtract(const Duration(hours: 3));
        final existing = DiaryEntry(
          entryId: 'agg-partial-1',
          entryType: 'epistaxis_event',
          effectiveDate: start,
          currentAnswers: <String, Object?>{
            'startTime': DateTimeFormatter.format(start),
          },
          isComplete: false,
          isDeleted: false,
          latestEventId: 'evt-agg-partial-1',
          updatedAt: start,
        );

        await pumpScreen(tester, existingEntry: existing);

        await tester.tap(find.byType(FilledButton), warnIfMissed: false);
        await tester.pump();

        expect(entryService.calls, hasLength(1));
        expect(entryService.calls.single.aggregateId, 'agg-partial-1');
      },
    );
  });
}
