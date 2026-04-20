// CUR-583: Timezone conversion utilities for cross-timezone time entry
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/widgets/timezone_picker.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Utility class for converting between displayed time (in a specific timezone)
/// and stored DateTime (adjusted for correct UTC representation).
///
/// When a user selects a time like "8:11 PM" with timezone "CET", we need to
/// store a DateTime that correctly represents that moment in time. Since Dart's
/// DateTime doesn't carry timezone info, we adjust the DateTime value so that
/// when stored/transmitted, it represents the correct UTC moment.
///
/// Uses the IANA timezone database (via `package:timezone`) for DST-aware
/// offset calculations. Falls back to static offsets from [commonTimezones]
/// if a timezone ID is not found in the database.
class TimezoneConverter {
  /// Test-only override for device timezone offset.
  /// Set this in tests to ensure consistent behavior regardless of machine timezone.
  /// Set to null to use actual device timezone.
  static int? testDeviceOffsetMinutes;

  /// Ensure the IANA timezone database is initialized. Safe to call multiple times.
  /// initializeTimeZones() is idempotent — the package tracks its own init state.
  static void ensureInitialized() {
    tz_data.initializeTimeZones();
  }

  /// Get UTC offset in minutes for a timezone, accounting for DST.
  ///
  /// Uses the IANA timezone database to compute the actual offset at a given
  /// moment, including Daylight Saving Time adjustments.
  ///
  /// [at] Optional reference time whose date/time components are interpreted
  /// as wall-clock time in the target timezone (used to determine DST state).
  /// Defaults to the current moment.
  /// Returns null if timezone is not found.
  static int? getTimezoneOffsetMinutes(String? ianaId, {DateTime? at}) {
    if (ianaId == null) return null;
    ensureInitialized();
    try {
      final location = tz.getLocation(ianaId);
      final tzDateTime = at != null
          ? tz.TZDateTime(
              location,
              at.year,
              at.month,
              at.day,
              at.hour,
              at.minute,
              at.second,
            )
          : tz.TZDateTime.now(location);
      return tzDateTime.timeZoneOffset.inMinutes;
    } catch (_) {
      // Fallback to static list if IANA ID not in timezone database
      final entry = commonTimezones
          .where((e) => e.ianaId == ianaId)
          .firstOrNull;
      return entry?.utcOffsetMinutes;
    }
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
  /// The DST offset is determined at the displayed time, ensuring correct
  /// conversion even near DST transitions.
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
    final timezoneOffset = getTimezoneOffsetMinutes(
      timezone,
      at: displayedDateTime,
    );
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
  /// Formula: displayedDateTime = storedDateTime + (timezoneOffset - deviceOffset)
  ///
  /// Uses a two-pass DST lookup to handle the "fall back" ambiguity: Pass 1
  /// approximates the display time using the stored (device-local) time as a
  /// DST reference; Pass 2 refines the offset using that approximate display
  /// time, which is already in target-TZ wall-clock terms. One iteration is
  /// always sufficient because the two DST states differ by at most 1 hour.
  static DateTime toDisplayedDateTime(
    DateTime storedDateTime,
    String? timezone, {
    int? deviceOffsetMinutes,
  }) {
    // Pass 1: approximate timezone offset using stored (device-local) time as
    // reference. Accurate in all cases except the ±1h ambiguous window at
    // "fall back" DST transitions, where stored (device-local) may have a
    // different DST state than the target timezone's local wall-clock time.
    final approxOffset = getTimezoneOffsetMinutes(timezone, at: storedDateTime);
    if (approxOffset == null) {
      // No timezone or unknown, use as-is
      return storedDateTime;
    }

    final deviceOffset = deviceOffsetMinutes ?? getDeviceOffsetMinutes();
    final approxDisplayed = storedDateTime.add(
      Duration(minutes: approxOffset - deviceOffset),
    );

    // Pass 2: re-lookup DST using the approximate display time, which is now
    // expressed in target-TZ wall-clock terms. This resolves the "fall back"
    // ambiguity — one iteration is always sufficient because the two results
    // differ by at most 1 hour.
    final timezoneOffset =
        getTimezoneOffsetMinutes(timezone, at: approxDisplayed) ?? approxOffset;

    return storedDateTime.add(Duration(minutes: timezoneOffset - deviceOffset));
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
