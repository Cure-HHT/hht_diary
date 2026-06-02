// Verifies: DIARY-GUI-epistaxis-record/A — a NEW recording preselected for a
//   calendar day defaults its start time to NOON of that day, not midnight
//   (midnight made nudging the time backwards wrap onto the previous day).
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2025, 5, 18, 9, 17);

  test('no preselected day -> defaults to now', () {
    expect(RecordingScreen.defaultStartTime(null, now), now);
  });

  test('preselected calendar day (midnight) -> noon of that day', () {
    expect(
      RecordingScreen.defaultStartTime(DateTime(2025, 5, 18), now),
      DateTime(2025, 5, 18, 12),
    );
  });

  test('preselected day with a time component -> normalized to noon', () {
    expect(
      RecordingScreen.defaultStartTime(DateTime(2025, 5, 18, 3, 30), now),
      DateTime(2025, 5, 18, 12),
    );
  });
}
