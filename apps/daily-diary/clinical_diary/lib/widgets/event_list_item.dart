// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00008: Mobile App Diary Entry

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/utils/date_time_formatter.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/nosebleed_intensity.dart';
import 'package:clinical_diary/widgets/timezone_picker.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// List item widget for displaying a nosebleed-related diary entry.
///
/// Reads directly from [DiaryEntry] (the materialized view row) rather than a
/// legacy intermediate model. The entry's `entryType` selects between the
/// "no nosebleeds" / "unknown" cards and the regular nosebleed card; for the
/// regular card the `currentAnswers` map supplies start/end time, intensity,
/// notes, and IANA timezone names.
///
/// Implements CUR-443: One-line history format with intensity icon.
class EventListItem extends StatelessWidget {
  const EventListItem({
    required this.entry,
    super.key,
    this.onTap,
    this.hasOverlap = false,
    this.highlightColor,
  });

  /// The materialized diary-entry row to render. Expected `entryType` values:
  /// `epistaxis_event`, `no_epistaxis_event`, or `unknown_day_event`.
  final DiaryEntry entry;
  final VoidCallback? onTap;

  /// Whether this entry overlaps with another entry's time range.
  final bool hasOverlap;

  /// Optional highlight color to apply to the card background (for flash animation)
  final Color? highlightColor;

  // --- Field accessors over entry.currentAnswers --------------------------

  bool get _isNoNosebleedsEvent => entry.entryType == 'no_epistaxis_event';
  bool get _isUnknownEvent => entry.entryType == 'unknown_day_event';
  bool get _isIncomplete => !entry.isComplete;

  DateTime get _startTime {
    final raw = entry.currentAnswers['startTime'];
    if (raw is String) return DateTimeFormatter.parse(raw);
    return entry.effectiveDate ?? entry.updatedAt;
  }

  DateTime? get _endTime {
    final raw = entry.currentAnswers['endTime'];
    if (raw is String) return DateTimeFormatter.parse(raw);
    return null;
  }

  NosebleedIntensity? get _intensity {
    final raw = entry.currentAnswers['intensity'];
    if (raw is String) return NosebleedIntensity.fromString(raw);
    return null;
  }

  String? get _startTimeTimezone {
    final raw = entry.currentAnswers['startTimeTimezone'];
    return raw is String ? raw : null;
  }

  String? get _endTimeTimezone {
    final raw = entry.currentAnswers['endTimeTimezone'];
    return raw is String ? raw : null;
  }

  /// Format start time for one-line display (e.g., "9:09 PM")
  /// CUR-597: Times are displayed in the event's timezone, not device timezone.
  /// If the event has a stored timezone, convert the stored time to that timezone.
  String _startTimeFormatted(String locale) {
    final stored = _startTime;
    final tz = _startTimeTimezone;
    final displayTime = tz != null
        ? TimezoneConverter.toDisplayedDateTime(stored, tz)
        : stored;
    return DateFormat.jm(locale).format(displayTime);
  }

  /// CUR-516: Get timezone display string if different from device TZ
  /// Returns null if timezone matches device TZ, otherwise returns abbreviation(s)
  /// CUR-597: Uses TimezoneService for device timezone to support test overrides.
  String? get _timezoneDisplay {
    final deviceTimezone =
        TimezoneService.instance.currentTimezone ?? DateTime.now().timeZoneName;
    final deviceTzAbbr = normalizeDeviceTimezone(deviceTimezone);
    final startTz = _startTimeTimezone;
    final endTz = _endTimeTimezone;

    // If no timezone info stored, don't show anything
    if (startTz == null && endTz == null) return null;

    final startAbbr = startTz != null
        ? getTimezoneAbbreviation(
            startTz,
            at: TimezoneConverter.toDisplayedDateTime(_startTime, startTz),
          )
        : null;
    final endAt = _endTime ?? _startTime;
    final endAbbr = endTz != null
        ? getTimezoneAbbreviation(
            endTz,
            at: TimezoneConverter.toDisplayedDateTime(endAt, endTz),
          )
        : null;

    final startDiffersFromDevice =
        startAbbr != null && startAbbr != deviceTzAbbr;
    final endDiffersFromDevice = endAbbr != null && endAbbr != deviceTzAbbr;
    final timezonesDiffer =
        startAbbr != null && endAbbr != null && startAbbr != endAbbr;

    if (!startDiffersFromDevice && !endDiffersFromDevice && !timezonesDiffer) {
      return null;
    }

    if (timezonesDiffer) {
      return '$startAbbr/$endAbbr';
    }
    if (startDiffersFromDevice) {
      return startAbbr;
    }
    if (endDiffersFromDevice) {
      return endAbbr;
    }
    return startAbbr ?? endAbbr;
  }

  /// Get the intensity icon image path
  String? get _intensityImagePath {
    final intensity = _intensity;
    if (intensity == null) return null;
    switch (intensity) {
      case NosebleedIntensity.spotting:
        return 'assets/images/intensity_spotting.png';
      case NosebleedIntensity.dripping:
        return 'assets/images/intensity_dripping.png';
      case NosebleedIntensity.drippingQuickly:
        return 'assets/images/intensity_dripping_quickly.png';
      case NosebleedIntensity.steadyStream:
        return 'assets/images/intensity_steady_stream.png';
      case NosebleedIntensity.pouring:
        return 'assets/images/intensity_pouring.png';
      case NosebleedIntensity.gushing:
        return 'assets/images/intensity_gushing.png';
    }
  }

  /// Check if the event crosses midnight (ends on a different day)
  bool get _isMultiDay {
    final end = _endTime;
    if (end == null) return false;
    final start = _startTime;

    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);

    return endDay.isAfter(startDay);
  }

  /// Calculate duration in minutes (null when no endTime).
  int? get _durationMinutes {
    final end = _endTime;
    if (end == null) return null;
    final start = _startTime;
    if (end.isBefore(start)) return null;
    return end.difference(start).inMinutes;
  }

  /// CUR-488: Show "Incomplete" for ongoing events (no end time set)
  /// Show minimum "1m" if start and end are the same (0 duration)
  /// Returns (text, isIncomplete) tuple for styling
  (String, bool) _getDurationInfo(AppLocalizations l10n) {
    final minutes = _durationMinutes;
    if (_endTime == null) {
      return (l10n.incomplete, true);
    }
    if (minutes == null) return ('', false);
    if (minutes == 0) return ('1m', false);
    if (minutes < 60) return ('${minutes}m', false);
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) return ('${hours}h', false);
    return ('${hours}h ${remainingMinutes}m', false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    if (_isNoNosebleedsEvent) {
      return _buildNoNosebleedsCard(context, l10n);
    }

    if (_isUnknownEvent) {
      return _buildUnknownCard(context, l10n);
    }

    return _buildNosebleedCard(context, l10n, locale);
  }

  /// Build card for "No nosebleed events" type
  Widget _buildNoNosebleedsCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.green.shade50,
      // CUR-488 Phase 2: Increased elevation for more visible shadows
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.noNosebleeds,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.translate('confirmedNoEvents'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: Colors.green.shade400),
            ],
          ),
        ),
      ),
    );
  }

  /// Build card for "Unknown" event type
  Widget _buildUnknownCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.yellow.shade50,
      // CUR-488 Phase 2: Increased elevation for more visible shadows
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(Icons.help_outline, color: Colors.orange.shade700, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.unknown,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.translate('unableToRecallEvents'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: Colors.orange.shade400),
            ],
          ),
        ),
      ),
    );
  }

  /// Build card for regular nosebleed events
  /// CUR-443: One-line format: "9:09 PM PST (icon) 1h 11m" with warning icon
  /// Fixed-width columns for alignment across rows
  /// CUR-488 Phase 2: Enhanced styling with better shadows, colors, and incomplete tint
  /// CUR-516: Show timezone when different from device TZ
  Widget _buildNosebleedCard(
    BuildContext context,
    AppLocalizations l10n,
    String locale,
  ) {
    // Fixed widths for column alignment
    // Time column: "12:59 AM" needs ~80px, 24h "23:59" needs ~45px
    final use24Hour = !DateFormat.jm(locale).pattern!.contains('a');
    final timeWidth = use24Hour ? 45.0 : 80.0;
    const iconWidth = 32.0;
    const durationWidth = 90.0;

    final (durationText, isIncompleteDuration) = _getDurationInfo(l10n);

    final cardColor =
        highlightColor ?? (_isIncomplete ? Colors.orange.shade50 : null);

    final timezoneText = _timezoneDisplay;
    final showTimezone = timezoneText != null;
    final cardHeight = showTimezone ? 52.0 : 40.0;

    return Card(
      margin: EdgeInsets.zero,
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: cardHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Start time - fixed width, right aligned
                SizedBox(
                  width: timeWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _startTimeFormatted(locale),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (showTimezone)
                        Text(
                          timezoneText,
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 10,
                              ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Intensity mini-icon - fixed width container with tight border
                SizedBox(
                  width: iconWidth,
                  child: _intensityImagePath != null
                      ? Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.5),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Image.asset(
                              _intensityImagePath!,
                              width: 28,
                              height: 28,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      : null,
                ),

                // Duration - fixed width with left padding
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: durationWidth,
                    child: Text(
                      durationText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isIncompleteDuration
                            ? Colors.orange.shade700
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isIncompleteDuration
                            ? FontWeight.w500
                            : null,
                        fontSize: isIncompleteDuration ? 12 : null,
                      ),
                    ),
                  ),
                ),

                // Spacer to push status indicators to the right
                Expanded(
                  child: _isMultiDay
                      ? Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            l10n.translate('plusOneDay'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // Incomplete indicator (compact)
                if (_isIncomplete) ...[
                  Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                ],

                // Overlap warning icon
                if (hasOverlap) ...[
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 24,
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(width: 8),
                ],

                // Chevron
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
