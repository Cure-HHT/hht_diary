// Verifies: REQ-d00166-C, REQ-d00166-F
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_functions/src/identity_admin.dart';
import 'package:test/test.dart';

void main() {
  group('IdentityAdmin', () {
    test(
      'REQ-d00166-C: IdentityAdmin.lookupOrProvisionByEmail signature exists',
      () {
        // Compilation-only test: the symbol must be accessible and its
        // return type must be a Record with the expected fields.
        final fn = IdentityAdmin.lookupOrProvisionByEmail;
        expect(fn, isA<Function>());
      },
    );

    test('REQ-d00166-F: LookupOrProvisionResult exposes uid and created', () {
      const r = LookupOrProvisionResult(uid: 'abc', created: true);
      expect(r.uid, equals('abc'));
      expect(r.created, isTrue);
    });
  });

  group('IdentityAdmin.lookupOrProvisionByEmail', () {
    setUp(() {
      IdentityAdmin.overrideClient = null;
    });
    tearDown(() {
      IdentityAdmin.overrideClient = null;
    });

    // Verifies: REQ-d00166-C
    test(
      'REQ-d00166-C: lookup miss -> signUp -> returns (uid, created=true)',
      () async {
        final calls = <Map<String, Object?>>[];
        final mock = MockClient((req) async {
          calls.add({
            'path': req.url.path,
            'method': req.method,
            'body': jsonDecode(req.body) as Map<String, dynamic>,
          });
          if (req.url.path.endsWith(':lookup')) {
            return http.Response(
              jsonEncode({'kind': 'identitytoolkit#GetAccountInfoResponse'}),
              200,
            );
          }
          if (req.url.path.endsWith('/accounts')) {
            return http.Response(jsonEncode({'localId': 'NEW_UID_123'}), 200);
          }
          return http.Response('unexpected', 500);
        });

        IdentityAdmin.overrideClient = mock;

        final result = await IdentityAdmin.lookupOrProvisionByEmail(
          email: 'alice@example.com',
          displayName: 'Alice',
          password: 'secretpw1',
        );

        expect(result.uid, equals('NEW_UID_123'));
        expect(result.created, isTrue);
        expect(calls.length, equals(2));
        expect(calls[0]['path'], endsWith(':lookup'));
        expect(calls[1]['path'], endsWith('/accounts'));
        final signUpBody = calls[1]['body'] as Map<String, dynamic>;
        expect(signUpBody['email'], equals('alice@example.com'));
        expect(signUpBody['password'], equals('secretpw1'));
        expect(signUpBody['emailVerified'], isTrue);
      },
    );

    // Verifies: REQ-d00166-C
    test(
      'REQ-d00166-C: lookup hit -> update -> returns (uid, created=false)',
      () async {
        final calls = <Map<String, Object?>>[];
        final mock = MockClient((req) async {
          calls.add({
            'path': req.url.path,
            'method': req.method,
            'body': jsonDecode(req.body) as Map<String, dynamic>,
          });
          if (req.url.path.endsWith(':lookup')) {
            return http.Response(
              jsonEncode({
                'kind': 'identitytoolkit#GetAccountInfoResponse',
                'users': [
                  {'localId': 'EXISTING_UID_456', 'email': 'alice@example.com'},
                ],
              }),
              200,
            );
          }
          if (req.url.path.endsWith(':update')) {
            return http.Response(
              jsonEncode({'localId': 'EXISTING_UID_456'}),
              200,
            );
          }
          return http.Response('unexpected', 500);
        });

        IdentityAdmin.overrideClient = mock;

        final result = await IdentityAdmin.lookupOrProvisionByEmail(
          email: 'alice@example.com',
          displayName: 'Alice',
          password: 'newpw2',
        );

        expect(result.uid, equals('EXISTING_UID_456'));
        expect(result.created, isFalse);
        final updateBody = calls[1]['body'] as Map<String, dynamic>;
        expect(updateBody['localId'], equals('EXISTING_UID_456'));
        expect(updateBody['password'], equals('newpw2'));
        expect(updateBody['emailVerified'], isTrue);
      },
    );

    // Verifies: REQ-d00166-F
    test(
      'REQ-d00166-F: 5xx from underlying API surfaces as IdentityAdminException',
      () async {
        final mock = MockClient(
          (req) async => http.Response('upstream sad', 503),
        );
        IdentityAdmin.overrideClient = mock;

        await expectLater(
          IdentityAdmin.lookupOrProvisionByEmail(
            email: 'alice@example.com',
            displayName: 'Alice',
            password: 'p',
          ),
          throwsA(
            isA<IdentityAdminException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(503),
            ),
          ),
        );
      },
    );
  });
}
