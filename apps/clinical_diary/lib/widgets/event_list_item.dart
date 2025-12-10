// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00008: Mobile App Diary Entry

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// List item widget for displaying a nosebleed event
/// Implements CUR-443: One-line history format with intensity icon
class EventListItem extends StatelessWidget {
  const EventListItem({
    required this.record,
    super.key,
    this.onTap,
    this.hasOverlap = false,
    this.highlightColor,
  });
  final NosebleedRecord record;
  final VoidCallback? onTap;

  /// Whether this record overlaps with another record's time range
  final bool hasOverlap;

  /// Optional highlight color to apply to the card background (for flash animation)
  final Color? highlightColor;

  /// Format start time for one-line display (e.g., "9:09 PM")
  /// Times are displayed in the user's current local timezone.
  String _startTimeFormatted(String locale) {
    return DateFormat.jm(locale).format(record.startTime);
  }

  /// Get the intensity icon image path
  String? get _intensityImagePath {
    if (record.intensity == null) return null;
    switch (record.intensity!) {
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
    if (record.endTime == null) return false;

    final startDay = DateTime(
      record.startTime.year,
      record.startTime.month,
      record.startTime.day,
    );
    final endDay = DateTime(
      record.endTime!.year,
      record.endTime!.month,
      record.endTime!.day,
    );

    return endDay.isAfter(startDay);
  }

  /// CUR-488: Show "Incomplete" for ongoing events (no end time set)
  /// Show minimum "1m" if start and end are the same (0 duration)
  /// Returns (text, isIncomplete) tuple for styling
  (String, bool) _getDurationInfo(AppLocalizations l10n) {
    final minutes = record.durationMinutes;
    // If no end time set, show "Incomplete" instead of empty or 0m
    if (record.endTime == null) {
      return (l10n.incomplete, true);
    }
    if (minutes == null) return ('', false);
    // Show minimum 1m if start and end are the same time
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

    // Handle special event types with custom styling
    if (record.isNoNosebleedsEvent) {
      return _buildNoNosebleedsCard(context, l10n);
    }

    if (record.isUnknownEvent) {
      return _buildUnknownCard(context, l10n);
    }

    // Regular nosebleed event card
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
  Widget _buildNosebleedCard(
    BuildContext context,
    AppLocalizations l10n,
    String locale,
  ) {
    // Fixed widths for column alignment
    // Time column: "12:59 AM" needs ~80px, 24h "23:59" needs ~45px
    // Note: timezone can be shown on second line when different from device
    final use24Hour = !DateFormat.jm(locale).pattern!.contains('a');
    final timeWidth = use24Hour ? 45.0 : 80.0;
    const iconWidth = 32.0; // 28px icon + 4px gap
    // CUR-488 Phase 2: Widened to 90px to fit "Incomplete" with large text on iPhone SE
    const durationWidth = 90.0;

    // CUR-488 Phase 2: Get duration info with incomplete flag for styling
    final (durationText, isIncompleteDuration) = _getDurationInfo(l10n);

    // CUR-488 Phase 2: Subtle orange tint for incomplete records
    final cardColor =
        highlightColor ?? (record.isIncomplete ? Colors.orange.shade50 : null);

    return Card(
      margin: EdgeInsets.zero,
      color: cardColor,
      // CUR-488 Phase 2: Increased elevation for more visible shadows
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Start time - fixed width, right aligned
                // CUR-488 Phase 2: Darker text for better readability
                SizedBox(
                  width: timeWidth,
                  child: Text(
                    _startTimeFormatted(locale),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
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
                // CUR-488 Phase 2: Orange text for "Incomplete", less muted for durations
                // Use smaller font for "Incomplete" to fit on small screens (iPhone SE)
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
                // Use Expanded to take remaining space and prevent overflow
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
                if (record.isIncomplete) ...[
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
