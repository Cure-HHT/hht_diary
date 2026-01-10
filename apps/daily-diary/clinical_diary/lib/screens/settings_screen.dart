// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

// ignore_for_file: deprecated_member_use

import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/feature_flags_screen.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/utils/app_page_route.dart';
import 'package:flutter/material.dart';

/// Settings screen for accessibility and preferences
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.preferencesService,
    this.onLanguageChanged,
    this.onThemeModeChanged,
    this.onLargerTextChanged,
    this.onFontChanged,
    super.key,
  });

  final PreferencesService preferencesService;
  final ValueChanged<String>? onLanguageChanged;
  final ValueChanged<bool>? onThemeModeChanged;
  final ValueChanged<bool>? onLargerTextChanged;
  final ValueChanged<String>? onFontChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  String _selectedFont = 'Roboto';
  bool _largerTextAndControls = false;
  bool _useAnimation = true;
  bool _compactView = false;
  String _languageCode = 'en';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await widget.preferencesService.getPreferences();
    setState(() {
      _isDarkMode = prefs.isDarkMode;
      _selectedFont = prefs.selectedFont;
      _largerTextAndControls = prefs.largerTextAndControls;
      _useAnimation = prefs.useAnimation;
      _compactView = prefs.compactView;
      _languageCode = prefs.languageCode;
      _isLoading = false;
    });
  }

  Future<void> _savePreferences() async {
    await widget.preferencesService.savePreferences(
      UserPreferences(
        isDarkMode: _isDarkMode,
        selectedFont: _selectedFont,
        largerTextAndControls: _largerTextAndControls,
        useAnimation: _useAnimation,
        compactView: _compactView,
        languageCode: _languageCode,
      ),
    );
  }

  void _selectLanguage(String code) {
    setState(() => _languageCode = code);
    _savePreferences();
    widget.onLanguageChanged?.call(code);
  }

  @override
  Widget build(BuildContext context) {
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
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
                            isSelected: !_isDarkMode,
                            onTap: () {
                              setState(() => _isDarkMode = false);
                              _savePreferences();
                              widget.onThemeModeChanged?.call(false);
                            },
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
                            AppLocalizations.of(
                              context,
                            ).accessibilityDescription,
                          ),
                          const SizedBox(height: 16),
                          // CUR-528: Font selection dropdown
                          if (FeatureFlagService
                              .instance
                              .shouldShowFontSelector)
                            _buildFontSelector(context),
                          if (FeatureFlagService
                              .instance
                              .shouldShowFontSelector)
                            const SizedBox(height: 12),
                          _buildAccessibilityOption(
                            context,
                            title: AppLocalizations.of(
                              context,
                            ).largerTextAndControls,
                            subtitle: AppLocalizations.of(
                              context,
                            ).largerTextDescription,
                            value: _largerTextAndControls,
                            onChanged: (value) {
                              setState(() => _largerTextAndControls = value);
                              _savePreferences();
                              // CUR-488: Notify parent to apply text scaling
                              widget.onLargerTextChanged?.call(value);
                            },
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
                              value: _useAnimation,
                              onChanged: (value) {
                                setState(() => _useAnimation = value);
                                _savePreferences();
                              },
                            ),
                          ],
                          // CUR-464: Compact view option
                          const SizedBox(height: 12),
                          _buildAccessibilityOption(
                            context,
                            title: AppLocalizations.of(context).compactView,
                            subtitle: AppLocalizations.of(
                              context,
                            ).compactViewDescription,
                            value: _compactView,
                            onChanged: (value) {
                              setState(() => _compactView = value);
                              _savePreferences();
                            },
                          ),

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
                            isSelected: _languageCode == 'en',
                            onTap: () => _selectLanguage('en'),
                          ),
                          const SizedBox(height: 12),
                          _buildLanguageOption(
                            context,
                            code: 'es',
                            name: 'Español',
                            isSelected: _languageCode == 'es',
                            onTap: () => _selectLanguage('es'),
                          ),
                          const SizedBox(height: 12),
                          _buildLanguageOption(
                            context,
                            code: 'fr',
                            name: 'Français',
                            isSelected: _languageCode == 'fr',
                            onTap: () => _selectLanguage('fr'),
                          ),
                          const SizedBox(height: 12),
                          _buildLanguageOption(
                            context,
                            code: 'de',
                            name: 'Deutsch',
                            isSelected: _languageCode == 'de',
                            onTap: () => _selectLanguage('de'),
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
                              title: AppLocalizations.of(
                                context,
                              ).featureFlagsTitle,
                              subtitle: AppLocalizations.of(
                                context,
                              ).featureFlagsWarning,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  AppPageRoute<void>(
                                    builder: (context) =>
                                        const FeatureFlagsScreen(),
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
  Widget _buildFontSelector(BuildContext context) {
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
            value: availableFonts.any((f) => f.fontFamily == _selectedFont)
                ? _selectedFont
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
                setState(() => _selectedFont = value);
                _savePreferences();
                // CUR-528: Notify parent to update theme font
                widget.onFontChanged?.call(value);
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
