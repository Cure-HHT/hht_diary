// IMPLEMENTS REQUIREMENTS:
//   REQ-p00009: Sponsor-Specific Web Portals
//   REQ-d00005: Sponsor Configuration Detection Implementation
//
// Client-side service for fetching sponsor branding configuration.
// Mirrors the pattern of identity_config_service.dart.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Sponsor branding configuration returned by GET /api/v1/sponsor/branding.
class SponsorBrandingConfig {
  final String sponsorId;
  final String title;
  final String assetBaseUrl;

  const SponsorBrandingConfig({
    required this.sponsorId,
    required this.title,
    required this.assetBaseUrl,
  });

  /// Fallback branding when config is unavailable.
  static const fallback = SponsorBrandingConfig(
    sponsorId: '',
    title: 'Clinical Trial Portal',
    assetBaseUrl: '',
  );

  factory SponsorBrandingConfig.fromJson(Map<String, dynamic> json) {
    return SponsorBrandingConfig(
      sponsorId: json['sponsorId'] as String? ?? '',
      title: json['title'] as String? ?? 'Clinical Trial Portal',
      assetBaseUrl: json['assetBaseUrl'] as String? ?? '',
    );
  }

  /// Convention-based URL for the portal app logo.
  String? get appLogoUrl {
    if (assetBaseUrl.isEmpty) return null;
    return '$assetBaseUrl/portal/assets/images/app_logo.png';
  }

  bool get hasLogo => appLogoUrl != null;
}

/// Exception for branding config fetch failures.
class SponsorBrandingException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;

  SponsorBrandingException(this.message, {this.statusCode, this.cause});

  @override
  String toString() {
    if (statusCode != null) {
      return 'SponsorBrandingException: $message (status: $statusCode)';
    }
    return 'SponsorBrandingException: $message';
  }
}

/// Service for fetching sponsor branding from the server.
class SponsorBrandingService {
  final http.Client _httpClient;

  SponsorBrandingService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  String get _apiBaseUrl {
    const envUrl = String.fromEnvironment('PORTAL_API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kDebugMode) return 'http://localhost:8080';
    return Uri.base.origin;
  }

  /// Fetch sponsor branding from server.
  Future<SponsorBrandingConfig> fetchBranding() async {
    final url = '$_apiBaseUrl/api/v1/sponsor/branding';
    debugPrint('[SponsorBrandingService] Fetching branding from: $url');

    try {
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 503) {
        debugPrint('[SponsorBrandingService] Server returned 503');
        throw SponsorBrandingException(
          'Sponsor branding not configured on server',
          statusCode: 503,
        );
      }

      if (response.statusCode != 200) {
        throw SponsorBrandingException(
          'Failed to fetch sponsor branding',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final config = SponsorBrandingConfig.fromJson(json);

      debugPrint('[SponsorBrandingService] Branding loaded: ${config.title}');
      return config;
    } on SponsorBrandingException {
      rethrow;
    } catch (e) {
      debugPrint('[SponsorBrandingService] Error: $e');
      throw SponsorBrandingException(
        'Network error while fetching branding',
        cause: e,
      );
    }
  }
}
