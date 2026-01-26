// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00013: GDPR compliance - EU-only regions
//   REQ-d00041: Sponsor Role Mapping Schema
//
// Sponsor configuration handler - converted from Firebase sponsor.ts

import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'database.dart';

/// Available font options for sponsor configuration
enum FontOption { roboto, openDyslexic, atkinsonHyperlegible }

extension FontOptionName on FontOption {
  String get name {
    switch (this) {
      case FontOption.roboto:
        return 'Roboto';
      case FontOption.openDyslexic:
        return 'OpenDyslexic';
      case FontOption.atkinsonHyperlegible:
        return 'AtkinsonHyperlegible';
    }
  }
}

/// Feature flags structure
class SponsorFeatureFlags {
  final bool useReviewScreen;
  final bool useAnimations;
  final bool requireOldEntryJustification;
  final bool enableShortDurationConfirmation;
  final bool enableLongDurationConfirmation;
  final int longDurationThresholdMinutes;
  final List<String> availableFonts;

  const SponsorFeatureFlags({
    required this.useReviewScreen,
    required this.useAnimations,
    required this.requireOldEntryJustification,
    required this.enableShortDurationConfirmation,
    required this.enableLongDurationConfirmation,
    required this.longDurationThresholdMinutes,
    required this.availableFonts,
  });

  Map<String, dynamic> toJson() => {
    'useReviewScreen': useReviewScreen,
    'useAnimations': useAnimations,
    'requireOldEntryJustification': requireOldEntryJustification,
    'enableShortDurationConfirmation': enableShortDurationConfirmation,
    'enableLongDurationConfirmation': enableLongDurationConfirmation,
    'longDurationThresholdMinutes': longDurationThresholdMinutes,
    'availableFonts': availableFonts,
  };
}

/// Default feature flags
const _defaultFlags = SponsorFeatureFlags(
  useReviewScreen: false,
  useAnimations: true,
  requireOldEntryJustification: false,
  enableShortDurationConfirmation: false,
  enableLongDurationConfirmation: false,
  longDurationThresholdMinutes: 60,
  availableFonts: ['Roboto', 'OpenDyslexic', 'AtkinsonHyperlegible'],
);

/// Sponsor-specific configurations
/// In production, these would be stored in PostgreSQL
const _sponsorConfigs = <String, SponsorFeatureFlags>{
  'curehht': _defaultFlags,
  'callisto': SponsorFeatureFlags(
    useReviewScreen: false,
    useAnimations: true,
    requireOldEntryJustification: true,
    enableShortDurationConfirmation: true,
    enableLongDurationConfirmation: true,
    longDurationThresholdMinutes: 60,
    availableFonts: ['Roboto', 'OpenDyslexic', 'AtkinsonHyperlegible'],
  ),
};

/// Sponsor config handler
/// GET /api/v1/sponsor/config?sponsorId=curehht
Response sponsorConfigHandler(Request request) {
  if (request.method != 'GET') {
    return _jsonResponse({'error': 'Method not allowed'}, 405);
  }

  final sponsorId = request.url.queryParameters['sponsorId']
      ?.toLowerCase()
      .trim();

  if (sponsorId == null || sponsorId.isEmpty) {
    return _jsonResponse({'error': 'sponsorId parameter is required'}, 400);
  }

  final config = _sponsorConfigs[sponsorId];

  if (config == null) {
    // Return default flags for unknown sponsors
    return _jsonResponse({
      'sponsorId': sponsorId,
      'flags': _defaultFlags.toJson(),
      'isDefault': true,
    });
  }

  return _jsonResponse({
    'sponsorId': sponsorId,
    'flags': config.toJson(),
    'isDefault': false,
  });
}

Response _jsonResponse(Map<String, dynamic> data, [int statusCode = 200]) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Get role mappings for a sponsor
/// GET /api/v1/sponsor/roles?sponsorId=callisto
///
/// Returns the mapping from sponsor display names to system roles.
/// UI uses sponsor names, backend stores system roles.
Future<Response> sponsorRoleMappingsHandler(Request request) async {
  if (request.method != 'GET') {
    return _jsonResponse({'error': 'Method not allowed'}, 405);
  }

  final sponsorId = request.url.queryParameters['sponsorId']
      ?.toLowerCase()
      .trim();

  if (sponsorId == null || sponsorId.isEmpty) {
    return _jsonResponse({'error': 'sponsorId parameter is required'}, 400);
  }

  final db = Database.instance;

  try {
    // Exclude Developer Admin - it's a system role, not user-assignable
    const serviceContext = UserContext.service;
    final result = await db.executeWithContext(
      '''
      SELECT sponsor_role_name, mapped_role::text
      FROM sponsor_role_mapping
      WHERE sponsor_id = @sponsorId
        AND mapped_role != 'Developer Admin'
      ORDER BY sponsor_role_name
      ''',
      parameters: {'sponsorId': sponsorId},
      context: serviceContext,
    );

    final mappings = <Map<String, String>>[];
    for (final row in result) {
      mappings.add({
        'sponsorName': row[0] as String,
        'systemRole': row[1] as String,
      });
    }

    return _jsonResponse({'sponsorId': sponsorId, 'mappings': mappings});
  } catch (e) {
    return _jsonResponse({'error': 'Database error: $e'}, 500);
  }
}
