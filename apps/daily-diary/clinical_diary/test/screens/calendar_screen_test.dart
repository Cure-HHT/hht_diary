// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00008: Mobile App Diary Entry
//
// Phase 12.5 (CUR-1169): Screen-level coverage for CalendarScreen.
// Drives the screen with a real EntryService + DiaryEntryReader against
// an in-memory Sembast backend so the day-status mapping is exercised
// end-to-end without needing the full runtime bootstrap.

import 'package:clinical_diary/screens/calendar_screen.dart';
import 'package:clinical_diary/screens/date_records_screen.dart';
import 'package:clinical_diary/screens/day_selection_screen.dart';
import 'package:clinical_diary/services/diary_entry_reader.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/utils/date_time_formatter.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_enrollment_service.dart';
import '../helpers/test_helpers.dart';

List<EntryTypeDefinition> _nosebleedDefs() => const [
  EntryTypeDefinition(
    id: 'epistaxis_event',
    registeredVersion: 1,
    name: 'Nosebleed',
    widgetId: 'epistaxis_form_v1',
    widgetConfig: <String, Object?>{},
    effectiveDatePath: 'startTime',
  ),
  EntryTypeDefinition(
    id: 'no_epistaxis_event',
    registeredVersion: 1,
    name: 'No Nosebleeds',
    widgetId: 'epistaxis_form_v1',
    widgetConfig: <String, Object?>{},
    effectiveDatePath: 'date',
  ),
  EntryTypeDefinition(
    id: 'unknown_day_event',
    registeredVersion: 1,
    name: 'Unknown Day',
    widgetId: 'epistaxis_form_v1',
    widgetConfig: <String, Object?>{},
    effectiveDatePath: 'date',
  ),
];

class _RecordedCall {
  _RecordedCall({
    required this.entryType,
    required this.aggregateId,
    required this.eventType,
    required this.answers,
  });
  final String entryType;
  final String aggregateId;
  final String eventType;
  final Map<String, Object?> answers;
}

/// EntryService double that captures record() calls and forwards to a
/// real EntryService so reads via DiaryEntryReader observe the writes.
class _CapturingEntryService extends EntryService {
  _CapturingEntryService._({
    required EntryService delegate,
    required super.backend,
    required super.entryTypes,
    required super.deviceInfo,
  }) : _delegate = delegate,
       super(syncCycleTrigger: _noop);

  static Future<void> _noop() async {}

  static Future<({_CapturingEntryService service, SembastBackend backend})>
  create() async {
    final db = await newDatabaseFactoryMemory().openDatabase(
      'calendar-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final backend = SembastBackend(database: db);
    final registry = EntryTypeRegistry();
    for (final def in _nosebleedDefs()) {
      registry.register(def);
    }
    final delegate = EntryService(
      backend: backend,
      entryTypes: registry,
      syncCycleTrigger: _noop,
      deviceInfo: const DeviceInfo(
        deviceId: 'device-test',
        softwareVersion: 'clinical_diary@0.0.0',
        userId: 'user-test',
      ),
    );
    final service = _CapturingEntryService._(
      delegate: delegate,
      backend: backend,
      entryTypes: registry,
      deviceInfo: const DeviceInfo(
        deviceId: 'device-test',
        softwareVersion: 'clinical_diary@0.0.0',
        userId: 'user-test',
      ),
    );
    return (service: service, backend: backend);
  }

  final EntryService _delegate;
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
      ),
    );
    return _delegate.record(
      entryType: entryType,
      aggregateId: aggregateId,
      eventType: eventType,
      answers: answers,
      checkpointReason: checkpointReason,
      changeReason: changeReason,
    );
  }
}

/// ISO-8601 string for the local-day midnight of [date].
String _localDayIso(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return DateTimeFormatter.format(day);
}

/// Bounded pumps. Avoids pumpAndSettle infinite-loop on the
/// TableCalendar's page animator while still letting async post-frame
/// futures resolve via Dart microtasks.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 33));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalendarScreen', () {
    late _CapturingEntryService entryService;
    late SembastBackend backend;
    late DiaryEntryReader reader;
    late MockEnrollmentService enrollment;
    late PreferencesService preferences;

    setUp(() async {
      // Disable animations to stop the table-calendar's page animator from
      // ticking forever inside pumpAndSettle.
      SharedPreferences.setMockInitialValues({'pref_use_animation': false});
      preferences = PreferencesService();
      enrollment = MockEnrollmentService();
      final created = await _CapturingEntryService.create();
      entryService = created.service;
      backend = created.backend;
      reader = DiaryEntryReader(backend: backend);
    });

    tearDown(() async {
      await backend.close();
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        wrapWithMaterialApp(
          CalendarScreen(
            entryService: entryService,
            reader: reader,
            enrollmentService: enrollment,
            preferencesService: preferences,
          ),
        ),
      );
      await _settle(tester);
    }

    /// Records an event via the real EntryService, but inside `runAsync`
    /// so Sembast's internal async (which can use real timers) actually
    /// fires under TestWidgetsFlutterBinding's fake clock.
    Future<void> recordEvent(
      WidgetTester tester, {
      required String entryType,
      required String aggregateId,
      required String eventType,
      required Map<String, Object?> answers,
      String? checkpointReason,
    }) async {
      await tester.runAsync(() async {
        await entryService.record(
          entryType: entryType,
          aggregateId: aggregateId,
          eventType: eventType,
          answers: answers,
          checkpointReason: checkpointReason,
        );
      });
    }

    /// Wraps a reader query in `runAsync` for the same reason as
    /// [recordEvent].
    Future<DayStatus?> readDayStatus(
      WidgetTester tester, {
      required DateTime day,
    }) async {
      Map<DateTime, DayStatus>? statuses;
      await tester.runAsync(() async {
        statuses = await reader.dayStatusRange(
          DateTime(day.year, day.month, 1),
          DateTime(day.year, day.month + 1, 0),
        );
      });
      return statuses?[DateTime(day.year, day.month, day.day)];
    }

    testWidgets('renders calendar dialog with header and legend', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Select Date'), findsOneWidget);
      expect(find.text('Nosebleed events'), findsOneWidget);
      expect(find.text('No nosebleeds'), findsOneWidget);
      expect(find.text('Unknown'), findsOneWidget);
      expect(find.text('Incomplete/Missing'), findsOneWidget);
      expect(find.text('Not recorded'), findsOneWidget);
    });

    testWidgets(
      'finalized epistaxis_event today produces DayStatus.nosebleed',
      (tester) async {
        await recordEvent(
          tester,
          entryType: 'epistaxis_event',
          aggregateId: 'agg-cal-1',
          eventType: 'finalized',
          answers: <String, Object?>{
            'startTime': DateTime.now().toUtc().toIso8601String(),
          },
        );

        await pumpScreen(tester);

        final status = await readDayStatus(tester, day: DateTime.now());
        expect(status, DayStatus.nosebleed);
      },
    );

    testWidgets(
      'finalized no_epistaxis_event today produces DayStatus.noNosebleed',
      (tester) async {
        await recordEvent(
          tester,
          entryType: 'no_epistaxis_event',
          aggregateId: 'agg-cal-2',
          eventType: 'finalized',
          answers: <String, Object?>{'date': _localDayIso(DateTime.now())},
        );

        await pumpScreen(tester);

        final status = await readDayStatus(tester, day: DateTime.now());
        expect(status, DayStatus.noNosebleed);
      },
    );

    testWidgets(
      'finalized unknown_day_event today produces DayStatus.unknown',
      (tester) async {
        await recordEvent(
          tester,
          entryType: 'unknown_day_event',
          aggregateId: 'agg-cal-3',
          eventType: 'finalized',
          answers: <String, Object?>{'date': _localDayIso(DateTime.now())},
        );

        await pumpScreen(tester);

        final status = await readDayStatus(tester, day: DateTime.now());
        expect(status, DayStatus.unknown);
      },
    );

    testWidgets('checkpointed-but-not-finalized epistaxis_event today produces '
        'DayStatus.incomplete', (tester) async {
      await recordEvent(
        tester,
        entryType: 'epistaxis_event',
        aggregateId: 'agg-cal-4',
        eventType: 'checkpoint',
        answers: <String, Object?>{
          'startTime': DateTime.now().toUtc().toIso8601String(),
        },
        checkpointReason: 'partial',
      );

      await pumpScreen(tester);

      final status = await readDayStatus(tester, day: DateTime.now());
      expect(status, DayStatus.incomplete);
    });

    testWidgets(
      'tapping a not-recorded day opens DaySelectionScreen and "No nosebleed '
      'events" records a no_epistaxis_event',
      (tester) async {
        await pumpScreen(tester);

        final today = DateTime.now();
        // Use .last because TableCalendar renders outside-month padding
        // days (e.g. March 29 in April's view) before the in-month cell.
        await tester.tap(find.text(today.day.toString()).last);
        await _settle(tester);

        expect(find.byType(DaySelectionScreen), findsOneWidget);

        await tester.tap(find.text('No nosebleed events'));
        await _settle(tester);

        expect(
          entryService.calls.where(
            (c) =>
                c.entryType == 'no_epistaxis_event' &&
                c.eventType == 'finalized',
          ),
          hasLength(1),
        );
      },
    );

    testWidgets('tapping a day with existing entries opens DateRecordsScreen', (
      tester,
    ) async {
      await recordEvent(
        tester,
        entryType: 'epistaxis_event',
        aggregateId: 'agg-cal-5',
        eventType: 'finalized',
        answers: <String, Object?>{
          'startTime': DateTime.now().toUtc().toIso8601String(),
        },
      );

      await pumpScreen(tester);

      final today = DateTime.now();
      // Use .last because TableCalendar renders outside-month padding
      // days (e.g. March 29 in April's view) before the in-month cell.
      await tester.tap(find.text(today.day.toString()).last);
      await _settle(tester);

      expect(find.byType(DateRecordsScreen), findsOneWidget);
    });

    testWidgets(
      'mark unknown via DaySelectionScreen records an unknown_day_event',
      (tester) async {
        await pumpScreen(tester);

        final today = DateTime.now();
        // Use .last because TableCalendar renders outside-month padding
        // days (e.g. March 29 in April's view) before the in-month cell.
        await tester.tap(find.text(today.day.toString()).last);
        await _settle(tester);
        expect(find.byType(DaySelectionScreen), findsOneWidget);

        await tester.tap(find.text("I don't recall / unknown"));
        await _settle(tester);

        expect(
          entryService.calls.where(
            (c) =>
                c.entryType == 'unknown_day_event' &&
                c.eventType == 'finalized',
          ),
          hasLength(1),
        );
      },
    );
  });
}
