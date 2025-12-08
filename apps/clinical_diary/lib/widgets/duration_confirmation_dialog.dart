// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00002: Short Duration Nosebleed Confirmation
//   REQ-CAL-p00003: Long Duration Nosebleed Confirmation

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Type of duration confirmation needed
enum DurationConfirmationType {
  /// REQ-CAL-p00002: Duration is <= 1 minute
  short,

  /// REQ-CAL-p00003: Duration is > threshold (default 60 minutes)
  long,
}

/// Dialog for confirming unusual nosebleed durations.
/// Used for both short duration (REQ-CAL-p00002) and long duration (REQ-CAL-p00003).
class DurationConfirmationDialog extends StatelessWidget {
  const DurationConfirmationDialog({
    required this.type,
    required this.durationMinutes,
    this.thresholdMinutes,
    super.key,
  });

  final DurationConfirmationType type;
  final int durationMinutes;

  /// Threshold in minutes (only used for long duration type)
  final int? thresholdMinutes;

  /// Show the duration confirmation dialog.
  /// Returns true if user confirms, false if user wants to edit.
  static Future<bool> show({
    required BuildContext context,
    required DurationConfirmationType type,
    required int durationMinutes,
    int? thresholdMinutes,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DurationConfirmationDialog(
        type: type,
        durationMinutes: durationMinutes,
        thresholdMinutes: thresholdMinutes,
      ),
    );
    return result ?? false;
  }

  String _formatDuration(int minutes, AppLocalizations l10n) {
    if (minutes < 60) {
      return l10n.translateWithParams('durationMinutesShort', [minutes]);
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return l10n.translateWithParams('durationHoursShort', [hours]);
    }
    return l10n.translateWithParams('durationHoursMinutesShort', [
      hours,
      remainingMinutes,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final String title;
    final String message;

    switch (type) {
      case DurationConfirmationType.short:
        title = l10n.translate('shortDurationTitle');
        message = l10n.translate('shortDurationMessage');
        break;
      case DurationConfirmationType.long:
        title = l10n.translate('longDurationTitle');
        final thresholdFormatted = _formatDuration(
          thresholdMinutes ?? 60,
          l10n,
        );
        message = l10n.translateWithParams('longDurationMessage', [
          thresholdFormatted,
        ]);
        break;
    }

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(durationMinutes, l10n),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.no),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.yes),
        ),
      ],
    );
  }
}
