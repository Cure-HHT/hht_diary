// Verifies: DIARY-GUI-calendar-day-view/A
import 'package:clinical_diary/read/diary_read.dart';
import 'package:flutter_test/flutter_test.dart';

DiaryEntryRow _row(String id, String type, Map<String, Object?> data) =>
    DiaryEntryRow(aggregateId: id, entryType: type, data: data);

void main() {
  final epistaxis = _row('e1', 'epistaxis_event', const {
    'startTime': '2025-10-15T23:30:00.000-05:00',
  });
  final noBleed = _row('P:2025-10-16', 'no_epistaxis_event', const {
    'date': '2025-10-16',
  });
  final unknown = _row('P:2025-10-17', 'unknown_day_event', const {
    'date': '2025-10-17',
  });

  group('entriesOnLocalDate', () {
    test('buckets by canonical capture-tz local date', () {
      // epistaxis startTime is 23:30 at -05:00 -> local day is the 15th.
      expect(entriesOnLocalDate([epistaxis, noBleed], '2025-10-15'), [
        epistaxis,
      ]);
      expect(entriesOnLocalDate([epistaxis, noBleed], '2025-10-16'), [noBleed]);
    });
  });

  group('yesterday / gap helpers', () {
    test('hasNosebleedRelatedEntryOn', () {
      expect(hasNosebleedRelatedEntryOn([epistaxis], '2025-10-15'), isTrue);
      expect(hasNosebleedRelatedEntryOn([epistaxis], '2025-10-16'), isFalse);
    });

    test('uncoveredDays returns the notRecorded days in the window', () {
      final days = ['2025-10-15', '2025-10-16', '2025-10-17', '2025-10-18'];
      // 15 covered (epistaxis), 16 (noBleed), 17 (unknown); 18 uncovered.
      expect(uncoveredDays([epistaxis, noBleed, unknown], days), [
        '2025-10-18',
      ]);
      // An incomplete checkpoint on 18 makes it covered (incomplete != notRecorded).
      expect(
        uncoveredDays(
          [epistaxis, noBleed, unknown],
          days,
          incompleteDates: {'2025-10-18'},
        ),
        isEmpty,
      );
    });
  });

  group('dayStatusForLocalDate precedence', () {
    test('nosebleed wins over a same-day no-bleed marker', () {
      final sameDayNoBleed = _row('P:2025-10-15', 'no_epistaxis_event', const {
        'date': '2025-10-15',
      });
      expect(
        dayStatusForLocalDate([epistaxis, sameDayNoBleed], '2025-10-15'),
        DayStatus.nosebleed,
      );
    });

    test('noNosebleed, unknown, notRecorded', () {
      expect(
        dayStatusForLocalDate([noBleed], '2025-10-16'),
        DayStatus.noNosebleed,
      );
      expect(dayStatusForLocalDate([unknown], '2025-10-17'), DayStatus.unknown);
      expect(
        dayStatusForLocalDate([epistaxis], '2025-10-20'),
        DayStatus.notRecorded,
      );
    });

    test(
      'incomplete only when a local checkpoint exists and no finalized entry',
      () {
        expect(
          dayStatusForLocalDate(
            const [],
            '2025-10-18',
            incompleteDates: {'2025-10-18'},
          ),
          DayStatus.incomplete,
        );
        // A finalized entry outranks an incomplete checkpoint on the same day.
        expect(
          dayStatusForLocalDate(
            [epistaxis],
            '2025-10-15',
            incompleteDates: {'2025-10-15'},
          ),
          DayStatus.nosebleed,
        );
      },
    );
  });
}
