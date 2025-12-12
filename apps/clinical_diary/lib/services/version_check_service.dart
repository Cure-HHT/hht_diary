// IMPLEMENTS REQUIREMENTS:
//   REQ-d00006: Mobile App Build and Release Process

import 'dart:convert';

import 'package:clinical_diary/utils/app_version.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Type of update available
enum UpdateType {
  /// No update needed
  none,

  /// Optional update available (current version >= minVersion)
  optional,

  /// Required update (current version < minVersion)
  required,
}

/// Result of version check
class VersionCheckResult {
  const VersionCheckResult({
    required this.updateType,
    this.remoteVersion,
    this.localVersion,
    this.releaseNotes,
  });

  final UpdateType updateType;
  final String? remoteVersion;
  final String? localVersion;
  final String? releaseNotes;

  /// Whether any update is available
  bool get hasUpdate => updateType != UpdateType.none;

  /// Whether update is required (blocks app usage)
  bool get isRequired => updateType == UpdateType.required;
}

/// Remote version info from version.json
class VersionInfo {
  const VersionInfo({
    required this.version,
    this.minVersion,
    this.releaseNotes,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      version: json['version'] as String? ?? '',
      minVersion: json['minVersion'] as String?,
      releaseNotes: json['releaseNotes'] as String?,
    );
  }

  final String version;
  final String? minVersion;
  final String? releaseNotes;
}

/// Service for checking app version updates
///
/// Checks remote version.json against local app version and determines
/// if an update is available or required.
class VersionCheckService {
  VersionCheckService({this.versionUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// URL to fetch version.json from. Defaults to relative path on web.
  final String? versionUrl;

  final http.Client _httpClient;

  static const String _lastCheckKey = 'version_check_last_time';
  static const String _dismissedVersionKey = 'version_check_dismissed_version';
  static const Duration _checkInterval = Duration(hours: 24);

  /// Fetch remote version info from version.json
  ///
  /// Uses cache-busting query parameter to ensure fresh data.
  Future<VersionInfo?> fetchRemoteVersion() async {
    try {
      final url = _getVersionUrl();
      // Add cache-busting query parameter
      final cacheBustUrl = url.contains('?')
          ? '$url&t=${DateTime.now().millisecondsSinceEpoch}'
          : '$url?t=${DateTime.now().millisecondsSinceEpoch}';

      final response = await _httpClient.get(
        Uri.parse(cacheBustUrl),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return VersionInfo.fromJson(data);
      }
    } catch (e) {
      debugPrint('VersionCheckService: Failed to fetch remote version: $e');
    }
    return null;
  }

  /// Get the local app version
  ///
  /// On web, uses the version embedded at build time via dart-define.
  /// This is immune to browser caching issues.
  /// On native platforms, uses package_info_plus.
  Future<String> getLocalVersion() async {
    // On web, use the embedded version constant to avoid reading from
    // potentially cached version.json (which package_info_plus does).
    if (kIsWeb) {
      return appVersion;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      debugPrint('VersionCheckService: Failed to get local version: $e');
      return '0.0.0';
    }
  }

  /// Check if an update is available
  ///
  /// Compares local version against remote version.json and returns
  /// the type of update available (none, optional, or required).
  Future<VersionCheckResult> checkForUpdate() async {
    final localVersion = await getLocalVersion();
    final remoteInfo = await fetchRemoteVersion();

    if (remoteInfo == null) {
      return VersionCheckResult(
        updateType: UpdateType.none,
        localVersion: localVersion,
      );
    }

    return compareVersions(
      local: localVersion,
      remote: remoteInfo.version,
      minVersion: remoteInfo.minVersion,
      releaseNotes: remoteInfo.releaseNotes,
    );
  }

  /// Compare local version against remote version
  ///
  /// Returns [UpdateType.required] if local < minVersion
  /// Returns [UpdateType.optional] if local < remote but >= minVersion
  /// Returns [UpdateType.none] if local >= remote
  VersionCheckResult compareVersions({
    required String local,
    required String remote,
    String? minVersion,
    String? releaseNotes,
  }) {
    final localParsed = _parseVersion(local);
    final remoteParsed = _parseVersion(remote);

    // Check if update is required (below minimum version)
    if (minVersion != null) {
      final minParsed = _parseVersion(minVersion);
      if (_compareVersionTuples(localParsed, minParsed) < 0) {
        return VersionCheckResult(
          updateType: UpdateType.required,
          remoteVersion: remote,
          localVersion: local,
          releaseNotes: releaseNotes,
        );
      }
    }

    // Check if optional update available
    if (_compareVersionTuples(localParsed, remoteParsed) < 0) {
      return VersionCheckResult(
        updateType: UpdateType.optional,
        remoteVersion: remote,
        localVersion: local,
        releaseNotes: releaseNotes,
      );
    }

    return VersionCheckResult(
      updateType: UpdateType.none,
      localVersion: local,
      remoteVersion: remote,
    );
  }

  /// Check if enough time has passed since last version check
  Future<bool> shouldCheckForUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastCheckKey);

      if (lastCheck == null) {
        return true;
      }

      final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheck);
      return DateTime.now().difference(lastCheckTime) >= _checkInterval;
    } catch (e) {
      debugPrint('VersionCheckService: Failed to check interval: $e');
      return true;
    }
  }

  /// Record the current time as last check time
  Future<void> recordCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('VersionCheckService: Failed to record check time: $e');
    }
  }

  /// Check if user has dismissed this specific version
  Future<bool> isVersionDismissed(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getString(_dismissedVersionKey);
      return dismissed == version;
    } catch (e) {
      return false;
    }
  }

  /// Mark a version as dismissed by the user
  Future<void> dismissVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedVersionKey, version);
    } catch (e) {
      debugPrint('VersionCheckService: Failed to dismiss version: $e');
    }
  }

  /// Clear dismissed version (for testing or after update)
  Future<void> clearDismissedVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dismissedVersionKey);
    } catch (e) {
      debugPrint('VersionCheckService: Failed to clear dismissed: $e');
    }
  }

  /// Get the URL for version.json
  String _getVersionUrl() {
    if (versionUrl != null) {
      return versionUrl!;
    }

    // On web, use relative URL resolved from base
    if (kIsWeb) {
      // This will be resolved relative to the app's base URL
      return 'version.json';
    }

    // For native apps testing, you'd need to provide a full URL
    // In production, this would come from app config
    return 'https://your-app-domain.com/version.json';
  }

  /// Parse version string into tuple of integers
  ///
  /// Handles versions like "1.2.3" or "1.2.3+45"
  List<int> _parseVersion(String version) {
    // Remove build number if present (e.g., "1.2.3+45" -> "1.2.3")
    final versionOnly = version.split('+').first;

    return versionOnly.split('.').map((part) {
      return int.tryParse(part) ?? 0;
    }).toList();
  }

  /// Compare two version tuples
  ///
  /// Returns negative if a < b, zero if a == b, positive if a > b
  int _compareVersionTuples(List<int> a, List<int> b) {
    final maxLength = a.length > b.length ? a.length : b.length;

    for (var i = 0; i < maxLength; i++) {
      final aVal = i < a.length ? a[i] : 0;
      final bVal = i < b.length ? b[i] : 0;

      if (aVal < bVal) return -1;
      if (aVal > bVal) return 1;
    }

    return 0;
  }
}
