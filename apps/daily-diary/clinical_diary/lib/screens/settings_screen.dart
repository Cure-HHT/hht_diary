// Implements: DIARY-DEV-action-write-path/A — each toggle writes one
//   `set_user_setting` action through the core ActionDispatcher (via the scope's
//   actionSubmitter); the screen holds no authoritative state.
// Implements: DIARY-DEV-reactive-read-path/A — current values are read from the
//   settings projection through [AppPreferencesScope] (fed by the app-level
//   settings ViewBuilder), not from a local cache.

// The font dropdown uses DropdownButtonFormField.value (reactively reflects the
// current setting); the newer initialValue API is set-once and unsuitable here.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/feature_flags_screen.dart';
import 'package:clinical_diary/settings/app_preferences_scope.dart';
import 'package:clinical_diary/settings/user_preferences.dart';
import 'package:clinical_diary/utils/app_page_route.dart';
import 'package:event_sourcing/event_sourcing.dart' show ActionSubmission;
import 'package:flutter/material.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

/// Settings screen for accessibility and preferences.
///
/// Reads the current [UserPreferences] from [AppPreferencesScope] (the settings
/// projection) and writes each change as a `set_user_setting` action.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Submits a `set_user_setting` action for [key]/[value] via the scope.
  void _setSetting(BuildContext context, String key, Object? value) {
    // Fire-and-forget: the settings projection is the source of truth and the
    // ViewBuilder at the app root rebuilds the tree on the resulting event.
    unawaited(
      ReActionScope.of(context).actionSubmitter.submit(
        ActionSubmission(
          actionName: 'set_user_setting',
          rawInput: <String, Object?>{'key': key, 'value': value},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferencesScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(AppLocalizations.of(context).back),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    AppLocalizations.of(context).settings,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Color Scheme Section
                    _buildSectionHeader(
                      context,
                      AppLocalizations.of(context).colorScheme,
                      AppLocalizations.of(context).chooseAppearance,
                    ),
                    const SizedBox(height: 16),
                    _buildColorSchemeOption(
                      context,
                      icon: Icons.light_mode,
                      title: AppLocalizations.of(context).lightMode,
                      subtitle: AppLocalizations.of(
                        context,
                      ).lightModeDescription,
                      isSelected: !prefs.isDarkMode,
                      onTap: () => _setSetting(context, prefDarkMode, false),
                    ),
                    const SizedBox(height: 12),
                    // Dark mode disabled for alpha release
                    _buildColorSchemeOption(
                      context,
                      icon: Icons.dark_mode,
                      title: AppLocalizations.of(context).darkMode,
                      subtitle: 'Coming soon',
                      isSelected: false,
                      onTap: null,
                      isDisabled: true,
                    ),

                    const SizedBox(height: 32),

                    // Accessibility Section
                    _buildSectionHeader(
                      context,
                      AppLocalizations.of(context).accessibility,
                      AppLocalizations.of(context).accessibilityDescription,
                    ),
                    const SizedBox(height: 16),
                    // CUR-528: Font selection dropdown
                    if (FeatureFlagService.instance.shouldShowFontSelector)
                      _buildFontSelector(context, prefs),
                    if (FeatureFlagService.instance.shouldShowFontSelector)
                      const SizedBox(height: 12),
                    _buildAccessibilityOption(
                      context,
                      title: AppLocalizations.of(context).largerTextAndControls,
                      subtitle: AppLocalizations.of(
                        context,
                      ).largerTextDescription,
                      value: prefs.largerTextAndControls,
                      onChanged: (value) =>
                          _setSetting(context, prefLargerText, value),
                    ),
                    // Use Animation option - only show if feature flag is enabled
                    if (FeatureFlagService.instance.useAnimations) ...[
                      const SizedBox(height: 12),
                      _buildAccessibilityOption(
                        context,
                        title: AppLocalizations.of(context).useAnimation,
                        subtitle: AppLocalizations.of(
                          context,
                        ).useAnimationDescription,
                        value: prefs.useAnimation,
                        onChanged: (value) =>
                            _setSetting(context, prefUseAnimation, value),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Language Section
                    _buildSectionHeader(
                      context,
                      AppLocalizations.of(context).language,
                      AppLocalizations.of(context).languageDescription,
                    ),
                    const SizedBox(height: 16),
                    _buildLanguageOption(
                      context,
                      code: 'en',
                      name: 'English',
                      isSelected: prefs.languageCode == 'en',
                      onTap: () => _setSetting(context, prefLanguageCode, 'en'),
                    ),
                    const SizedBox(height: 12),
                    _buildLanguageOption(
                      context,
                      code: 'es',
                      name: 'Español',
                      isSelected: prefs.languageCode == 'es',
                      onTap: () => _setSetting(context, prefLanguageCode, 'es'),
                    ),
                    const SizedBox(height: 12),
                    _buildLanguageOption(
                      context,
                      code: 'fr',
                      name: 'Français',
                      isSelected: prefs.languageCode == 'fr',
                      onTap: () => _setSetting(context, prefLanguageCode, 'fr'),
                    ),
                    const SizedBox(height: 12),
                    _buildLanguageOption(
                      context,
                      code: 'de',
                      name: 'Deutsch',
                      isSelected: prefs.languageCode == 'de',
                      onTap: () => _setSetting(context, prefLanguageCode, 'de'),
                    ),

                    // Feature Flags - only available in dev/qa builds
                    if (F.showDevTools) ...[
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        context,
                        AppLocalizations.of(context).featureFlagsTitle,
                        AppLocalizations.of(context).featureFlagsWarning,
                      ),
                      const SizedBox(height: 16),
                      _buildNavigationOption(
                        context,
                        icon: Icons.science_outlined,
                        title: AppLocalizations.of(context).featureFlagsTitle,
                        subtitle: AppLocalizations.of(
                          context,
                        ).featureFlagsWarning,
                        onTap: () {
                          Navigator.push(
                            context,
                            AppPageRoute<void>(
                              builder: (context) => const FeatureFlagsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  /// CUR-528: Build font selection dropdown
  Widget _buildFontSelector(BuildContext context, UserPreferences prefs) {
    final l10n = AppLocalizations.of(context);
    final availableFonts = FeatureFlagService.instance.availableFonts;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.fontSelection,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.fontSelectionDescription,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: availableFonts.any((f) => f.fontFamily == prefs.selectedFont)
                ? prefs.selectedFont
                : availableFonts.first.fontFamily,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            items: availableFonts.map((font) {
              return DropdownMenuItem<String>(
                value: font.fontFamily,
                child: Text(font.displayName),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _setSetting(context, prefSelectedFont, value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColorSchemeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback? onTap,
    bool isDisabled = false,
  }) {
    final effectiveOpacity = isDisabled ? 0.5 : 1.0;

    return Opacity(
      opacity: effectiveOpacity,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessibilityOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? linkText,
    VoidCallback? onLinkTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(!value),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (linkText != null) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: onLinkTap,
                      child: Text(
                        linkText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context, {
    required String code,
    required String name,
    required bool isSelected,
    required VoidCallback? onTap,
    bool isDisabled = false,
  }) {
    final effectiveOpacity = isDisabled ? 0.5 : 1.0;

    return Opacity(
      opacity: effectiveOpacity,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : null,
          ),
          child: Row(
            children: [
              const Icon(Icons.language, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
