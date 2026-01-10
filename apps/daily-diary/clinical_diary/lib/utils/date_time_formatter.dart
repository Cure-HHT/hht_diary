// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:intl/intl.dart';

/// Utility class for formatting and parsing ISO 8601 timestamps with timezone offsets.
///
/// Per spec/dev-data-models-jsonb.md, all timestamps must be in ISO 8601 format
/// with timezone offset embedded (e.g., "2025-10-15T14:30:00.000-05:00").
///
/// This preserves the user's local timezone at the time of entry, which is important
/// for clinical data to know when the event actually occurred in the user's context.
class DateTimeFormatter {
  DateTimeFormatter._();

  /// ISO 8601 base format without timezone (intl's ZZZZZ pattern doesn't work)
  static final DateFormat _iso8601Base = DateFormat(
    "yyyy-MM-dd'T'HH:mm:ss.SSS",
  );

  /// Format a DateTime to ISO 8601 string with timezone offset.
  ///
  /// Example output: "2025-10-15T14:30:00.000-05:00"
  ///
  /// The DateTime should be in local time. If it's in UTC, it will be
  /// formatted with +00:00 offset.
  ///
  /// Note: We manually build the timezone offset because Dart's intl package
  /// DateFormat does not actually output timezone information for any pattern
  /// (Z, ZZZZZ, z, etc.) - they all produce empty strings.
  static String format(DateTime dateTime) {
    final base = _iso8601Base.format(dateTime);
    final offset = dateTime.timeZoneOffset;
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final mins = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final sign = offset.isNegative ? '-' : '+';
    return '$base$sign$hours:$mins';
  }

  /// Parse an ISO 8601 string with timezone offset to DateTime.
  ///
  /// Accepts formats like:
  /// - "2025-10-15T14:30:00.000-05:00" (with offset)
  /// - "2025-10-15T14:30:00.000Z" (UTC)
  /// - "2025-10-15T14:30:00.000" (no offset, assumes local)
  ///
  /// Returns the DateTime in local time, preserving the original moment in time.
  static DateTime parse(String dateTimeString) {
    // DateTime.parse handles ISO 8601 with offsets correctly
    return DateTime.parse(dateTimeString).toLocal();
  }

  /// Parse an ISO 8601 string, returning null if parsing fails or input is null.
  static DateTime? tryParse(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return null;
    }
    try {
      return parse(dateTimeString);
    } catch (_) {
      return null;
    }
  }

  /// Extract the timezone offset string from an ISO 8601 formatted string.
  ///
  /// Example: "2025-10-15T14:30:00.000-05:00" returns "-05:00"
  /// Example: "2025-10-15T14:30:00.000Z" returns "Z"
  /// Example: "2025-10-15T14:30:00.000+00:00" returns "+00:00"
  ///
  /// Returns null if no timezone offset is found.
  static String? extractTimezoneOffset(String dateTimeString) {
    // Match timezone offset patterns at the end of the string
    // Patterns: Z, +HH:MM, -HH:MM, +HHMM, -HHMM
    final regex = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');
    final match = regex.firstMatch(dateTimeString);
    return match?.group(1);
  }

  /// Get a human-readable timezone abbreviation from offset.
  ///
  /// Example: "-05:00" might return "EST" or "CDT" depending on locale.
  /// Note: This is a simplified version - accurate timezone names require
  /// additional context (date for DST, location for name).
  static String getTimezoneAbbreviation(DateTime dateTime) {
    // Use intl's DateFormat to get the timezone abbreviation
    return DateFormat('z').format(dateTime);
  }

  /// Get the full timezone name for display.
  ///
  /// Example: Returns "Eastern Standard Time" or similar.
  static String getTimezoneName(DateTime dateTime) {
    return DateFormat('zzzz').format(dateTime);
  }
}
