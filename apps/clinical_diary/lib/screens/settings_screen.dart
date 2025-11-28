// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings screen for accessibility and preferences
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.preferencesService,
    this.onLanguageChanged,
    this.onThemeModeChanged,
    super.key,
  });

  final PreferencesService preferencesService;
  final ValueChanged<String>? onLanguageChanged;
  final ValueChanged<bool>? onThemeModeChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  bool _dyslexiaFriendlyFont = false;
  bool _largerTextAndControls = false;
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
      _dyslexiaFriendlyFont = prefs.dyslexiaFriendlyFont;
      _largerTextAndControls = prefs.largerTextAndControls;
      _languageCode = prefs.languageCode;
      _isLoading = false;
    });
  }

  Future<void> _savePreferences() async {
    await widget.preferencesService.savePreferences(
      UserPreferences(
        isDarkMode: _isDarkMode,
        dyslexiaFriendlyFont: _dyslexiaFriendlyFont,
        largerTextAndControls: _largerTextAndControls,
        languageCode: _languageCode,
      ),
    );
  }

  Future<void> _launchOpenDyslexicUrl() async {
    final uri = Uri.parse('https://opendyslexic.org/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
                          _buildColorSchemeOption(
                            context,
                            icon: Icons.dark_mode,
                            title: AppLocalizations.of(context).darkMode,
                            subtitle: AppLocalizations.of(
                              context,
                            ).darkModeDescription,
                            isSelected: _isDarkMode,
                            onTap: () {
                              setState(() => _isDarkMode = true);
                              _savePreferences();
                              widget.onThemeModeChanged?.call(true);
                            },
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
                          _buildAccessibilityOption(
                            context,
                            title: AppLocalizations.of(
                              context,
                            ).dyslexiaFriendlyFont,
                            subtitle: AppLocalizations.of(
                              context,
                            ).dyslexiaFontDescription,
                            linkText: AppLocalizations.of(
                              context,
                            ).learnMoreOpenDyslexic,
                            onLinkTap: _launchOpenDyslexicUrl,
                            value: _dyslexiaFriendlyFont,
                            onChanged: (value) {
                              setState(() => _dyslexiaFriendlyFont = value);
                              _savePreferences();
                            },
                          ),
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
                            onTap: () {
                              setState(() => _languageCode = 'en');
                              _savePreferences();
                              widget.onLanguageChanged?.call('en');
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildLanguageOption(
                            context,
                            code: 'es',
                            name: 'Espanol',
                            isSelected: _languageCode == 'es',
                            onTap: () {
                              setState(() => _languageCode = 'es');
                              _savePreferences();
                              widget.onLanguageChanged?.call('es');
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildLanguageOption(
                            context,
                            code: 'fr',
                            name: 'Francais',
                            isSelected: _languageCode == 'fr',
                            onTap: () {
                              setState(() => _languageCode = 'fr');
                              _savePreferences();
                              widget.onLanguageChanged?.call('fr');
                            },
                          ),
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

  Widget _buildColorSchemeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
    );
  }
}
