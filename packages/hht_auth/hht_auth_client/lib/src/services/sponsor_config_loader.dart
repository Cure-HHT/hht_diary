/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00084: Sponsor Configuration Loading
///
/// Sponsor configuration loading service.
///
/// After authentication, fetches sponsor-specific configuration directly from
/// the Sponsor Portal using the sponsorUrl provided in the auth token.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hht_auth_core/hht_auth_core.dart';

/// Service for loading sponsor-specific configuration from the Sponsor Portal.
///
/// After authentication, the auth token contains a `sponsorUrl` which points
/// to the sponsor's portal. This service fetches branding and configuration
/// directly from that portal.
class SponsorConfigLoader {
  final http.Client _httpClient;

  // In-memory cache (cleared on logout)
  final Map<String, SponsorConfig> _cache = {};

  /// Creates a loader with the given HTTP client.
  ///
  /// The HTTP client is used to fetch configuration from the Sponsor Portal.
  SponsorConfigLoader(this._httpClient);

  /// Creates a loader with a default HTTP client.
  factory SponsorConfigLoader.create() {
    return SponsorConfigLoader(http.Client());
  }

  /// Loads sponsor configuration from the Sponsor Portal.
  ///
  /// Uses the `sponsorUrl` from the auth token to fetch configuration
  /// from the portal's `/api/diary/config` endpoint.
  ///
  /// Caches the result in memory for subsequent calls.
  /// Falls back to default configuration if the fetch fails.
  Future<SponsorConfig> loadConfig(AuthToken token) async {
    // Check cache first
    if (_cache.containsKey(token.sponsorId)) {
      return _cache[token.sponsorId]!;
    }

    try {
      // Fetch from Sponsor Portal
      final configUrl = Uri.parse('${token.sponsorUrl}/api/diary/config');
      final response = await _httpClient.get(configUrl);

      if (response.statusCode != 200) {
        // Fall back to defaults if portal returns error
        return _createAndCacheDefaults(token);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final config = SponsorConfig.fromJson(json);

      // Cache for future use
      _cache[token.sponsorId] = config;

      return config;
    } catch (e) {
      // Fall back to defaults if fetch fails (network error, parse error, etc.)
      return _createAndCacheDefaults(token);
    }
  }

  /// Creates default config and caches it.
  SponsorConfig _createAndCacheDefaults(AuthToken token) {
    final config = SponsorConfig.defaults(sponsorId: token.sponsorId);
    _cache[token.sponsorId] = config;
    return config;
  }

  /// Loads sponsor configuration by sponsor URL directly.
  ///
  /// This variant is useful when you have the portal URL but not a full token.
  /// Falls back to defaults if the fetch fails.
  Future<SponsorConfig> loadConfigFromUrl({
    required String sponsorId,
    required String sponsorUrl,
  }) async {
    // Check cache first
    if (_cache.containsKey(sponsorId)) {
      return _cache[sponsorId]!;
    }

    try {
      final configUrl = Uri.parse('$sponsorUrl/api/diary/config');
      final response = await _httpClient.get(configUrl);

      if (response.statusCode != 200) {
        return _createAndCacheDefaultsForId(sponsorId);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final config = SponsorConfig.fromJson(json);

      _cache[sponsorId] = config;
      return config;
    } catch (e) {
      return _createAndCacheDefaultsForId(sponsorId);
    }
  }

  /// Creates default config for sponsorId and caches it.
  SponsorConfig _createAndCacheDefaultsForId(String sponsorId) {
    final config = SponsorConfig.defaults(sponsorId: sponsorId);
    _cache[sponsorId] = config;
    return config;
  }

  /// Clears the configuration cache.
  void clearCache() {
    _cache.clear();
  }

  /// Checks if config is cached for sponsor.
  bool isCached(String sponsorId) {
    return _cache.containsKey(sponsorId);
  }

  /// Closes the HTTP client.
  ///
  /// Call this when the loader is no longer needed.
  void dispose() {
    _httpClient.close();
  }
}
