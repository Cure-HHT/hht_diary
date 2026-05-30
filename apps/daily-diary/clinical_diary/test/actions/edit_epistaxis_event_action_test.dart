// Verifies: DIARY-GUI-epistaxis-record/A
import 'package:clinical_diary/actions/edit_epistaxis_event_action.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const action = EditEpistaxisEventAction();
  ActionContext ctx() => ActionContext(
    principal: const AnonymousPrincipal(),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2025, 10, 16),
  );

  test('parseInput requires aggregateId', () {
    expect(
      () => action.parseInput(const {
        'startTime': '2025-10-15T14:30:00.000-05:00',
        'startTimeZone': 'UTC',
        'startTimeUtcOffset': '+00:00',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('re-finalizes the same aggregate with changeReason=edited', () async {
    final input = action.parseInput(const {
      'aggregateId': 'e1',
      'startTime': '2025-10-15T14:30:00.000-05:00',
      'startTimeZone': 'America/New_York',
      'startTimeUtcOffset': '-05:00',
      'intensity': 'pouring',
    });
    action.validate(input);
    final result = await action.execute(input, ctx());
    final draft = result.events.single;
    expect(draft.aggregateId, 'e1');
    expect(result.result, 'e1');
    expect(draft.entryType, 'epistaxis_event');
    expect(draft.eventType, 'finalized');
    expect(draft.data['changeReason'], 'edited');
    expect(draft.data['intensity'], 'pouring');
  });
}
