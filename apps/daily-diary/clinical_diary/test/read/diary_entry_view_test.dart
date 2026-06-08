// Verifies: DIARY-DEV-reactive-read-path/B
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:flutter_test/flutter_test.dart';

DiaryEntryRow _row(Map<String, Object?> data, String type) =>
    DiaryEntryRow(aggregateId: 'a1', entryType: type, data: data);

void main() {
  group('EpistaxisEntryView', () {
    test('parses typed fields + computes duration/multiday', () {
      final v = EpistaxisEntryView(
        _row(
          const EpistaxisEventPayload(
            startTime: '2025-10-15T22:00:00.000-05:00',
            startTimeZone: 'America/New_York',
            startTimeUtcOffset: '-05:00',
            participantId: 'P-test',
            endTime: '2025-10-16T00:30:00.000-05:00',
            endTimeZone: 'America/New_York',
            endTimeUtcOffset: '-05:00',
            intensity: NosebleedIntensity.pouring,
          ).toJson(),
          'epistaxis_event',
        ),
        isComplete: true,
      );
      // startTime/endTime are the device-local form of the stored instant (so
      // the renderer + edit-init, which expect device-local, are correct). Same
      // moment, device-local kind.
      expect(
        v.startTime,
        DateTime.parse('2025-10-15T22:00:00.000-05:00').toLocal(),
      );
      expect(v.startTime.isUtc, isFalse);
      expect(
        v.endTime,
        DateTime.parse('2025-10-16T00:30:00.000-05:00').toLocal(),
      );
      expect(v.startTimeZone, 'America/New_York');
      expect(v.intensity, NosebleedIntensity.pouring);
      expect(v.durationMinutes, 150);
      expect(v.isMultiDay, isTrue);
      expect(v.isComplete, isTrue);
    });

    test('open-ended entry: null end, null duration', () {
      final v = EpistaxisEntryView(
        _row(
          const EpistaxisEventPayload(
            startTime: '2025-10-15T22:00:00.000-05:00',
            startTimeZone: 'UTC',
            startTimeUtcOffset: '+00:00',
            participantId: 'P-test',
          ).toJson(),
          'epistaxis_event',
        ),
        isComplete: false,
      );
      expect(v.endTime, isNull);
      expect(v.durationMinutes, isNull);
      expect(v.isMultiDay, isFalse);
    });
  });

  group('DayMarkerView', () {
    test('exposes the local date + entry type', () {
      final v = DayMarkerView(
        _row(const {'date': '2025-10-15'}, 'no_epistaxis_event'),
      );
      expect(v.localDate, '2025-10-15');
      expect(v.entryType, 'no_epistaxis_event');
    });
  });

  group('SurveyEntryView', () {
    test('parses typed fields from a survey submission row', () {
      final v = SurveyEntryView(
        _row(
          const QuestionnaireSubmissionPayload(
            instanceId: 'inst-1',
            questionnaireType: 'nose_hht',
            schemaVersion: 's1',
            contentVersion: 'c1',
            guiVersion: 'g1',
            completedAt: '2026-06-08T11:34:00-04:00',
            responses: {
              'q1': QuestionResponse(value: 2, displayLabel: 'Mild'),
              'q2': QuestionResponse(value: 0, displayLabel: 'None'),
            },
          ).toJson(),
          'nose_hht_survey',
        ),
        isComplete: true,
      );
      expect(v.questionnaireType, 'nose_hht');
      // completedAt is the device-local form of the stored instant.
      expect(
        v.completedAt,
        DateTime.parse('2026-06-08T11:34:00-04:00').toLocal(),
      );
      expect(v.completedAt.isUtc, isFalse);
      expect(v.responseCount, 2);
      expect(v.entryType, 'nose_hht_survey');
      expect(v.isComplete, isTrue);
    });
  });

  group('diaryEntryViewOf', () {
    test(
      'returns EpistaxisEntryView for epistaxis rows, DayMarkerView else',
      () {
        final ep = diaryEntryViewOf(
          _row(const {
            'startTime': '2025-10-15T10:00:00.000Z',
            'startTimeZone': 'UTC',
            'startTimeUtcOffset': '+00:00',
            'participantId': 'P-test',
          }, 'epistaxis_event'),
          isComplete: true,
        );
        final dm = diaryEntryViewOf(
          _row(const {'date': '2025-10-15'}, 'unknown_day_event'),
          isComplete: true,
        );
        expect(ep, isA<EpistaxisEntryView>());
        expect(dm, isA<DayMarkerView>());
      },
    );

    test('returns SurveyEntryView for a <id>_survey row', () {
      final sv = diaryEntryViewOf(
        _row(
          const QuestionnaireSubmissionPayload(
            instanceId: 'inst-2',
            questionnaireType: 'qol',
            schemaVersion: 's1',
            contentVersion: 'c1',
            guiVersion: 'g1',
            completedAt: '2026-06-08T09:00:00-04:00',
            responses: {'q1': QuestionResponse(value: 1)},
          ).toJson(),
          'qol_survey',
        ),
        isComplete: true,
      );
      expect(sv, isA<SurveyEntryView>());
      expect((sv as SurveyEntryView).questionnaireType, 'qol');
      expect(sv.responseCount, 1);
    });
  });
}
