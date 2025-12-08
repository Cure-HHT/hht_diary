// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00001: Old Entry Modification Justification
//   REQ-CAL-p00002: Short Duration Nosebleed Confirmation
//   REQ-CAL-p00003: Long Duration Nosebleed Confirmation

import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Screen for viewing and modifying feature flags.
/// Only available in dev and qa builds for testing purposes.
/// These are sponsor-controlled settings that will be set at enrollment time.
class FeatureFlagsScreen extends StatefulWidget {
  const FeatureFlagsScreen({super.key});

  @override
  State<FeatureFlagsScreen> createState() => _FeatureFlagsScreenState();
}

class _FeatureFlagsScreenState extends State<FeatureFlagsScreen> {
  final _featureFlagService = FeatureFlagService.instance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.featureFlagsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: l10n.featureFlagsResetToDefaults,
            onPressed: _resetToDefaults,
          ),
        ],
      ),
      body: ListView(
        children: [
          // Warning banner
          Container(
            color: theme.colorScheme.errorContainer,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.featureFlagsWarning,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),

          // UI Features Section
          _buildSectionHeader(l10n.featureFlagsSectionUI),

          // Use Review Screen
          SwitchListTile(
            title: Text(l10n.featureFlagsUseReviewScreen),
            subtitle: Text(l10n.featureFlagsUseReviewScreenDescription),
            value: _featureFlagService.useReviewScreen,
            onChanged: (value) {
              setState(() {
                _featureFlagService.useReviewScreen = value;
              });
            },
          ),
          const Divider(height: 1),

          // Use Animations
          SwitchListTile(
            title: Text(l10n.featureFlagsUseAnimations),
            subtitle: Text(l10n.featureFlagsUseAnimationsDescription),
            value: _featureFlagService.useAnimations,
            onChanged: (value) {
              setState(() {
                _featureFlagService.useAnimations = value;
              });
            },
          ),
          const Divider(height: 1),

          // Validation Features Section
          _buildSectionHeader(l10n.featureFlagsSectionValidation),

          // Old Entry Justification
          SwitchListTile(
            title: Text(l10n.featureFlagsOldEntryJustification),
            subtitle: Text(l10n.featureFlagsOldEntryJustificationDescription),
            value: _featureFlagService.requireOldEntryJustification,
            onChanged: (value) {
              setState(() {
                _featureFlagService.requireOldEntryJustification = value;
              });
            },
          ),
          const Divider(height: 1),

          // Short Duration Confirmation
          SwitchListTile(
            title: Text(l10n.featureFlagsShortDurationConfirmation),
            subtitle: Text(
              l10n.featureFlagsShortDurationConfirmationDescription,
            ),
            value: _featureFlagService.enableShortDurationConfirmation,
            onChanged: (value) {
              setState(() {
                _featureFlagService.enableShortDurationConfirmation = value;
              });
            },
          ),
          const Divider(height: 1),

          // Long Duration Confirmation
          SwitchListTile(
            title: Text(l10n.featureFlagsLongDurationConfirmation),
            subtitle: Text(
              l10n.featureFlagsLongDurationConfirmationDescription,
            ),
            value: _featureFlagService.enableLongDurationConfirmation,
            onChanged: (value) {
              setState(() {
                _featureFlagService.enableLongDurationConfirmation = value;
              });
            },
          ),
          const Divider(height: 1),

          // Long Duration Threshold (only enabled when Long Duration Confirmation is on)
          ListTile(
            enabled: _featureFlagService.enableLongDurationConfirmation,
            title: Text(l10n.featureFlagsLongDurationThreshold),
            subtitle: Text(
              l10n.featureFlagsLongDurationThresholdDescription(
                _featureFlagService.longDurationThresholdMinutes,
              ),
            ),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _featureFlagService.longDurationThresholdMinutes
                    .toDouble(),
                min: FeatureFlags.minLongDurationThresholdHours * 60,
                max: FeatureFlags.maxLongDurationThresholdHours * 60,
                divisions:
                    FeatureFlags.maxLongDurationThresholdHours -
                    FeatureFlags.minLongDurationThresholdHours,
                label:
                    '${_featureFlagService.longDurationThresholdMinutes ~/ 60}h',
                onChanged: _featureFlagService.enableLongDurationConfirmation
                    ? (value) {
                        setState(() {
                          _featureFlagService.longDurationThresholdMinutes =
                              value.round();
                        });
                      }
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _resetToDefaults() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.featureFlagsResetTitle),
        content: Text(l10n.featureFlagsResetConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.featureFlagsResetButton),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await _featureFlagService.resetToDefaults();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.featureFlagsResetSuccess)));
      }
    }
  }
}
