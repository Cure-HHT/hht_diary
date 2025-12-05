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
  });
  final NosebleedRecord record;
  final VoidCallback? onTap;

  /// Whether this record overlaps with another record's time range
  final bool hasOverlap;

  /// Format start time for one-line display (e.g., "09:09 PM")
  String _startTimeFormatted(String locale) {
    if (record.startTime == null) return '--:--';
    return DateFormat.jm(locale).format(record.startTime!);
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
    if (record.startTime == null || record.endTime == null) return false;

    final startDay = DateTime(
      record.startTime!.year,
      record.startTime!.month,
      record.startTime!.day,
    );
    final endDay = DateTime(
      record.endTime!.year,
      record.endTime!.month,
      record.endTime!.day,
    );

    return endDay.isAfter(startDay);
  }

  String get _duration {
    final minutes = record.durationMinutes;
    if (minutes == null) return '';
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) return '${hours}h';
    return '${hours}h ${remainingMinutes}m';
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
  /// CUR-443: One-line format: "09:09 PM (icon) 1h 11m" with warning icon
  Widget _buildNosebleedCard(
    BuildContext context,
    AppLocalizations l10n,
    String locale,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Start time
                Text(
                  _startTimeFormatted(locale),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),

                // Intensity mini-icon with subtle border (tight to image)
                if (_intensityImagePath != null) ...[
                  const SizedBox(width: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
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
                  ),
                ],

                // Duration
                if (_duration.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Text(
                    _duration,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],

                // Multi-day indicator
                if (_isMultiDay) ...[
                  const SizedBox(width: 8),
                  Text(
                    l10n.translate('plusOneDay'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                // Spacer to push status indicators to the right
                const Spacer(),

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
