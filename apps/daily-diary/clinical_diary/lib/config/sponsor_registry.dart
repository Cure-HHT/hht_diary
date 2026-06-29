// Sponsor registry for mapping linking code prefixes to backend URLs.
// Each sponsor has a unique 2-letter prefix (e.g., CA for Callisto).
// The mobile app uses this to determine which diary-server to connect to.
//
// Backend URL for the current deployment is provided by AppConfig.apiBase,
// which layers DIARY_API_BASE / BACKEND_URL overrides over the resolved
// EnvProfile. Single-tenant-per-sponsor: each deployment serves one sponsor,
// so apiBase is that sponsor's backend.
// TODO: Replace with central config service on cure-hht-admin GCP project
// so new sponsors can be added without app updates.

import 'package:clinical_diary/config/app_config.dart';

/// Exception thrown when sponsor lookup fails.
class SponsorRegistryException implements Exception {
  SponsorRegistryException(this.message);
  final String message;

  @override
  String toString() => 'SponsorRegistryException: $message';
}

/// Sponsor metadata for display purposes.
/// The backend URL for the active deployment is provided by AppConfig.apiBase.
class SponsorInfo {
  const SponsorInfo({required this.id, required this.name});

  final String id;
  final String name;
  String get logo => 'assets/sponsor-content/status_badge.png';
}

/// Registry of sponsors and their linking code prefixes.
///
/// The mobile app uses this to:
/// 1. Extract the 2-letter prefix from a linking code
/// 2. Validate the prefix identifies a known sponsor
/// 3. Route to AppConfig.apiBase (the active deployment's diary-server URL)
class SponsorRegistry {
  SponsorRegistry._();

  /// Sponsor metadata by prefix.
  /// The backend URL is provided by AppConfig.apiBase.
  static const _sponsors = <String, SponsorInfo>{
    'CA': SponsorInfo(id: 'callisto', name: 'Callisto'),
    // Add more sponsors here as they are onboarded:
    // 'OR': SponsorInfo(id: 'orion', name: 'Orion'),
  };

  /// Get sponsor info by prefix.
  /// Returns null if no sponsor matches the prefix.
  static SponsorInfo? getByPrefix(String prefix) {
    return _sponsors[prefix.toUpperCase()];
  }

  /// Get sponsor info by ID.
  /// Returns null if no sponsor matches the ID.
  static SponsorInfo? getById(String sponsorId) {
    final lowerId = sponsorId.toLowerCase();
    for (final entry in _sponsors.entries) {
      if (entry.value.id == lowerId) {
        return entry.value;
      }
    }
    return null;
  }

  /// Get the prefix for a sponsor ID.
  static String? getPrefixForId(String sponsorId) {
    final lowerId = sponsorId.toLowerCase();
    for (final entry in _sponsors.entries) {
      if (entry.value.id == lowerId) {
        return entry.key;
      }
    }
    return null;
  }

  /// Extract the 2-letter prefix from a linking code.
  /// Linking codes are 10 characters: 2-letter prefix + 8 random chars.
  /// Handles both formats: CAXXXXXXXX and CAXXX-XXXXX (with dash).
  static String extractPrefix(String code) {
    final normalized = code.toUpperCase().replaceAll('-', '').trim();
    if (normalized.length < 2) {
      throw SponsorRegistryException(
        'Linking code too short to extract prefix',
      );
    }
    return normalized.substring(0, 2);
  }

  /// Get the backend URL for a linking code.
  /// Validates the sponsor prefix, then returns the active backend
  /// (AppConfig.apiBase already layers DIARY_API_BASE / BACKEND_URL
  /// overrides over the resolved EnvProfile). Single-tenant-per-sponsor:
  /// each deployment serves one sponsor, so apiBase is that sponsor's backend.
  static String getBackendUrlForCode(String code) {
    final prefix = extractPrefix(code);
    final sponsor = getByPrefix(prefix);

    return AppConfig.apiBase;
  }

  /// Get all registered sponsor prefixes.
  static List<String> get allPrefixes => _sponsors.keys.toList();
}
