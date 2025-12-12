// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// Service for detecting and providing the device's current IANA timezone.
/// Detects timezone at startup and can be refreshed periodically.
class TimezoneService {
  TimezoneService._();

  static final TimezoneService _instance = TimezoneService._();
  static TimezoneService get instance => _instance;

  String? _currentTimezone;

  /// The device's current IANA timezone (e.g., "Europe/Paris", "America/New_York").
  /// Returns null if timezone detection hasn't completed or failed.
  String? get currentTimezone => _currentTimezone;

  /// Initialize the service by detecting the device's timezone.
  /// Should be called at app startup.
  Future<void> initialize() async {
    await refresh();
  }

  /// Refresh the timezone detection.
  /// Call this when the app resumes from background or periodically.
  Future<void> refresh() async {
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      _currentTimezone = _normalizeTimezone(tzInfo.identifier);
    } catch (e) {
      debugPrint('Failed to detect timezone: $e');
      // Keep existing value if refresh fails
    }
  }

  /// Normalize POSIX-style timezones to IANA format.
  /// Some platforms (iOS simulator) return POSIX format like "EST5EDT" instead
  /// of IANA format like "America/New_York".
  String _normalizeTimezone(String tz) {
    const posixToIana = {
      'EST5EDT': 'America/New_York',
      'CST6CDT': 'America/Chicago',
      'MST7MDT': 'America/Denver',
      'PST8PDT': 'America/Los_Angeles',
      'EST': 'America/New_York',
      'CST': 'America/Chicago',
      'MST': 'America/Denver',
      'PST': 'America/Los_Angeles',
      'CET': 'Europe/Paris',
      'CEST': 'Europe/Paris',
      'EET': 'Europe/Helsinki',
      'WET': 'Europe/Lisbon',
      'GMT': 'Europe/London',
    };
    return posixToIana[tz] ?? tz;
  }
}
