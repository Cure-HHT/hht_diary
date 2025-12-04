// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00043: Temporal Entry Validation - Overlap Prevention

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Warning widget for overlapping events
/// Displays the specific time range of the first conflicting record
/// and provides a button to navigate to view it, as required by REQ-p00043
class OverlapWarning extends StatelessWidget {
  const OverlapWarning({
    required this.overlappingRecords,
    this.onViewConflict,
    super.key,
  });

  final List<NosebleedRecord> overlappingRecords;

  /// Callback when user taps "View" to navigate to the conflicting record.
  /// Passes the first overlapping record.
  final void Function(NosebleedRecord record)? onViewConflict;

  String _formatTime(DateTime? time, String locale) {
    if (time == null) return '--:--';
    return DateFormat.jm(locale).format(time);
  }

  @override
  Widget build(BuildContext context) {
    if (overlappingRecords.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    // Get the first overlapping record to display its time range
    final firstOverlap = overlappingRecords.first;
    final startTimeStr = _formatTime(firstOverlap.startTime, locale);
    final endTimeStr = _formatTime(firstOverlap.endTime, locale);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.overlappingEventsDetected,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.overlappingEventTimeRange(startTimeStr, endTimeStr),
                  style: TextStyle(color: Colors.amber.shade800, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onViewConflict != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => onViewConflict!(firstOverlap),
              style: TextButton.styleFrom(
                foregroundColor: Colors.amber.shade900,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n.viewConflictingRecord,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
