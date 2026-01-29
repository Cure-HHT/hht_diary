// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-d00078: Linking Code Validation
//
// Sponsor registry for mapping linking code prefixes to backend URLs.
// Each sponsor has a unique 2-letter prefix (e.g., CA for Callisto).
// The mobile app uses this to determine which diary-server to connect to.

import 'package:clinical_diary/flavors.dart';

/// Registry entry for a sponsor's backend configuration.
class SponsorBackend {
  const SponsorBackend({
    required this.sponsorId,
    required this.prefix,
    required this.name,
    required this.backendUrls,
  });

  /// Unique sponsor identifier (e.g., 'callisto')
  final String sponsorId;

  /// 2-letter code prefix (e.g., 'CA')
  final String prefix;

  /// Human-readable sponsor name
  final String name;

  /// Backend URLs per flavor/environment
  final Map<Flavor, String> backendUrls;

  /// Get the backend URL for the current flavor
  String getBackendUrl(Flavor flavor) {
    final url = backendUrls[flavor];
    if (url == null) {
      throw SponsorRegistryException(
        'No backend URL configured for sponsor $sponsorId in $flavor environment',
      );
    }
    return url;
  }
}

/// Exception thrown when sponsor lookup fails.
class SponsorRegistryException implements Exception {
  SponsorRegistryException(this.message);
  final String message;

  @override
  String toString() => 'SponsorRegistryException: $message';
}

/// Registry of all sponsors and their backend configurations.
///
/// The mobile app uses this to:
/// 1. Extract the 2-letter prefix from a linking code
/// 2. Look up the corresponding sponsor's diary-server URL
/// 3. Call the /api/v1/user/link endpoint on that server
///
/// New sponsors are added here when onboarded to the platform.
class SponsorRegistry {
  SponsorRegistry._();

  /// All registered sponsors.
  /// Add new sponsors here as they are onboarded.
  static const _sponsors = <SponsorBackend>[
    // Callisto (CA) - First sponsor
    SponsorBackend(
      sponsorId: 'callisto',
      prefix: 'CA',
      name: 'Callisto Pharmaceuticals',
      backendUrls: {
        // Cloud Run URLs per environment
        // TODO: Update qa/uat/prod URLs when deployed
        Flavor.dev: 'https://patient-server-1012274191696.europe-west9.run.app',
        Flavor.qa: 'https://patient-server-qa-PROJECTID.europe-west9.run.app',
        Flavor.uat: 'https://patient-server-uat-PROJECTID.europe-west9.run.app',
        Flavor.prod: 'https://patient-server-PROJECTID.europe-west9.run.app',
      },
    ),
    // Add more sponsors here as they are onboarded:
    // SponsorBackend(
    //   sponsorId: 'orion',
    //   prefix: 'OR',
    //   name: 'Orion Therapeutics',
    //   backendUrls: { ... },
    // ),
  ];

  /// Look up a sponsor by their linking code prefix.
  /// Returns null if no sponsor matches the prefix.
  static SponsorBackend? getByPrefix(String prefix) {
    final upperPrefix = prefix.toUpperCase();
    for (final sponsor in _sponsors) {
      if (sponsor.prefix == upperPrefix) {
        return sponsor;
      }
    }
    return null;
  }

  /// Look up a sponsor by their ID.
  /// Returns null if no sponsor matches the ID.
  static SponsorBackend? getById(String sponsorId) {
    final lowerId = sponsorId.toLowerCase();
    for (final sponsor in _sponsors) {
      if (sponsor.sponsorId == lowerId) {
        return sponsor;
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

  /// Get the backend URL for a linking code in the current flavor.
  /// Extracts the prefix and looks up the corresponding sponsor.
  static String getBackendUrlForCode(String code, Flavor flavor) {
    final prefix = extractPrefix(code);
    final sponsor = getByPrefix(prefix);
    if (sponsor == null) {
      throw SponsorRegistryException(
        'Unknown sponsor prefix: $prefix. '
        'Please check your linking code or contact support.',
      );
    }
    return sponsor.getBackendUrl(flavor);
  }

  /// Get all registered sponsor prefixes.
  static List<String> get allPrefixes =>
      _sponsors.map((s) => s.prefix).toList();
}
