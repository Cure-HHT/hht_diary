import 'dart:convert';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:portal_identity/portal_identity.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() => IdentityAdmin.overrideClient = null);

  test('absent user -> signUp, created=true', () async {
    final calls = <String>[];
    IdentityAdmin.overrideClient = MockClient((req) async {
      calls.add(req.url.path);
      if (req.url.path.endsWith('accounts:lookup')) {
        return http.Response(jsonEncode({'users': <Object?>[]}), 200);
      }
      if (req.url.path.endsWith('/accounts')) {
        return http.Response(jsonEncode({'localId': 'uid-new'}), 200);
      }
      return http.Response('unexpected', 500);
    });
    final r = await IdentityAdmin.lookupOrProvisionByEmail(
        email: 'a@x.org', displayName: 'A', password: 'pw');
    expect(r.uid, 'uid-new');
    expect(r.created, isTrue);
    expect(calls.any((p) => p.endsWith('accounts:lookup')), isTrue);
  });

  test('existing user -> update, created=false', () async {
    IdentityAdmin.overrideClient = MockClient((req) async {
      if (req.url.path.endsWith('accounts:lookup')) {
        return http.Response(
            jsonEncode({
              'users': [
                {'localId': 'uid-old'}
              ]
            }),
            200);
      }
      if (req.url.path.endsWith('accounts:update')) {
        return http.Response(jsonEncode({'localId': 'uid-old'}), 200);
      }
      return http.Response('unexpected', 500);
    });
    final r = await IdentityAdmin.lookupOrProvisionByEmail(
        email: 'a@x.org', displayName: 'A', password: 'pw');
    expect(r.uid, 'uid-old');
    expect(r.created, isFalse);
  });

  test('non-200 lookup throws IdentityAdminException', () async {
    IdentityAdmin.overrideClient =
        MockClient((req) async => http.Response('boom', 503));
    expect(
      () => IdentityAdmin.lookupOrProvisionByEmail(
          email: 'a@x.org', displayName: 'A', password: 'pw'),
      throwsA(isA<IdentityAdminException>()),
    );
  });
}
