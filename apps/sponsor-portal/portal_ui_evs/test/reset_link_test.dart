import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/reset_link.dart';

void main() {
  test('extracts reset code from ?reset=', () {
    expect(resetCodeFromUri(Uri.parse('https://p/?reset=R-1')), 'R-1');
    expect(
      resetCodeFromUri(Uri.parse('https://p/?code=AB')),
      isNull,
    ); // activation, not reset
    expect(resetCodeFromUri(Uri.parse('https://p/')), isNull);
  });
}
