// Verifies: DIARY-DEV-sponsor-branding-source/E+F+G — the branding asset
//   endpoint requires the patient session JWT (401 without), serves the logo
//   bytes for a role present in the materialized manifest, 404s an unknown or
//   path-traversal role (never reading a file off the request string), and 503s
//   when no branding has been materialized.
import 'dart:io';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/src/patient_token_validator.dart';
import 'package:portal_server_evs/src/sponsor_branding_asset_handler.dart';
import 'package:portal_server_evs/src/sponsor_branding_seed.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

Future<EventStore> _openStore() async {
  final db = await newDatabaseFactoryMemory().openDatabase('branding-h.db');
  return openPortalEventStore(backend: SembastBackend(database: db));
}

/// Content overlay with a logo, returns the root dir.
Directory _withLogo(String sponsorId, List<int> logoBytes) {
  final dir = Directory.systemTemp.createTempSync('branding_asset_');
  final imgDir = Directory('${dir.path}/$sponsorId/portal/assets/images')
    ..createSync(recursive: true);
  File('${imgDir.path}/app_logo.png').writeAsBytesSync(logoBytes);
  File('${dir.path}/$sponsorId/sponsor-config.json')
      .writeAsStringSync('{"sponsorId":"$sponsorId","title":"Ref"}');
  return dir;
}

/// Drive the handler through a router so `<role>` is parsed as a path param.
Future<Response> _get(Handler h, String role, {String? auth}) {
  final router = Router()..get('/api/v1/sponsor/branding/asset/<role>', h);
  return router.call(Request(
    'GET',
    Uri.parse('http://localhost/api/v1/sponsor/branding/asset/$role'),
    headers: {if (auth != null) 'authorization': auth},
  ));
}

void main() {
  test('missing auth -> 401', () async {
    final store = await _openStore();
    final h = sponsorBrandingAssetHandler(eventStore: store);
    final res = await _get(h, 'logo');
    expect(res.statusCode, 401);
  });

  test('invalid token -> 401', () async {
    final store = await _openStore();
    final h = sponsorBrandingAssetHandler(eventStore: store);
    final res = await _get(h, 'logo', auth: 'Bearer not-a-jwt');
    expect(res.statusCode, 401);
  });

  test('valid JWT but no branding materialized -> 503', () async {
    final store = await _openStore();
    final h = sponsorBrandingAssetHandler(eventStore: store);
    final token = createPatientJwt(authCode: 'ac', userId: 'P-1');
    final res = await _get(h, 'logo', auth: 'Bearer $token');
    expect(res.statusCode, 503);
  });

  test('valid JWT + seeded logo -> 200 + image/png + bytes', () async {
    final store = await _openStore();
    final root = _withLogo('reference', const [9, 8, 7, 6, 5]);
    addTearDown(() => root.deleteSync(recursive: true));
    await seedSponsorBranding(
      eventStore: store,
      backend: store.backend,
      contentRoot: root.path,
      sponsorId: 'reference',
    );

    final h = sponsorBrandingAssetHandler(
      eventStore: store,
      contentRoot: root.path,
      sponsorId: 'reference',
    );
    final token = createPatientJwt(authCode: 'ac', userId: 'P-1');
    final res = await _get(h, 'logo', auth: 'Bearer $token');
    expect(res.statusCode, 200);
    expect(res.headers['content-type'], 'image/png');
    final body = await res.read().expand((c) => c).toList();
    expect(body, const [9, 8, 7, 6, 5]);
  });

  test('valid JWT + unknown role -> 404', () async {
    final store = await _openStore();
    final root = _withLogo('reference', const [1, 2, 3]);
    addTearDown(() => root.deleteSync(recursive: true));
    await seedSponsorBranding(
      eventStore: store,
      backend: store.backend,
      contentRoot: root.path,
      sponsorId: 'reference',
    );
    final h = sponsorBrandingAssetHandler(
      eventStore: store,
      contentRoot: root.path,
      sponsorId: 'reference',
    );
    final token = createPatientJwt(authCode: 'ac', userId: 'P-1');
    final res = await _get(h, 'banner', auth: 'Bearer $token');
    expect(res.statusCode, 404);
  });

  test('valid JWT + path-traversal role -> 404 (no file read)', () async {
    final store = await _openStore();
    final root = _withLogo('reference', const [1, 2, 3]);
    addTearDown(() => root.deleteSync(recursive: true));
    await seedSponsorBranding(
      eventStore: store,
      backend: store.backend,
      contentRoot: root.path,
      sponsorId: 'reference',
    );
    final h = sponsorBrandingAssetHandler(
      eventStore: store,
      contentRoot: root.path,
      sponsorId: 'reference',
    );
    final token = createPatientJwt(authCode: 'ac', userId: 'P-1');
    final res = await _get(h, '..%2F..%2Fetc%2Fpasswd', auth: 'Bearer $token');
    expect(res.statusCode, 404);
  });
}
