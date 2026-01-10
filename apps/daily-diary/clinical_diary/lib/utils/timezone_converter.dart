// CUR-583: Timezone conversion utilities for cross-timezone time entry
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/widgets/timezone_picker.dart';

/// Utility class for converting between displayed time (in a specific timezone)
/// and stored DateTime (adjusted for correct UTC representation).
///
/// When a user selects a time like "8:11 PM" with timezone "CET", we need to
/// store a DateTime that correctly represents that moment in time. Since Dart's
/// DateTime doesn't carry timezone info, we adjust the DateTime value so that
/// when stored/transmitted, it represents the correct UTC moment.
class TimezoneConverter {
  /// Test-only override for device timezone offset.
  /// Set this in tests to ensure consistent behavior regardless of machine timezone.
  /// Set to null to use actual device timezone.
  static int? testDeviceOffsetMinutes;

  /// Get UTC offset in minutes for a timezone from commonTimezones list.
  /// Returns null if timezone is not found.
  static int? getTimezoneOffsetMinutes(String? ianaId) {
    if (ianaId == null) return null;
    final entry = commonTimezones
        .where((tz) => tz.ianaId == ianaId)
        .firstOrNull;
    return entry?.utcOffsetMinutes;
  }

  /// Get the current device timezone offset in minutes.
  /// Uses [testDeviceOffsetMinutes] if set, otherwise actual device timezone.
  static int getDeviceOffsetMinutes() {
    return testDeviceOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes;
  }

  /// Convert displayed time/date/timezone into a stored DateTime.
  ///
  /// The displayed time is what the user sees on the clock (e.g., "8:11 PM").
  /// The timezone is the IANA timezone ID (e.g., "Europe/Paris").
  /// The returned DateTime is adjusted so it represents the correct UTC moment.
  ///
  /// Formula: storedDateTime = displayedDateTime + (deviceOffset - timezoneOffset)
  ///
  /// Example: User sees 8:11 PM CET on Dec 18, device is in EST
  /// - deviceOffset = -300 (EST = UTC-5)
  /// - timezoneOffset = +60 (CET = UTC+1)
  /// - adjustment = -300 - 60 = -360 minutes
  /// - storedDateTime = Dec 18, 8:11 PM + (-360 min) = Dec 18, 2:11 PM
  /// - This Dec 18, 2:11 PM (device local) represents Dec 18, 8:11 PM CET
  static DateTime toStoredDateTime(
    DateTime displayedDateTime,
    String? timezone, {
    int? deviceOffsetMinutes,
  }) {
    final timezoneOffset = getTimezoneOffsetMinutes(timezone);
    if (timezoneOffset == null) {
      // No timezone or unknown, use as-is
      return displayedDateTime;
    }

    final deviceOffset = deviceOffsetMinutes ?? getDeviceOffsetMinutes();
    final adjustment = deviceOffset - timezoneOffset;

    return displayedDateTime.add(Duration(minutes: adjustment));
  }

  /// Convert stored DateTime back to displayed time for a specific timezone.
  ///
  /// This is the reverse of [toStoredDateTime]. Takes a stored DateTime
  /// (adjusted for UTC correctness) and returns what should be displayed
  /// to the user in the specified timezone.
  ///
  /// Formula: displayedDateTime = storedDateTime - (deviceOffset - timezoneOffset)
  ///        = storedDateTime + (timezoneOffset - deviceOffset)
  static DateTime toDisplayedDateTime(
    DateTime storedDateTime,
    String? timezone, {
    int? deviceOffsetMinutes,
  }) {
    final timezoneOffset = getTimezoneOffsetMinutes(timezone);
    if (timezoneOffset == null) {
      // No timezone or unknown, use as-is
      return storedDateTime;
    }

    final deviceOffset = deviceOffsetMinutes ?? getDeviceOffsetMinutes();
    // Reverse the adjustment
    final reverseAdjustment = timezoneOffset - deviceOffset;

    return storedDateTime.add(Duration(minutes: reverseAdjustment));
  }

  /// Recalculate stored DateTime when timezone changes.
  ///
  /// When the user changes timezone (e.g., from EST to CET) while keeping
  /// the same displayed time (e.g., 8:11 PM), the stored DateTime needs
  /// to be recalculated.
  ///
  /// This first converts the stored DateTime back to displayed time using
  /// the old timezone, then converts to stored DateTime using the new timezone.
  static DateTime recalculateForTimezoneChange(
    DateTime storedDateTime,
    String? oldTimezone,
    String newTimezone, {
    int? deviceOffsetMinutes,
  }) {
    // Get displayed time using old timezone
    final displayedDateTime = toDisplayedDateTime(
      storedDateTime,
      oldTimezone,
      deviceOffsetMinutes: deviceOffsetMinutes,
    );

    // Convert to stored time using new timezone
    return toStoredDateTime(
      displayedDateTime,
      newTimezone,
      deviceOffsetMinutes: deviceOffsetMinutes,
    );
  }
}
