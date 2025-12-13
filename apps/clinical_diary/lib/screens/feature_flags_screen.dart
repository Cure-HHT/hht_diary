// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-CAL-p00001: Old Entry Modification Justification
//   REQ-CAL-p00002: Short Duration Nosebleed Confirmation
//   REQ-CAL-p00003: Long Duration Nosebleed Confirmation

// ignore_for_file: deprecated_member_use

import 'package:clinical_diary/config/app_config.dart';
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
  // CUR-546: Default to currently loaded sponsor, or first known sponsor
  late String _selectedSponsor;
  bool _isLoading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // Use the currently loaded sponsor if available, otherwise default to first
    _selectedSponsor =
        _featureFlagService.currentSponsorId ??
        FeatureFlags.knownSponsors.first;
  }

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

          // Sponsor Selection Section
          _buildSectionHeader(l10n.featureFlagsSponsorSelection),

          // Current sponsor display
          if (_featureFlagService.currentSponsorId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                l10n.featureFlagsCurrentSponsor(
                  _featureFlagService.currentSponsorId!,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Sponsor dropdown and Load button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSponsor,
                    decoration: InputDecoration(
                      labelText: l10n.featureFlagsSponsorId,
                      border: const OutlineInputBorder(),
                    ),
                    items: FeatureFlags.knownSponsors
                        .map(
                          (sponsor) => DropdownMenuItem(
                            value: sponsor,
                            child: Text(sponsor),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedSponsor = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _loadFromServer,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download),
                  label: Text(l10n.featureFlagsLoad),
                ),
              ],
            ),
          ),

          // Error message
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SelectableText(
                _loadError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),

          const Divider(height: 32),

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

          // CUR-508: Use One-Page Recording Screen
          SwitchListTile(
            title: Text(l10n.featureFlagsUseOnePageRecordingScreen),
            subtitle: Text(
              l10n.featureFlagsUseOnePageRecordingScreenDescription,
            ),
            value: _featureFlagService.useOnePageRecordingScreen,
            onChanged: (value) {
              setState(() {
                _featureFlagService.useOnePageRecordingScreen = value;
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

          const Divider(height: 32),

          // CUR-528: Font Accessibility Section
          _buildSectionHeader(l10n.featureFlagsSectionFonts),

          // Font checkboxes
          ...FontOption.values.map((font) {
            final isSelected = _featureFlagService.availableFonts.contains(
              font,
            );
            return CheckboxListTile(
              title: Text(font.displayName),
              subtitle: Text(_getFontDescription(font, l10n)),
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  final currentFonts = List<FontOption>.from(
                    _featureFlagService.availableFonts,
                  );
                  if (value ?? false) {
                    if (!currentFonts.contains(font)) {
                      currentFonts.add(font);
                    }
                  } else {
                    currentFonts.remove(font);
                  }
                  _featureFlagService.availableFonts = currentFonts;
                });
              },
            );
          }),

          // Info about font selector visibility
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _featureFlagService.shouldShowFontSelector
                  ? l10n.featureFlagsFontSelectorVisible
                  : l10n.featureFlagsFontSelectorHidden,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFontDescription(FontOption font, AppLocalizations l10n) {
    switch (font) {
      case FontOption.roboto:
        return l10n.fontDescriptionRoboto;
      case FontOption.openDyslexic:
        return l10n.fontDescriptionOpenDyslexic;
      case FontOption.atkinsonHyperlegible:
        return l10n.fontDescriptionAtkinson;
    }
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

  Future<void> _loadFromServer() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final apiKey = AppConfig.qaApiKey;
    final success = await _featureFlagService.loadFromServer(
      _selectedSponsor,
      apiKey,
    );

    setState(() {
      _isLoading = false;
      if (!success) {
        _loadError = _featureFlagService.lastError ?? 'Unknown error';
      }
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).featureFlagsLoadSuccess(_selectedSponsor),
          ),
        ),
      );
    }
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
      _featureFlagService.resetToDefaults();
      setState(() {
        _loadError = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.featureFlagsResetSuccess)));
      }
    }
  }
}
