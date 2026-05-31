// Verifies: DIARY-DEV-portal-reaction-server/B
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:reaction/reaction.dart';
import 'package:test/test.dart';

void main() {
  final v = const DevCredentialAuthValidator();

  test('parses "userId:activeRole" into a UserPrincipal', () async {
    final p = await v.authenticate('admin-1:Administrator');
    expect(p, isA<UserPrincipal>());
    final up = p as UserPrincipal;
    expect(up.userId, 'admin-1');
    expect(up.activeRole, 'Administrator');
    expect(up.roles, contains('Administrator'));
  });

  test('rejects empty or malformed credentials', () async {
    expect(() => v.authenticate(''), throwsA(isA<AuthenticationDenied>()));
    expect(
        () => v.authenticate('no-colon'), throwsA(isA<AuthenticationDenied>()));
    expect(() => v.authenticate('u:'), throwsA(isA<AuthenticationDenied>()));
  });
}
