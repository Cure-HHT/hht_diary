// Verifies: DIARY-DEV-linking-code-lifecycle/A — server-side code generation.
import 'package:portal_actions/src/linking_code_generator.dart';
import 'package:test/test.dart';

void main() {
  test('code is prefix + 8 non-ambiguous chars, random', () {
    const charset = 'ABCDEFGHJKLMNPQRTUVWXY346789';
    final codes = {
      for (var i = 0; i < 100; i++) generateLinkingCode(prefix: 'CA'),
    };
    expect(codes.length, 100);
    for (final c in codes) {
      expect(c.startsWith('CA'), isTrue);
      expect(c.length, 10);
      expect(c.substring(2).split('').every(charset.contains), isTrue);
    }
  });
}
