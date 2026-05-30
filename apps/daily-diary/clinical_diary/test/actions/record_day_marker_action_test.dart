// Verifies: DIARY-GUI-epistaxis-record/A, DIARY-GUI-epistaxis-delete/A
import 'package:clinical_diary/actions/delete_entry_action.dart';
import 'package:clinical_diary/actions/record_day_marker_action.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';

ActionContext _ctx({Principal? principal}) => ActionContext(
  principal:
      principal ??
      UserPrincipal(
        userId: 'P-42',
        roles: const {'participant'},
        activeRole: 'participant',
      ),
  security: const SecurityDetails(),
  requestStartedAt: DateTime.utc(2025, 10, 16, 12),
);

void main() {
  group('RecordNoEpistaxisDayAction', () {
    const action = RecordNoEpistaxisDayAction();

    test(
      'emits finalized no_epistaxis_event on the per-day aggregate',
      () async {
        final input = action.parseInput(const {'date': '2025-10-15'});
        action.validate(input);
        final result = await action.execute(input, _ctx());
        final draft = result.events.single;
        expect(draft.entryType, 'no_epistaxis_event');
        expect(draft.eventType, 'finalized');
        expect(draft.aggregateId, 'P-42:2025-10-15'); // {patientId}:{localDate}
        expect(result.result, 'P-42:2025-10-15');
      },
    );

    test('validate rejects a malformed date', () {
      expect(
        () => action.validate(action.parseInput(const {'date': 'nope'})),
        throwsArgumentError,
      );
    });

    test('requires an identified participant', () async {
      final input = action.parseInput(const {'date': '2025-10-15'});
      expect(
        () =>
            action.execute(input, _ctx(principal: const AnonymousPrincipal())),
        throwsStateError,
      );
    });
  });

  group('RecordUnknownDayAction', () {
    const action = RecordUnknownDayAction();
    test(
      'emits finalized unknown_day_event on the per-day aggregate',
      () async {
        final input = action.parseInput(const {'date': '2025-10-15'});
        final result = await action.execute(input, _ctx());
        expect(result.events.single.entryType, 'unknown_day_event');
        expect(result.events.single.aggregateId, 'P-42:2025-10-15');
      },
    );
  });

  group('DeleteEntryAction', () {
    const action = DeleteEntryAction();
    test('emits a tombstone carrying the changeReason', () async {
      final input = action.parseInput(const {
        'aggregateId': 'e1',
        'entryType': 'epistaxis_event',
        'changeReason': 'portal-withdrawn',
      });
      action.validate(input);
      final draft = (await action.execute(input, _ctx())).events.single;
      expect(draft.eventType, 'tombstone');
      expect(draft.aggregateId, 'e1');
      expect(draft.data['changeReason'], 'portal-withdrawn');
    });

    test('parseInput requires aggregateId / entryType / changeReason', () {
      expect(
        () => action.parseInput(const {'entryType': 'x', 'changeReason': 'y'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('validate rejects a changeReason outside the closed set', () {
      final input = action.parseInput(const {
        'aggregateId': 'e1',
        'entryType': 'epistaxis_event',
        'changeReason': 'because-i-felt-like-it',
      });
      expect(() => action.validate(input), throwsArgumentError);
    });

    test('validate accepts entered-in-error / duplicate', () {
      for (final r in ['entered-in-error', 'duplicate']) {
        final input = action.parseInput({
          'aggregateId': 'e1',
          'entryType': 'epistaxis_event',
          'changeReason': r,
        });
        expect(() => action.validate(input), returnsNormally);
      }
    });
  });
}
