// Verifies: DIARY-DEV-shared-events-catalog/A
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:test/test.dart';

void main() {
  test('closed set wire values', () {
    expect(changeReasonWireValues, {
      'edited',
      'corrected',
      'portal-withdrawn',
      'entered-in-error',
      'duplicate',
    });
  });
  test('fromWire round-trips; rejects unknown', () {
    expect(
      DiaryChangeReason.fromWire('portal-withdrawn'),
      DiaryChangeReason.portalWithdrawn,
    );
    expect(DiaryChangeReason.fromWire('free text'), isNull);
  });
}
