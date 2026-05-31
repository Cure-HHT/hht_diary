// Verifies: DIARY-DEV-shared-events-catalog/A+C+E
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:test/test.dart';

void main() {
  group('diaryEntriesProjection spec', () {
    test(
      'DIARY-DEV-shared-events-catalog/C: folds only finalized; tombstone deletes',
      () {
        expect(diaryEntriesProjection.viewName, diaryEntriesViewName);
        expect(
          diaryEntriesProjection.interest.aggregateTypes,
          contains(diaryEntryAggregateType),
        );
        // Canonical view excludes checkpoints (P6) — only finalized + tombstone.
        expect(
          diaryEntriesProjection.interest.eventTypes,
          unorderedEquals(<String>{'finalized', 'tombstone'}),
        );
        expect(
          diaryEntriesProjection.interest.eventTypes,
          isNot(contains('checkpoint')),
        );
        expect(
          diaryEntriesProjection.tombstoneEventTypes,
          contains('tombstone'),
        );
      },
    );
  });

  group('dayAggregateId', () {
    test('is {participantId}:{localDate}, stable per participant-day', () {
      expect(dayAggregateId('P-42', '2025-10-15'), 'P-42:2025-10-15');
      // Same participant + day => same aggregate (re-record updates, not dup).
      expect(
        dayAggregateId('P-42', '2025-10-15'),
        dayAggregateId('P-42', '2025-10-15'),
      );
      expect(
        dayAggregateId('P-42', '2025-10-15'),
        isNot(dayAggregateId('P-99', '2025-10-15')),
      );
    });
  });

  group('canonicalEntryDate', () {
    test('epistaxis: uses the local date component of startTime', () {
      final date = canonicalEntryDate('epistaxis_event', const {
        'startTime': '2025-10-15T23:30:00.000-05:00',
      });
      // Capture-tz local day is the 15th, regardless of reader device tz.
      expect(date, '2025-10-15');
    });

    test('near-midnight: date follows the captured local wall clock', () {
      // Same instant, captured in two zones -> two different local days.
      expect(
        canonicalEntryDate('epistaxis_event', const {
          'startTime': '2025-10-16T00:30:00.000+01:00',
        }),
        '2025-10-16',
      );
      expect(
        canonicalEntryDate('epistaxis_event', const {
          'startTime': '2025-10-15T20:30:00.000-04:00',
        }),
        '2025-10-15',
      );
    });

    test('no_epistaxis / unknown_day: use the date field', () {
      expect(
        canonicalEntryDate('no_epistaxis_event', const {'date': '2025-10-15'}),
        '2025-10-15',
      );
      expect(
        canonicalEntryDate('unknown_day_event', const {
          'date': '2025-10-15T00:00:00.000-05:00',
        }),
        '2025-10-15',
      );
    });

    test('returns null for missing / malformed / unknown type', () {
      expect(canonicalEntryDate('epistaxis_event', const {}), isNull);
      expect(
        canonicalEntryDate('epistaxis_event', const {'startTime': 'nope'}),
        isNull,
      );
      expect(
        canonicalEntryDate('mystery_event', const {'date': '2025-10-15'}),
        isNull,
      );
    });
  });
}
