// Verifies: DIARY-GUI-epistaxis-record/A, DIARY-PRD-entry-time-restrictions/D
import 'package:clinical_diary/actions/record_epistaxis_event_action.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final action = RecordEpistaxisEventAction();

  ActionContext ctx() => ActionContext(
    principal: const AnonymousPrincipal(),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2025, 10, 15, 20),
  );

  group('RecordEpistaxisEventAction', () {
    test('parseInput throws when required payload fields are missing', () {
      expect(
        () => action.parseInput(const {'intensity': 'dripping'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('validate rejects endTime not after startTime', () {
      final input = action.parseInput(const {
        'startTime': '2025-10-15T14:30:00.000-05:00',
        'startTimeZone': 'America/New_York',
        'startTimeUtcOffset': '-05:00',
        'endTime': '2025-10-15T14:00:00.000-05:00',
        'endTimeZone': 'America/New_York',
        'endTimeUtcOffset': '-05:00',
      });
      expect(() => action.validate(input), throwsArgumentError);
    });

    test(
      'execute emits one finalized epistaxis_event on a fresh DiaryEntry',
      () async {
        final input = action.parseInput(const {
          'startTime': '2025-10-15T14:30:00.000-05:00',
          'startTimeZone': 'America/New_York',
          'startTimeUtcOffset': '-05:00',
          'intensity': 'dripping',
        });
        action.validate(input);
        final result = await action.execute(input, ctx());
        expect(result.events, hasLength(1));
        final draft = result.events.single;
        expect(draft.aggregateType, 'DiaryEntry');
        expect(draft.entryType, 'epistaxis_event');
        expect(draft.eventType, 'finalized');
        expect(draft.aggregateId, result.result); // returned id == aggregate id
        expect(draft.data['startTimeZone'], 'America/New_York');
      },
    );

    test(
      'DIARY-PRD-entry-time-restrictions/D: stores entryJustification when supplied',
      () async {
        final input = action.parseInput(const {
          'startTime': '2025-10-15T14:30:00.000-05:00',
          'startTimeZone': 'America/New_York',
          'startTimeUtcOffset': '-05:00',
          'entryJustification': 'forgot_to_log',
        });
        final result = await action.execute(input, ctx());
        expect(
          result.events.single.data['entryJustification'],
          'forgot_to_log',
        );
      },
    );
  });
}
