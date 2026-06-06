// Verifies: DIARY-DEV-sponsor-branding-assets/A+B+C — branding asset bytes are
//   cached locally keyed by content hash (fetched at most once per hash),
//   verified against the expected hash (mismatch -> failed fetch, nothing
//   stored), and served from the cache without re-fetching while the hash is
//   unchanged. The fetch goes JWT-gated to the role-keyed asset endpoint.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clinical_diary/services/branding_asset_cache.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('branding_cache_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  String hashOf(List<int> bytes) => sha256.convert(bytes).toString();

  test('miss -> fetch -> hash matches -> bytes stored under sha256; '
      'subsequent get() returns bytes with NO further HTTP call', () async {
    final logo = Uint8List.fromList(utf8.encode('PNGLOGOBYTES'));
    final digest = hashOf(logo);
    var httpCalls = 0;
    final client = MockClient((req) async {
      httpCalls++;
      return http.Response.bytes(logo, 200);
    });
    final cache = BrandingAssetCache(cacheDir: tempDir, httpClient: client);

    // Initial get is a miss with no network.
    expect(await cache.get(digest), isNull);
    expect(httpCalls, 0);

    final fetched = await cache.fetchAndCache(
      role: 'logo',
      sha256: digest,
      jwt: 'jwt-token',
      apiBase: 'https://example.test',
    );
    expect(fetched, equals(logo));
    expect(httpCalls, 1);

    // Stored under the content hash (hash is the filename).
    final cachedFile = File('${tempDir.path}/$digest');
    expect(cachedFile.existsSync(), isTrue);
    expect(await cachedFile.readAsBytes(), equals(logo));

    // Subsequent get is a cache hit — no further HTTP call.
    expect(await cache.get(digest), equals(logo));
    expect(httpCalls, 1);
  });

  test('hash mismatch -> returns null, file NOT written', () async {
    final logo = Uint8List.fromList(utf8.encode('REALBYTES'));
    final wrongHash = hashOf(utf8.encode('SOMETHING-ELSE'));
    final client = MockClient((req) async => http.Response.bytes(logo, 200));
    final cache = BrandingAssetCache(cacheDir: tempDir, httpClient: client);

    final result = await cache.fetchAndCache(
      role: 'logo',
      sha256: wrongHash,
      jwt: 'jwt-token',
      apiBase: 'https://example.test',
    );
    expect(result, isNull);
    expect(File('${tempDir.path}/$wrongHash').existsSync(), isFalse);
    // Nothing cached under the (wrong) hash.
    expect(await cache.get(wrongHash), isNull);
  });

  test('get() for an uncached hash -> null (no fetch)', () async {
    var httpCalls = 0;
    final client = MockClient((req) async {
      httpCalls++;
      return http.Response.bytes(Uint8List(0), 200);
    });
    final cache = BrandingAssetCache(cacheDir: tempDir, httpClient: client);

    expect(await cache.get('deadbeef'), isNull);
    expect(httpCalls, 0);
  });

  test('fetchAndCache sends Authorization: Bearer <jwt> to '
      '<apiBase>/api/v1/sponsor/branding/asset/<role>', () async {
    final logo = Uint8List.fromList(utf8.encode('LOGO'));
    final digest = hashOf(logo);
    http.Request? captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response.bytes(logo, 200);
    });
    final cache = BrandingAssetCache(cacheDir: tempDir, httpClient: client);

    await cache.fetchAndCache(
      role: 'logo',
      sha256: digest,
      jwt: 'the-jwt',
      apiBase: 'https://example.test',
    );

    expect(captured, isNotNull);
    expect(captured!.method, 'GET');
    expect(
      captured!.url.toString(),
      'https://example.test/api/v1/sponsor/branding/asset/logo',
    );
    expect(captured!.headers['Authorization'], 'Bearer the-jwt');
  });
}
