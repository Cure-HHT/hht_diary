// IMPLEMENTS REQUIREMENTS:
//   REQ-o00045Q: PII scrubbing in error messages

import 'package:otel_common/otel_common.dart';
import 'package:test/test.dart';

void main() {
  group('scrubPii', () {
    test('scrubs email addresses', () {
      expect(
        scrubPii('Error for user john.doe@example.com'),
        equals('Error for user [EMAIL]'),
      );
    });

    test('scrubs JWT tokens', () {
      final jwt =
          'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc123def456';
      expect(scrubPii('Invalid token: $jwt'), equals('Invalid token: [JWT]'));
    });

    test('scrubs phone numbers', () {
      expect(scrubPii('Contact at 555-123-4567'), equals('Contact at [PHONE]'));
    });

    test('scrubs multiple PII types', () {
      final message = 'User test@mail.com called from 555.123.4567';
      final scrubbed = scrubPii(message);
      expect(scrubbed, contains('[EMAIL]'));
      expect(scrubbed, contains('[PHONE]'));
      expect(scrubbed, isNot(contains('test@mail.com')));
    });

    test('preserves messages without PII', () {
      const message = 'Database connection timeout after 30s';
      expect(scrubPii(message), equals(message));
    });
  });
}
