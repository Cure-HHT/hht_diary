// Verifies: DIARY-DEV-native-outbound-sync/C
import 'package:clinical_diary/scope/outbound_watermark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final trialStart = DateTime.utc(2026, 6, 20, 10);

  test('normal flow (link BEFORE Trial Start): watermark is Trial Start', () {
    final linkedAt = DateTime.utc(2026, 6, 20, 9); // linked first
    expect(
      effectiveClinicalStartWatermark(
        trialStartedAt: trialStart,
        linkedAt: linkedAt,
      ),
      trialStart,
    );
  });

  test('Trial Start BEFORE link: watermark is floored at the link time so '
      'pre-link entries never ship', () {
    final linkedAt = DateTime.utc(2026, 6, 20, 11); // linked AFTER Trial Start
    expect(
      effectiveClinicalStartWatermark(
        trialStartedAt: trialStart,
        linkedAt: linkedAt,
      ),
      linkedAt,
    );
  });

  test('no link time known: falls back to Trial Start', () {
    expect(
      effectiveClinicalStartWatermark(
        trialStartedAt: trialStart,
        linkedAt: null,
      ),
      trialStart,
    );
  });
}
