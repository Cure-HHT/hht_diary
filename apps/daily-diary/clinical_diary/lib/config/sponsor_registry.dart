// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-d00078: Linking Code Validation
//
// Sponsor registry for mapping linking code prefixes to backend URLs.
// Each sponsor has a unique 2-letter prefix (e.g., CA for Callisto).
// The mobile app uses this to determine which diary-server to connect to.
//
// Backend URLs are configured in FlavorConfig (lib/flavors.dart).
// TODO: Replace with central config service on cure-hht-admin GCP project
// so new sponsors can be added without app updates.

import 'package:clinical_diary/flavors.dart';

/// Exception thrown when sponsor lookup fails.
class SponsorRegistryException implements Exception {
  SponsorRegistryException(this.message);
  final String message;

  @override
  String toString() => 'SponsorRegistryException: $message';
}

/// Sponsor metadata for display purposes.
/// Backend URLs are in FlavorConfig.sponsorBackends.
class SponsorInfo {
  const SponsorInfo({required this.id, required this.name});

  final String id;
  final String name;
}

/// Registry of sponsors and their linking code prefixes.
///
/// The mobile app uses this to:
/// 1. Extract the 2-letter prefix from a linking code
/// 2. Look up the corresponding sponsor's diary-server URL from FlavorConfig
/// 3. Call the /api/v1/user/link endpoint on that server
class SponsorRegistry {
  SponsorRegistry._();

  /// Sponsor metadata by prefix.
  /// Backend URLs are in FlavorConfig.sponsorBackends.
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

  /// Get the backend URL for a linking code in the given flavor.
  /// Extracts the prefix and looks up the URL from FlavorConfig.
  static String getBackendUrlForCode(String code, Flavor flavor) {
    final prefix = extractPrefix(code);

    // Validate sponsor exists
    final sponsor = getByPrefix(prefix);
    if (sponsor == null) {
      throw SponsorRegistryException(
        'Unknown sponsor prefix: $prefix. '
        'Please check your linking code or contact support.',
      );
    }

    // Get URL from flavor config
    final flavorConfig = FlavorConfig.byName(flavor.name);
    final url = flavorConfig.sponsorBackends[prefix];
    if (url == null) {
      throw SponsorRegistryException(
        'No backend URL configured for sponsor ${sponsor.name} '
        'in ${flavor.name} environment.',
      );
    }

    return url;
  }

  /// Get all registered sponsor prefixes.
  static List<String> get allPrefixes => _sponsors.keys.toList();
}
