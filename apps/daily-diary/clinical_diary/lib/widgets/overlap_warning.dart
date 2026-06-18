// Implements: DIARY-GUI-entry-overlap-resolution

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:flutter/material.dart';

/// Warning widget for overlapping events.
///
/// Figma 675:2377 "Critical Message": Pending Bg (#FFF5DE) rounded card with a
/// 28px triangle alert and Pending Dark (#B9790A) copy. Shows how many
/// finalized records the current entry overlaps.
///
/// The banner is purely informational: per DIARY-GUI-entry-overlap-resolution
/// Assertion B the early warning SHALL NOT prevent the participant from
/// continuing the recording flow, so it carries NO "Resolve" action. Resolution
/// is triggered only once the participant confirms the end time and the overlap
/// is confirmed (Assertion C), at which point the recording screen routes to the
/// side-by-side Resolution Screen.
class OverlapWarning extends StatelessWidget {
  const OverlapWarning({required this.overlappingEntries, super.key});

  final List<EpistaxisEntryView> overlappingEntries;

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
        ],
      ),
    );
  }
}
