// GET /config/study — the read-only Study Settings aggregate. Values must
// be the EFFECTIVE runtime values (resolved through the same code paths
// their consumers use), unimplemented parameters must be absent, and the
// surface requires an authenticated portal user.
//
// NOTE: study-settings visibility is a spec gap (no DIARY-* REQ covers
// this read surface yet — flagged on CUR-1483), so no Verifies annotation.
import 'dart:convert';
import 'dart:io';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  Future<PortalServerBoot> boot(String dbName) async {
    final db = await newDatabaseFactoryMemory().openDatabase(dbName);
    final b = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
      raveClient: DevSeedRaveClient(),
    );
    addTearDown(b.dispose);
    return b;
  }

  test('unauthenticated -> 403', () async {
    final b = await boot('study-config-unauth.db');
    final resp = await b.router(
      Request('GET', Uri.parse('http://localhost/config/study')),
    );
    expect(resp.statusCode, anyOf(401, 403));
  });

  test(
      'gated on portal.admin.view_settings (ACT-ADM-001): every seeded '
      'role holds it -> 200; a principal without roles is denied', () async {
    final b = await boot('study-config-gate.db');
    // Product decision (CUR-1485): the read-only settings page is
    // reference material for ALL portal staff, so every role is granted
    // the ACT-ADM-001 permission in the sponsor matrix.
    // No CRA user exists in the dev seed, so CRA isn't exercised here;
    // its grant is pinned by the sponsor matrix drift guard instead.
    for (final allowed in ['admin-1', 'sysop-1', 'sc-1']) {
      final resp = await b.router(
        Request(
          'GET',
          Uri.parse('http://localhost/config/study'),
          headers: {'Authorization': 'Bearer $allowed'},
        ),
      );
      expect(resp.statusCode, 200, reason: '$allowed holds view_settings');
    }
    // The permission gate itself still denies a principal that resolves
    // no grants (unknown user -> no roles -> no permissions).
    final denied = await b.router(
      Request(
        'GET',
        Uri.parse('http://localhost/config/study'),
        headers: const {'Authorization': 'Bearer nobody-1'},
      ),
    );
    expect(denied.statusCode, anyOf(401, 403));
  });

  test(
      'authenticated user -> 200 with effective values; unimplemented '
      'params absent', () async {
    final b = await boot('study-config-shape.db');
    final resp = await b.router(
      Request(
        'GET',
        Uri.parse('http://localhost/config/study'),
        headers: const {'Authorization': 'Bearer admin-1'},
      ),
    );
    expect(resp.statusCode, 200);
    final body = jsonDecode(await resp.readAsString()) as Map<String, Object?>;

    // Effective defaults (nothing seeded in this boot).
    expect(body['session_idle_minutes'], 10);
    expect(body['two_factor_code_expiry_minutes'], 10);
    expect(body['two_factor_max_attempts'], 5);
    expect(body['two_factor_issue_max_per_window'], 3);
    expect(body['password_reset_ttl_hours'], 24);
    expect(body['linking_code_expiry_hours'], 72);
    expect(body['justification_threshold_hours'], isNull,
        reason: 'unseeded threshold = no restriction, reported as null');
    expect(body['lock_threshold_hours'], isNull);
    expect(body['short_duration_confirm'], isFalse);
    expect(body['long_duration_confirm'], isFalse);
    expect(body['long_duration_threshold_minutes'], 240,
        reason: 'ClinicalRules permissive default, NOT a display-side copy');
    expect(body['questionnaire_session_timeout_minutes'], 30);
    expect(body['questionnaire_timeout_warning_minutes'], 5);

    // Unimplemented parameters must NOT be reported at all.
    expect(body.containsKey('password_expiry_days'), isFalse);
    expect(body.keys.where((k) => k.contains('app_lock')), isEmpty);
    expect(body.keys.where((k) => k.contains('reminder')), isEmpty);
  });

  test('seeded clinical settings surface as the effective values', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('study-seeded.db');
    final backend = SembastBackend(database: db);
    final b = await bootstrapPortalServer(
      backend: backend,
      raveClient: DevSeedRaveClient(),
      environment: <String, String>{
        ...Platform.environment,
        'PORTAL_SEED_CLINICAL_JUSTIFICATION_THRESHOLD_HOURS': '24',
        'PORTAL_SEED_CLINICAL_LOCK_THRESHOLD_HOURS': '48',
        'PORTAL_SEED_CLINICAL_LONG_DURATION_CONFIRM': 'true',
        'PORTAL_SEED_CLINICAL_LONG_DURATION_THRESHOLD_MINUTES': '60',
      },
    );
    addTearDown(b.dispose);

    final resp = await b.router(
      Request(
        'GET',
        Uri.parse('http://localhost/config/study'),
        headers: const {'Authorization': 'Bearer admin-1'},
      ),
    );
    expect(resp.statusCode, 200);
    final body = jsonDecode(await resp.readAsString()) as Map<String, Object?>;
    expect(body['justification_threshold_hours'], 24);
    expect(body['lock_threshold_hours'], 48);
    expect(body['long_duration_confirm'], isTrue);
    expect(body['long_duration_threshold_minutes'], 60);
  });

  test(
      'questionnaire timing constants match the validated asset '
      '(drift guard)', () {
    // The server mirrors these because Flutter assets are unloadable here;
    // this test pins the mirror to the canonical questionnaire artifact.
    final asset = File(
      '../../common-dart/trial_data_types/assets/data/questionnaires.json',
    );
    expect(asset.existsSync(), isTrue,
        reason: 'expected the canonical questionnaire asset in-repo');
    final doc = jsonDecode(asset.readAsStringSync()) as Map<String, Object?>;
    final questionnaires = (doc['questionnaires'] as List).cast<Map>();
    expect(questionnaires, isNotEmpty);
    for (final q in questionnaires) {
      final sc = q['sessionConfig'] as Map;
      expect(sc['sessionTimeoutMinutes'], questionnaireSessionTimeoutMinutes,
          reason: '${q['id']} timeout drifted from the server mirror');
      expect(sc['timeoutWarningMinutes'], questionnaireTimeoutWarningMinutes,
          reason: '${q['id']} warning drifted from the server mirror');
    }
  });
}
