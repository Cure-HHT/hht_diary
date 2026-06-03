// Verifies: DIARY-PRD-incomplete-entry-preservation/A+C+D
import 'package:clinical_diary/actions/checkpoint_epistaxis_event_action.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const action = CheckpointEpistaxisEventAction();
  ActionContext ctx() => ActionContext(
    principal: const AnonymousPrincipal(),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2025, 10, 16),
  );

  test('parseInput accepts a null aggregateId (a brand-new draft)', () {
    final input = action.parseInput(const {
      'startTime': '2025-10-15T14:30:00.000-05:00',
      'startTimeZone': 'America/New_York',
      'startTimeUtcOffset': '-05:00',
    });
    expect(input.aggregateId, isNull);
  });

  test(
    'parseInput keeps a supplied aggregateId (resume an existing draft)',
    () {
      final input = action.parseInput(const {
        'aggregateId': 'draft-1',
        'startTime': '2025-10-15T14:30:00.000-05:00',
        'startTimeZone': 'America/New_York',
        'startTimeUtcOffset': '-05:00',
      });
      expect(input.aggregateId, 'draft-1');
    },
  );

  test('parseInput rejects a non-string aggregateId', () {
    expect(
      () => action.parseInput(const {
        'aggregateId': 42,
        'startTime': '2025-10-15T14:30:00.000-05:00',
        'startTimeZone': 'UTC',
        'startTimeUtcOffset': '+00:00',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('validate accepts a partial payload (no endTime / no intensity)', () {
    final input = action.parseInput(const {
      'startTime': '2025-10-15T14:30:00.000-05:00',
      'startTimeZone': 'America/New_York',
      'startTimeUtcOffset': '-05:00',
    });
    expect(() => action.validate(input), returnsNormally);
  });

  test('validate rejects a non-ISO startTime', () {
    final input = action.parseInput(const {
      'startTime': 'not-a-timestamp',
      'startTimeZone': 'UTC',
      'startTimeUtcOffset': '+00:00',
    });
    expect(() => action.validate(input), throwsA(isA<ArgumentError>()));
  });

  test('validate rejects an endTime that is not after startTime', () {
    final input = action.parseInput(const {
      'startTime': '2025-10-15T14:30:00.000Z',
      'startTimeZone': 'UTC',
      'startTimeUtcOffset': '+00:00',
      'endTime': '2025-10-15T14:00:00.000Z',
      'endTimeZone': 'UTC',
      'endTimeUtcOffset': '+00:00',
    });
    expect(() => action.validate(input), throwsA(isA<ArgumentError>()));
  });

  // Equal start/end is structurally valid; the sponsor's shortDurationConfirm
  // clinical rule (UI layer) is the gate for whether equal times can be
  // submitted.
  test('validate accepts an endTime equal to startTime', () {
    final input = action.parseInput(const {
      'startTime': '2025-10-15T14:30:00.000Z',
      'startTimeZone': 'UTC',
      'startTimeUtcOffset': '+00:00',
      'endTime': '2025-10-15T14:30:00.000Z',
      'endTimeZone': 'UTC',
      'endTimeUtcOffset': '+00:00',
    });
    expect(() => action.validate(input), returnsNormally);
  });

  test(
    'execute mints a fresh id for a new draft and emits a checkpoint',
    () async {
      final input = action.parseInput(const {
        'startTime': '2025-10-15T14:30:00.000-05:00',
        'startTimeZone': 'America/New_York',
        'startTimeUtcOffset': '-05:00',
        'intensity': 'dripping',
      });
      action.validate(input);
      final result = await action.execute(input, ctx());
      final draft = result.events.single;
      expect(result.result, isNotEmpty);
      expect(draft.aggregateId, result.result);
      expect(draft.entryType, 'epistaxis_event');
      expect(draft.eventType, 'checkpoint');
      expect(draft.data['startTime'], '2025-10-15T14:30:00.000-05:00');
      expect(draft.data['intensity'], 'dripping');
    },
  );

  test(
    'execute checkpoints the SAME aggregate when resuming a draft',
    () async {
      final input = action.parseInput(const {
        'aggregateId': 'draft-1',
        'startTime': '2025-10-15T14:30:00.000-05:00',
        'startTimeZone': 'America/New_York',
        'startTimeUtcOffset': '-05:00',
      });
      action.validate(input);
      final result = await action.execute(input, ctx());
      final draft = result.events.single;
      expect(result.result, 'draft-1');
      expect(draft.aggregateId, 'draft-1');
      expect(draft.eventType, 'checkpoint');
    },
  );

  test('execute carries an optional checkpointReason onto the event', () async {
    final input = action.parseInput(const {
      'startTime': '2025-10-15T14:30:00.000Z',
      'startTimeZone': 'UTC',
      'startTimeUtcOffset': '+00:00',
      'checkpointReason': 'auto-saved on exit',
    });
    action.validate(input);
    final result = await action.execute(input, ctx());
    expect(result.events.single.data['checkpointReason'], 'auto-saved on exit');
  });
}
