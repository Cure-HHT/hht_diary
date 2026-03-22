// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047G: Database query tracing
//   REQ-o00045Q: PII/PHI scrubbing in trace data

import 'package:otel_common/otel_common.dart';
import 'package:test/test.dart';

void main() {
  group('sanitizeSql', () {
    test('replaces single-quoted string literals', () {
      expect(
        sanitizeSql("SELECT * FROM users WHERE name = 'John Doe'"),
        equals("SELECT * FROM users WHERE name = '?'"),
      );
    });

    test('replaces multiple string literals', () {
      expect(
        sanitizeSql(
            "INSERT INTO users (name, email) VALUES ('Jane', 'jane@test.com')"),
        equals("INSERT INTO users (name, email) VALUES ('?', '?')"),
      );
    });

    test('replaces numeric literals', () {
      expect(
        sanitizeSql('SELECT * FROM users WHERE age > 25 AND id = 42'),
        equals('SELECT * FROM users WHERE age > ? AND id = ?'),
      );
    });

    test('preserves named parameters', () {
      expect(
        sanitizeSql('SELECT * FROM users WHERE id = @userId'),
        equals('SELECT * FROM users WHERE id = @userId'),
      );
    });

    test('handles empty string', () {
      expect(sanitizeSql(''), equals(''));
    });

    test('preserves table and column names', () {
      expect(
        sanitizeSql('SELECT user_id, name FROM app_users'),
        equals('SELECT user_id, name FROM app_users'),
      );
    });
  });
}
