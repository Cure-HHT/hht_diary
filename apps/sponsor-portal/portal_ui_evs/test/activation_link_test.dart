import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/activation_link.dart';

void main() {
  test('extracts code from ?code=', () {
    expect(activationCodeFromUri(Uri.parse('https://p/activate?code=AB-CD')),
        'AB-CD');
    expect(activationCodeFromUri(Uri.parse('https://p/?code=AB-CD')), 'AB-CD');
    expect(activationCodeFromUri(Uri.parse('https://p/')), isNull);
  });

  test('passwordsMatch requires equal non-empty values', () {
    expect(passwordsMatch('abc', 'abc'), isTrue);
    expect(passwordsMatch('abc', 'abd'), isFalse);
    expect(passwordsMatch('', ''), isFalse);
  });
}
