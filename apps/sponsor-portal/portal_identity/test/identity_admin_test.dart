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

  test('updatePasswordByEmail: existing user -> accounts:update, returns uid',
      () async {
    final calls = <String>[];
    IdentityAdmin.overrideClient = MockClient((req) async {
      calls.add(req.url.path);
      if (req.url.path.endsWith('accounts:lookup')) {
        return http.Response(
            jsonEncode({
              'users': [
                {'localId': 'uid-9'}
              ]
            }),
            200);
      }
      if (req.url.path.endsWith('accounts:update')) {
        return http.Response(jsonEncode({'localId': 'uid-9'}), 200);
      }
      return http.Response('unexpected', 500);
    });
    final uid = await IdentityAdmin.updatePasswordByEmail(
        email: 'a@x.org', password: 'newpw123');
    expect(uid, 'uid-9');
    expect(calls.any((p) => p.endsWith('accounts:update')), isTrue);
    expect(calls.any((p) => p.endsWith('/accounts')), isFalse); // never signUp
  });

  test('updatePasswordByEmail: no such user -> throws (never creates)',
      () async {
    IdentityAdmin.overrideClient = MockClient((req) async {
      if (req.url.path.endsWith('accounts:lookup')) {
        return http.Response(jsonEncode({'users': <Object?>[]}), 200);
      }
      return http.Response('unexpected', 500);
    });
    expect(
      () => IdentityAdmin.updatePasswordByEmail(
          email: 'ghost@x.org', password: 'pw'),
      throwsA(isA<IdentityAdminException>()),
    );
  });

  test('updatePasswordByEmail: weak password -> IdentityAdminException(400)',
      () async {
    IdentityAdmin.overrideClient = MockClient((req) async {
      if (req.url.path.endsWith('accounts:lookup')) {
        return http.Response(
            jsonEncode({
              'users': [
                {'localId': 'uid-9'}
              ]
            }),
            200);
      }
      if (req.url.path.endsWith('accounts:update')) {
        return http.Response(
            jsonEncode({
              'error': {'message': 'WEAK_PASSWORD'}
            }),
            400);
      }
      return http.Response('unexpected', 500);
    });
    expect(
      () =>
          IdentityAdmin.updatePasswordByEmail(email: 'a@x.org', password: 'x'),
      throwsA(isA<IdentityAdminException>()
          .having((e) => e.statusCode, 'statusCode', 400)),
    );
  });
}
