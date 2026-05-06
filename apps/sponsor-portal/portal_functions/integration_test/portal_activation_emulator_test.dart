// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166: Server-owned portal activation; {code, password} body; no bearer required
//
// Verifies: REQ-d00166-A,B,C,D,E,F (server-owned activation, end-to-end
// against the auth emulator).
//
// Run with:
//   FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
//   DB_HOST=localhost DB_NAME=sponsor_portal \
//   dart test integration_test/portal_activation_emulator_test.dart

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:portal_functions/portal_functions.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'helpers/emulator_setup.dart';

// ---------------------------------------------------------------------------
// Skip guard — all tests skip gracefully when env is absent.
// ---------------------------------------------------------------------------
final bool _hasEmulator =
    Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'] != null;
const String _skipReason =
    'Requires FIREBASE_AUTH_EMULATOR_HOST and a running database';

void main() {
  setUpAll(() async {
    await OTel.reset();
    await OTel.initialize(
      serviceName: 'portal-functions-emulator-test',
      serviceVersion: '0.0.1-test',
      enableMetrics: false,
    );
  });

  tearDownAll(() async {
    await OTel.shutdown();
    await OTel.reset();
    if (_hasEmulator) {
      await Database.instance.close();
    }
  });

  setUpAll(() async {
    if (!_hasEmulator) return;

    final sslEnv = Platform.environment['DB_SSL'];
    final config = DatabaseConfig(
      host: Platform.environment['DB_HOST'] ?? 'localhost',
      port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
      database: Platform.environment['DB_NAME'] ?? 'sponsor_portal',
      username: Platform.environment['DB_USER'] ?? 'postgres',
      password:
          Platform.environment['DB_PASSWORD'] ??
          Platform.environment['LOCAL_DB_PASSWORD'] ??
          'postgres',
      useSsl: sslEnv == 'true',
    );
    await Database.instance.initialize(config);
  });

  tearDown(() async {
    if (!_hasEmulator) return;
    // Remove test rows and all emulator users after each test.
    final db = Database.instance;
    await db.execute(
      "DELETE FROM portal_users WHERE email LIKE '%@emulator-test.example.com'",
    );
    await deleteAllEmulatorUsers();
  });

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Future<Response> post(Map<String, dynamic> body) => activateUserHandler(
    Request(
      'POST',
      Uri.parse('http://localhost/api/v1/portal/activate'),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  Future<Map<String, dynamic>> json(Response r) async {
    final raw = await r.readAsString();
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // -------------------------------------------------------------------------
  // REQ-d00166-A,B,C,D: brand-new email -> emulator user created, uid stamped
  // -------------------------------------------------------------------------

  // Verifies: REQ-d00166-A
  // Verifies: REQ-d00166-B
  // Verifies: REQ-d00166-C
  // Verifies: REQ-d00166-D
  test(
    'REQ-d00166-A,B,C,D: activate brand-new email -> emulator user created, firebase_uid stamped',
    skip: _hasEmulator ? null : _skipReason,
    () async {
      final db = Database.instance;
      await db.execute('''
        INSERT INTO portal_users
          (id, email, name, status, activation_code, activation_code_expires_at)
        VALUES
          (gen_random_uuid(), 'fresh@emulator-test.example.com', 'Fresh',
           'pending', 'FRESH-00001', now() + interval '14 days')
        ''');

      final response = await post({
        'code': 'FRESH-00001',
        'password': 'Emulat0rPw!',
      });

      expect(response.statusCode, equals(200));

      // REQ-d00166-C: single IdP call created the user.
      final emulatorUser = await emulatorLookupByEmail(
        'fresh@emulator-test.example.com',
      );
      expect(
        emulatorUser,
        isNotNull,
        reason: 'IdentityAdmin must have created the emulator user',
      );
      // REQ-d00166-B: emailVerified=true is set by the server (no client-side
      // verification step needed because the activation code was the proof).
      expect(
        emulatorUser!['emailVerified'],
        isTrue,
        reason: 'server must stamp emailVerified=true',
      );

      // REQ-d00166-D: firebase_uid is stamped in the DB row.
      final rows = await db.execute(
        "SELECT firebase_uid, status FROM portal_users "
        "WHERE email = 'fresh@emulator-test.example.com'",
      );
      expect(rows, isNotEmpty);
      expect(
        rows.first[0],
        equals(emulatorUser['localId']),
        reason: 'DB firebase_uid must match the emulator-assigned localId',
      );
      expect(rows.first[1], equals('active'));
    },
  );

  // -------------------------------------------------------------------------
  // REQ-d00166-C: IdP already has the user -> update; preserve uid
  // -------------------------------------------------------------------------

  // Verifies: REQ-d00166-C
  test(
    'REQ-d00166-C: activate when emulator already has user -> updates password, preserves uid',
    skip: _hasEmulator ? null : _skipReason,
    () async {
      // Pre-create an emulator user to simulate IdP-collision.
      final preExistingUid = await emulatorCreateUser(
        'exists@emulator-test.example.com',
        'oldpassword',
      );

      final db = Database.instance;
      await db.execute('''
        INSERT INTO portal_users
          (id, email, name, status, activation_code, activation_code_expires_at)
        VALUES
          (gen_random_uuid(), 'exists@emulator-test.example.com', 'Exists',
           'pending', 'EXIST-00001', now() + interval '14 days')
        ''');

      final response = await post({
        'code': 'EXIST-00001',
        'password': 'NewPw99!',
      });

      expect(response.statusCode, equals(200));

      // uid must be preserved (not a new user created).
      final rows = await db.execute(
        "SELECT firebase_uid FROM portal_users "
        "WHERE email = 'exists@emulator-test.example.com'",
      );
      expect(rows.first[0], equals(preExistingUid));

      // New password must work.
      final signInOk = await emulatorSignIn(
        'exists@emulator-test.example.com',
        'NewPw99!',
      );
      expect(signInOk, isTrue, reason: 'new password must be accepted');

      // Old password must not work.
      final oldSignIn = await emulatorSignIn(
        'exists@emulator-test.example.com',
        'oldpassword',
      );
      expect(oldSignIn, isFalse, reason: 'old password must be rejected');
    },
  );

  // -------------------------------------------------------------------------
  // REQ-d00166-E: retry after success -> already_active=true; no second write
  // -------------------------------------------------------------------------

  // Verifies: REQ-d00166-E
  test(
    'REQ-d00166-E: retry after success returns already_active=true; no second IdP write',
    skip: _hasEmulator ? null : _skipReason,
    () async {
      final db = Database.instance;
      await db.execute('''
        INSERT INTO portal_users
          (id, email, name, status, activation_code, activation_code_expires_at)
        VALUES
          (gen_random_uuid(), 'retry@emulator-test.example.com', 'Retry',
           'pending', 'RETRY-00001', now() + interval '14 days')
        ''');

      // First activation succeeds.
      final first = await post({
        'code': 'RETRY-00001',
        'password': 'FirstPw1!',
      });
      expect(first.statusCode, equals(200));

      final firstUidRows = await db.execute(
        "SELECT firebase_uid FROM portal_users "
        "WHERE email = 'retry@emulator-test.example.com'",
      );
      final firstUid = firstUidRows.first[0] as String;
      expect(firstUid, isNotNull);

      // Second activation with a different password must be idempotent.
      final second = await post({
        'code': 'RETRY-00001',
        'password': 'DifferentPw2!',
      });
      expect(second.statusCode, equals(200));
      final secondBody = await json(second);
      expect(
        secondBody['already_active'],
        isTrue,
        reason: 'idempotent retry must return already_active=true',
      );

      // uid must not have changed.
      final secondUidRows = await db.execute(
        "SELECT firebase_uid FROM portal_users "
        "WHERE email = 'retry@emulator-test.example.com'",
      );
      expect(
        secondUidRows.first[0],
        equals(firstUid),
        reason: 'second activation must not overwrite firebase_uid',
      );

      // First password must still work.
      expect(
        await emulatorSignIn('retry@emulator-test.example.com', 'FirstPw1!'),
        isTrue,
        reason: 'original password must still be valid after retry',
      );

      // Second (rejected) password must not work.
      expect(
        await emulatorSignIn(
          'retry@emulator-test.example.com',
          'DifferentPw2!',
        ),
        isFalse,
        reason: 'second password must be rejected (no IdP write on retry)',
      );
    },
  );

  // -------------------------------------------------------------------------
  // REQ-d00166-A: expired code -> 400, no IdP call made
  // -------------------------------------------------------------------------

  // Verifies: REQ-d00166-A
  test(
    'REQ-d00166-A: expired activation code -> 400, no IdP user created',
    skip: _hasEmulator ? null : _skipReason,
    () async {
      final db = Database.instance;
      await db.execute('''
        INSERT INTO portal_users
          (id, email, name, status, activation_code, activation_code_expires_at)
        VALUES
          (gen_random_uuid(), 'expired@emulator-test.example.com', 'Expired',
           'pending', 'EXPIR-00001', now() - interval '1 day')
        ''');

      final response = await post({
        'code': 'EXPIR-00001',
        'password': 'SomePw1!',
      });

      expect(response.statusCode, equals(400));
      final responseBody = await json(response);
      expect(responseBody['code'], equals('code_expired'));

      // No emulator user must have been created.
      final emulatorUser = await emulatorLookupByEmail(
        'expired@emulator-test.example.com',
      );
      expect(
        emulatorUser,
        isNull,
        reason: 'validation failure must prevent any IdP call',
      );
    },
  );
}
