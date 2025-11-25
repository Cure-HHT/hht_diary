import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// List item widget for displaying a nosebleed event
class EventListItem extends StatelessWidget {

  const EventListItem({
    required this.record, super.key,
    this.onTap,
  });
  final NosebleedRecord record;
  final VoidCallback? onTap;

  String get _timeRange {
    if (record.startTime == null) return '--';

    final startStr = DateFormat('h:mm a').format(record.startTime!);
    if (record.endTime == null) return startStr;

    final endStr = DateFormat('h:mm a').format(record.endTime!);
    return '$startStr - $endStr';
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

  Color _getSeverityColor(BuildContext context) {
    if (record.severity == null) return Colors.grey;

    // Use neutral blue-grey scale for severity indicator
    switch (record.severity!) {
      case NosebleedSeverity.spotting:
        return Colors.blueGrey.shade100;
      case NosebleedSeverity.dripping:
        return Colors.blueGrey.shade200;
      case NosebleedSeverity.drippingQuickly:
        return Colors.blueGrey.shade300;
      case NosebleedSeverity.steadyStream:
        return Colors.blueGrey.shade400;
      case NosebleedSeverity.pouring:
        return Colors.blueGrey.shade500;
      case NosebleedSeverity.gushing:
        return Colors.blueGrey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Severity indicator
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: _getSeverityColor(context),
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
                          _timeRange,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        if (_duration.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
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
                    if (record.severity != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        record.severity!.displayName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ],
                ),
              ),

              // Status indicators
              if (record.isIncomplete)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        'Incomplete',
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
