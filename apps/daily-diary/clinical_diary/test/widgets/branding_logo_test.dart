// Verifies: DIARY-DEV-sponsor-branding-assets/D — the logo renders from the
//   content-addressed cache (Image.memory), fetching the bytes at most once per
//   content hash (no re-fetch on rebuild) and falling back to the app default
//   while loading or when unavailable.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clinical_diary/services/branding_asset_cache.dart';
import 'package:clinical_diary/services/sponsor_branding_service.dart';
import 'package:clinical_diary/widgets/branding_logo.dart';
import 'package:crypto/crypto.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _fallbackKey = Key('logo-fallback');
const _fallback = SizedBox(key: _fallbackKey, width: 120, height: 40);

/// A valid 1x1 PNG so `Image.memory` decodes cleanly under flutter_test.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAF'
  'AAH/iZk9HQAAAABJRU5ErkJggg==',
);

SponsorBrandingConfig _branding(String sha256) =>
    SponsorBrandingConfig.fromSettings(<String, SettingPayload>{
      'branding.logoRole': const SettingPayload(
        key: 'branding.logoRole',
        value: 'logo',
        source: SettingSource.sponsor,
        locked: true,
      ),
      'branding.logoSha256': SettingPayload(
        key: 'branding.logoSha256',
        value: sha256,
        source: SettingSource.sponsor,
        locked: true,
      ),
    });

/// Mount [app] and pump until the async logo resolution (real file IO under
/// `runAsync` + mocked HTTP) has rendered an `Image`. Polls up to ~2s, far more
/// robust on slow CI than a single fixed delay (which raced and rendered 0
/// Images under load).
Future<void> _mountUntilImage(WidgetTester tester, Widget app) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(app);
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
      if (find.byType(Image).evaluate().isNotEmpty) return;
    }
  });
  await tester.pump();
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('branding_logo_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String hashOf(List<int> b) => sha256.convert(b).toString();

  testWidgets('fetches once, renders Image.memory, and does NOT re-fetch '
      'on rebuild', (tester) async {
    final logo = _png;
    final digest = hashOf(logo);
    var httpCalls = 0;
    final client = MockClient((req) async {
      httpCalls++;
      return http.Response.bytes(logo, 200);
    });
    final cache = BrandingAssetCache(cacheDir: tempDir, httpClient: client);

    Widget app() => MaterialApp(
      home: BrandingLogo(
        branding: _branding(digest),
        cache: cache,
        jwtProvider: () async => 'jwt-token',
        fallback: _fallback,
      ),
    );

    // The resolution does real async file IO (cache write/read) which needs a
    // real event loop, so mounting + settling happens under runAsync and pumps
    // until the FutureBuilder has rendered the Image.
    await _mountUntilImage(tester, app());
    // Resolved -> Image.memory rendered, fallback gone, one HTTP fetch.
    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(_fallbackKey), findsNothing);
    expect(httpCalls, 1);
    // The bytes were verified and stored under the content hash.
    expect(File('${tempDir.path}/$digest').existsSync(), isTrue);

    // Rebuild with the SAME branding (same hash) — served from cache, no new
    // fetch (fetch-once per content hash, even across a fresh widget build).
    await _mountUntilImage(tester, app());
    expect(httpCalls, 1);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('cache hit renders with NO network fetch', (tester) async {
    final logo = _png;
    final digest = hashOf(logo);
    // Pre-seed the cache file (content-addressed under its hash).
    File('${tempDir.path}/$digest').writeAsBytesSync(logo);
    var httpCalls = 0;
    final client = MockClient((req) async {
      httpCalls++;
      return http.Response.bytes(Uint8List(0), 200);
    });
    final cache = BrandingAssetCache(cacheDir: tempDir, httpClient: client);

    await _mountUntilImage(
      tester,
      MaterialApp(
        home: BrandingLogo(
          branding: _branding(digest),
          cache: cache,
          jwtProvider: () async => 'jwt-token',
          fallback: _fallback,
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(httpCalls, 0);
  });

  testWidgets('no logo configured -> fallback (no fetch)', (tester) async {
    var httpCalls = 0;
    final client = MockClient((req) async {
      httpCalls++;
      return http.Response.bytes(Uint8List(0), 200);
    });
    final cache = BrandingAssetCache(cacheDir: tempDir, httpClient: client);

    await tester.pumpWidget(
      MaterialApp(
        home: BrandingLogo(
          branding: SponsorBrandingConfig.fallback,
          cache: cache,
          jwtProvider: () async => 'jwt-token',
          fallback: _fallback,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_fallbackKey), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(httpCalls, 0);
  });

  testWidgets('no JWT -> fallback (fetch not attempted)', (tester) async {
    final logo = Uint8List.fromList(utf8.encode('LOGO'));
    final digest = hashOf(logo);
    var httpCalls = 0;
    final client = MockClient((req) async {
      httpCalls++;
      return http.Response.bytes(logo, 200);
    });
    final cache = BrandingAssetCache(cacheDir: tempDir, httpClient: client);

    await tester.pumpWidget(
      MaterialApp(
        home: BrandingLogo(
          branding: _branding(digest),
          cache: cache,
          jwtProvider: () async => null,
          fallback: _fallback,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_fallbackKey), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(httpCalls, 0);
  });
}
