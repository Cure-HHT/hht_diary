// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00008: Mobile App Diary Entry

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// List item widget for displaying a nosebleed event
class EventListItem extends StatelessWidget {
  const EventListItem({required this.record, super.key, this.onTap});
  final NosebleedRecord record;
  final VoidCallback? onTap;

  String _timeRange(String locale) {
    if (record.startTime == null) return '--';

    final startStr = DateFormat.jm(locale).format(record.startTime!);
    if (record.endTime == null) return startStr;

    final endStr = DateFormat.jm(locale).format(record.endTime!);
    return '$startStr - $endStr';
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

  Color _getIntensityColor(BuildContext context) {
    if (record.intensity == null) return Colors.grey;

    // Use neutral blue-grey scale for intensity indicator
    switch (record.intensity!) {
      case NosebleedIntensity.spotting:
        return Colors.blueGrey.shade100;
      case NosebleedIntensity.dripping:
        return Colors.blueGrey.shade200;
      case NosebleedIntensity.drippingQuickly:
        return Colors.blueGrey.shade300;
      case NosebleedIntensity.steadyStream:
        return Colors.blueGrey.shade400;
      case NosebleedIntensity.pouring:
        return Colors.blueGrey.shade500;
      case NosebleedIntensity.gushing:
        return Colors.blueGrey.shade600;
    }
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
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Intensity indicator
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: _getIntensityColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _timeRange(locale),
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        if (_isMultiDay) ...[
                          const SizedBox(width: 4),
                          Text(
                            l10n.translate('plusOneDay'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                        if (_duration.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _duration,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (record.intensity != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.intensityName(record.intensity!.name),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Status indicators
              if (record.isIncomplete)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: Colors.orange.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.translate('incomplete'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // Chevron
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
