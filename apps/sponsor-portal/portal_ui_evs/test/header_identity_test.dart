import 'package:flutter_test/flutter_test.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_ui_evs/src/header_identity.dart';

void main() {
  final principal = UserPrincipal(
    userId: 'elyakolyadina48@gmail.com',
    roles: const {'Administrator'},
    activeRole: 'Administrator',
  );

  group('headerUserName', () {
    test('shows the display name (not the email) when a name is available', () {
      final label = headerUserName(principal, 'Dr. Emily Parker');
      expect(label, 'Dr. Emily Parker');
      expect(label, isNot(contains('@')));
    });

    test('trims surrounding whitespace on the display name', () {
      expect(
        headerUserName(principal, '  Dr. Emily Parker  '),
        'Dr. Emily Parker',
      );
    });

    test('falls back to the account identifier when name is null', () {
      expect(headerUserName(principal, null), 'elyakolyadina48@gmail.com');
    });

    test('falls back to the account identifier when name is blank', () {
      expect(headerUserName(principal, '   '), 'elyakolyadina48@gmail.com');
    });

    test('uses the principal id for a non-user principal', () {
      const anon = AnonymousPrincipal(ipAddress: '10.0.0.1');
      expect(headerUserName(anon, null), anon.id);
    });
  });
}
