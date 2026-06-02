// Implements: DIARY-GUI-entry-overlap-resolution

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Warning widget for overlapping events.
///
/// Displays the specific time range of the first conflicting
/// [EpistaxisEntryView] and provides a button to finalize the current entry
/// and route to the side-by-side resolution screen.
///
/// The time range is read directly from the typed view-model's start/end
/// times; no answer-map parsing happens here.
class OverlapWarning extends StatelessWidget {
  const OverlapWarning({
    required this.overlappingEntries,
    this.onResolve,
    super.key,
  });

  final List<EpistaxisEntryView> overlappingEntries;

  /// Callback when user taps "Resolve" to finalize the entry and navigate to
  /// the side-by-side compare screen.
  final VoidCallback? onResolve;

  String _formatTime(DateTime? time, String locale) {
    if (time == null) return '--:--';
    return DateFormat.jm(locale).format(time);
  }

  @override
  Widget build(BuildContext context) {
    if (overlappingEntries.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    final firstOverlap = overlappingEntries.first;
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
          if (onResolve != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onResolve,
              style: TextButton.styleFrom(
                foregroundColor: Colors.amber.shade900,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                // TODO(i18n): localize.
                'Resolve',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
