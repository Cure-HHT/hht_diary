// Implements: DIARY-GUI-entry-overlap-resolution

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:flutter/material.dart';

/// Warning widget for overlapping events.
///
/// Figma 675:2377 "Critical Message": Pending Bg (#FFF5DE) rounded card with a
/// 28px triangle alert and Pending Dark (#B9790A) copy. Shows how many
/// finalized records the current entry overlaps and provides a button to
/// finalize the current entry and route to the side-by-side resolution screen.
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

  /// Figma "Pending Dark"-toned accent used across the attention surfaces.
  static const Color _accent = Color(0xFFB9790A);

  @override
  Widget build(BuildContext context) {
    if (overlappingEntries.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final count = overlappingEntries.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5DE),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.overlappingEventsDetected,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 23.8 / 18,
                    letterSpacing: -0.43,
                    color: _accent,
                  ),
                ),
                Text(
                  // TODO(i18n): localize (Figma 675:2380 copy).
                  'This event overlaps with $count existing '
                  'event${count == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    letterSpacing: -0.43,
                    color: _accent,
                  ),
                ),
              ],
            ),
          ),
          if (onResolve != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onResolve,
              style: TextButton.styleFrom(
                foregroundColor: _accent,
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
