// IMPLEMENTS REQUIREMENTS:
//   REQ-d00102: Display full sponsor branding

// Client-side service for fetching sponsor branding configuration.

import 'dart:convert';

import 'package:clinical_diary/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Sponsor branding configuration returned by GET /api/v1/sponsor/branding.
class SponsorBrandingConfig {
  const SponsorBrandingConfig({
    required this.sponsorId,
    required this.title,
    required this.assetBaseUrl,
  });

  factory SponsorBrandingConfig.fromJson(Map<String, dynamic> json) {
    return SponsorBrandingConfig(
      sponsorId: json['sponsorId'] as String? ?? '',
      title: json['title'] as String? ?? 'Clinical Trial',
      assetBaseUrl: json['assetBaseUrl'] as String? ?? '',
    );
  }
  final String sponsorId;
  final String title;
  final String assetBaseUrl;

  /// Fallback branding when config is unavailable.
  static const fallback = SponsorBrandingConfig(
    sponsorId: '',
    title: 'Clinical Trial ',
    assetBaseUrl: '',
  );

  /// Convention-based URL for the app logo.
  String? get appLogoUrl {
    if (assetBaseUrl.isEmpty) return null;
    return '${AppConfig.apiBase}$assetBaseUrl/mobile/assets/images/app_logo.png';
  }

  bool get hasLogo => appLogoUrl != null;
}

/// Exception for branding config fetch failures.
class SponsorBrandingException implements Exception {
  SponsorBrandingException(this.message, {this.statusCode, this.cause});
  final String message;
  final int? statusCode;
  final Object? cause;

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
  SponsorBrandingService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();
  final http.Client _httpClient;

  String get _apiBaseUrl {
    return AppConfig.apiBase;
  }

  /// Fetch sponsor branding from server.
  Future<SponsorBrandingConfig> fetchBranding(String sponsorId) async {
    final url = '$_apiBaseUrl/api/v1/sponsor/branding/$sponsorId';
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
