import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

/// Content-addressed local cache for *Sponsor* branding asset bytes.
///
/// The asset endpoint is JWT-gated (it requires `Authorization: Bearer <patient
/// session JWT>`), so the logo cannot be loaded with a plain `Image.network`.
/// The bytes are fetched programmatically with the session JWT, verified against
/// their expected content hash, and stored on-device keyed by that hash. The
/// hash IS the filename — a content-addressed store — so a given hash is fetched
/// at most once and served from the cache thereafter (offline-safe), and the
/// cache is retained for posterity after participation ends (it is never on the
/// local-data-reset delete list and lives outside the wiped store directory).
///
// Implements: DIARY-DEV-sponsor-branding-assets/A+B+C
class BrandingAssetCache {
  BrandingAssetCache({required Directory cacheDir, http.Client? httpClient})
    : _cacheDir = cacheDir,
      _httpClient = httpClient ?? http.Client();

  final Directory _cacheDir;
  final http.Client _httpClient;

  File _fileFor(String sha256Hex) => File('${_cacheDir.path}/$sha256Hex');

  /// Cache hit -> bytes; miss -> null. NEVER hits the network.
  // Implements: DIARY-DEV-sponsor-branding-assets/C
  Future<Uint8List?> get(String sha256Hex) async {
    try {
      final file = _fileFor(sha256Hex);
      if (file.existsSync()) {
        return await file.readAsBytes();
      }
    } catch (e, stack) {
      debugPrint('[BrandingAssetCache] get($sha256Hex) failed: $e\n$stack');
    }
    return null;
  }

  /// Fetch the branding asset for [role] from the JWT-gated endpoint, verify the
  /// bytes against [sha256], store them under the hash, and return them.
  ///
  /// On a hash mismatch (corrupted or substituted asset) this returns null and
  /// stores nothing — a verification failure is treated as a failed fetch so a
  /// tampered asset is never displayed and the caller falls back to the app
  /// default brand. Returns null on any network/HTTP error too.
  // Implements: DIARY-DEV-sponsor-branding-assets/A+B
  Future<Uint8List?> fetchAndCache({
    required String role,
    required String sha256,
    required String jwt,
    required String apiBase,
  }) async {
    final url = Uri.parse('$apiBase/api/v1/sponsor/branding/asset/$role');
    try {
      final response = await _httpClient.get(
        url,
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (response.statusCode != 200) {
        debugPrint(
          '[BrandingAssetCache] fetch($role) HTTP ${response.statusCode}',
        );
        return null;
      }
      final bytes = response.bodyBytes;
      final actual = sha256Lib.convert(bytes).toString();
      if (actual != sha256) {
        // Verification failure -> failed fetch; store nothing.
        debugPrint(
          '[BrandingAssetCache] hash mismatch for role=$role '
          '(expected $sha256, got $actual) — discarding',
        );
        return null;
      }
      await _cacheDir.create(recursive: true);
      await _fileFor(sha256).writeAsBytes(bytes, flush: true);
      return bytes;
    } catch (e, stack) {
      debugPrint('[BrandingAssetCache] fetch($role) failed: $e\n$stack');
      return null;
    }
  }
}

/// Alias for the `crypto` package's sha256 hasher, named to avoid colliding
/// with the `sha256` parameter on [BrandingAssetCache.fetchAndCache].
const Hash sha256Lib = sha256;
