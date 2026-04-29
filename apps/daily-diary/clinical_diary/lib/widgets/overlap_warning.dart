// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00043: Temporal Entry Validation - Overlap Prevention

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/utils/date_time_formatter.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Warning widget for overlapping events.
///
/// Displays the specific time range of the first conflicting [DiaryEntry] and
/// provides a button to navigate to view it, as required by REQ-p00043.
///
/// Each entry's `currentAnswers['startTime']` and `currentAnswers['endTime']`
/// supply the displayed range; entries that have no parsable startTime fall
/// back to `entry.effectiveDate` (which is the materialized derivation).
class OverlapWarning extends StatelessWidget {
  const OverlapWarning({
    required this.overlappingEntries,
    this.onViewConflict,
    super.key,
  });

  final List<DiaryEntry> overlappingEntries;

  /// Callback when user taps "View" to navigate to the conflicting entry.
  /// Passes the first overlapping entry.
  final void Function(DiaryEntry entry)? onViewConflict;

  String _formatTime(DateTime? time, String locale) {
    if (time == null) return '--:--';
    return DateFormat.jm(locale).format(time);
  }

  DateTime? _readTime(DiaryEntry entry, String key) {
    final raw = entry.currentAnswers[key];
    if (raw is String) return DateTimeFormatter.parse(raw);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (overlappingEntries.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    final firstOverlap = overlappingEntries.first;
    final start = _readTime(firstOverlap, 'startTime');
    final end = _readTime(firstOverlap, 'endTime');
    final startTimeStr = _formatTime(start, locale);
    final endTimeStr = _formatTime(end, locale);

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
