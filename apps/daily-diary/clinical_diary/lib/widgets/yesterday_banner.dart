import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Choice values for the yesterday-confirmation segmented prompt — `yes`,
/// `no`, or `dontRemember`. Each maps to a different write callback (this is
/// a dispatch surface, not a sticky single-select).
enum _YesterdayChoice { yes, no, dontRemember }

/// Confirm-yesterday prompt — "Did you have nosebleeds?" with three quick
/// actions. The three-option picker uses the design-system
/// [AppSegmentedChoice]; behaviour is unchanged.
// Implements: DIARY-PRD-day-disposition/B
class YesterdayBanner extends StatelessWidget {
  const YesterdayBanner({
    required this.onNoNosebleeds,
    required this.onHadNosebleeds,
    required this.onDontRemember,
    super.key,
  });
  final VoidCallback onNoNosebleeds;
  final VoidCallback onHadNosebleeds;
  final VoidCallback onDontRemember;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr = DateFormat('MMM d').format(yesterday);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: semantic.primaryLightSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.confirmYesterdayDate(dateStr),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.didYouHaveNosebleeds,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          AppSegmentedChoice<_YesterdayChoice>(
            // Dispatch surface — no sticky selection. Each tap fires the
            // matching callback (write a marker / open the recording screen).
            value: null,
            options: [
              AppChoiceOption(value: _YesterdayChoice.yes, label: l10n.yes),
              AppChoiceOption(value: _YesterdayChoice.no, label: l10n.no),
              AppChoiceOption(
                value: _YesterdayChoice.dontRemember,
                label: l10n.dontRemember,
              ),
            ],
            onChanged: (choice) {
              switch (choice) {
                case _YesterdayChoice.yes:
                  onHadNosebleeds();
                case _YesterdayChoice.no:
                  onNoNosebleeds();
                case _YesterdayChoice.dontRemember:
                  onDontRemember();
              }
            },
          ),
        ],
      ),
    );
  }
}
