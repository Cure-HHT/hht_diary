// Implements: DIARY-DEV-deployment-config-defaults/E — dev-only screen
//   (env-gated via AppConfig.showAllConfigsScreen) for exercising every sponsor
//   configuration parameter over the REAL settings-apply path: user-settable
//   keys (clinical rules + pref.* picks) through `set_user_setting`, and the
//   sponsor/deployment-only allow-set & capability keys (`ui.*`) through the
//   `apply_sponsor_settings` / `unlock_sponsor_settings` lock-simulation actions.
//   No sponsor dropdown and no "Load from server" — config arrives EVS-native at
//   link time; this screen only simulates / overrides it locally.
import 'dart:async';

import 'package:clinical_diary/scope/sponsor_ui_config_scope.dart';
import 'package:clinical_diary/settings/app_preferences_scope.dart';
import 'package:clinical_diary/settings/clinical_rules_scope.dart';
import 'package:clinical_diary/settings/user_preferences.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart' show ActionSubmission;
import 'package:flutter/material.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

/// Dev configs screen. Reads current values from the live scopes
/// ([SponsorUiConfigScope], [ClinicalRulesScope], [AppPreferencesScope]) and
/// writes each change through the registered actions.
class AllConfigsScreen extends StatelessWidget {
  const AllConfigsScreen({super.key});

  /// Writes a user-settable key (clinical rule or `pref.*` pick) via
  /// `set_user_setting`.
  void _setUserSetting(BuildContext context, String key, Object? value) {
    unawaited(
      ReActionScope.of(context).actionSubmitter.submit(
        ActionSubmission(
          actionName: 'set_user_setting',
          rawInput: <String, Object?>{'key': key, 'value': value},
        ),
      ),
    );
  }

  /// Applies one or more sponsor/deployment-only keys (locked) via
  /// `apply_sponsor_settings`, simulating what the portal sends at link time.
  void _applySponsorSettings(
    BuildContext context,
    Map<String, Object?> settings,
  ) {
    unawaited(
      ReActionScope.of(context).actionSubmitter.submit(
        ActionSubmission(
          actionName: 'apply_sponsor_settings',
          rawInput: <String, Object?>{'settings': settings},
        ),
      ),
    );
  }

  /// Reverts the given sponsor keys (clears the lock) via
  /// `unlock_sponsor_settings`, simulating the not-participating revert.
  void _unlockSponsorSettings(
    BuildContext context,
    Map<String, Object?> lockedSettings,
  ) {
    unawaited(
      ReActionScope.of(context).actionSubmitter.submit(
        ActionSubmission(
          actionName: 'unlock_sponsor_settings',
          rawInput: <String, Object?>{'lockedSettings': lockedSettings},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uiConfig = SponsorUiConfigScope.of(context);
    final rules = ClinicalRulesScope.of(context);
    final prefs = AppPreferencesScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('All configs (dev)')),
      body: ListView(
        children: [
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
                    'Developer tool. These write the same event-sourced '
                    'settings a sponsor delivers at link time. Use only for '
                    'testing.',
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),

          // --- Clinical rules (user-settable: set_user_setting) ---
          _sectionHeader(context, 'Clinical rules (user settings)'),
          SwitchListTile(
            title: const Text('Confirm very short nosebleeds'),
            subtitle: const Text('clinical.shortDurationConfirm'),
            value: rules.shortDurationConfirm,
            onChanged: (v) =>
                _setUserSetting(context, shortDurationConfirmKey, v),
          ),
          SwitchListTile(
            title: const Text('Confirm very long nosebleeds'),
            subtitle: const Text('clinical.longDurationConfirm'),
            value: rules.longDurationConfirm,
            onChanged: (v) =>
                _setUserSetting(context, longDurationConfirmKey, v),
          ),
          _intTile(
            context,
            title: 'Long-duration threshold (minutes)',
            subtitle: 'clinical.longDurationThresholdMinutes',
            current: rules.longDurationThresholdMinutes,
            options: const [60, 120, 240, 480],
            settingKey: longDurationThresholdMinutesKey,
          ),
          SwitchListTile(
            title: const Text('Show review screen'),
            subtitle: const Text('clinical.useReviewScreen'),
            value: rules.useReviewScreen,
            onChanged: (v) => _setUserSetting(context, useReviewScreenKey, v),
          ),
          _intTile(
            context,
            title: 'Require justification after (hours)',
            subtitle: 'clinical.justificationThresholdHours',
            current: rules.gate.justificationThreshold?.inHours,
            options: const [24, 48, 72],
            settingKey: justificationThresholdHoursKey,
          ),
          _intTile(
            context,
            title: 'Lock entries after (hours)',
            subtitle: 'clinical.lockThresholdHours',
            current: rules.gate.lockThreshold?.inHours,
            options: const [24, 48, 72, 168],
            settingKey: lockThresholdHoursKey,
          ),

          const Divider(height: 32),

          // --- User picks (user-settable: set_user_setting) ---
          _sectionHeader(context, 'User picks'),
          _stringTile(
            context,
            title: 'Selected font',
            subtitle: 'pref.selectedFont',
            current: prefs.selectedFont,
            options: uiConfig.availableFonts,
            settingKey: prefSelectedFont,
          ),
          _stringTile(
            context,
            title: 'Language',
            subtitle: 'pref.languageCode',
            current: prefs.languageCode,
            options: uiConfig.availableLanguages,
            settingKey: prefLanguageCode,
          ),

          const Divider(height: 32),

          // --- Sponsor/deployment allow-set + capability keys ---
          //   apply_sponsor_settings (locked) / unlock_sponsor_settings (revert).
          _sectionHeader(context, 'Sponsor / deployment config (locked)'),
          SwitchListTile(
            title: const Text('Animations capability'),
            subtitle: const Text('ui.useAnimations'),
            value: uiConfig.useAnimations,
            onChanged: (v) =>
                _applySponsorSettings(context, {uiUseAnimationsKey: v}),
          ),
          _allowSetTile(
            context,
            title: 'Available fonts',
            allowKey: uiAvailableFontsKey,
            defaultKey: uiDefaultFontKey,
            platform: kPlatformFontFamilies,
            current: uiConfig.availableFonts,
            currentDefault: uiConfig.defaultFont,
          ),
          _allowSetTile(
            context,
            title: 'Available languages',
            allowKey: uiAvailableLanguagesKey,
            defaultKey: uiDefaultLanguageKey,
            platform: kPlatformLanguageCodes,
            current: uiConfig.availableLanguages,
            currentDefault: uiConfig.defaultLanguage,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.lock_open),
              label: const Text('Unlock (revert) all ui.* keys'),
              onPressed: () => _unlockSponsorSettings(context, {
                uiUseAnimationsKey: uiConfig.useAnimations,
                uiAvailableFontsKey: uiConfig.availableFonts,
                uiDefaultFontKey: uiConfig.defaultFont,
                uiAvailableLanguagesKey: uiConfig.availableLanguages,
                uiDefaultLanguageKey: uiConfig.defaultLanguage,
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  /// A dropdown over int [options] (plus Off) that writes [settingKey] via
  /// `set_user_setting`. [current] null = Off.
  Widget _intTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int? current,
    required List<int> options,
    required String settingKey,
  }) {
    final values = <int?>[
      null,
      ...options,
      if (current != null && !options.contains(current)) current,
    ];
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<int?>(
        value: current,
        items: [
          for (final v in values)
            DropdownMenuItem<int?>(
              value: v,
              child: Text(v?.toString() ?? 'Off'),
            ),
        ],
        onChanged: (v) => _setUserSetting(context, settingKey, v),
      ),
    );
  }

  /// A dropdown over string [options] writing [settingKey] via
  /// `set_user_setting`.
  Widget _stringTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String current,
    required List<String> options,
    required String settingKey,
  }) {
    final values = <String>[
      ...options,
      if (!options.contains(current)) current,
    ];
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<String>(
        value: values.contains(current) ? current : null,
        items: [
          for (final v in values)
            DropdownMenuItem<String>(value: v, child: Text(v)),
        ],
        onChanged: (v) {
          if (v != null) _setUserSetting(context, settingKey, v);
        },
      ),
    );
  }

  /// An allow-set editor (checkboxes over the [platform] set) plus a default
  /// picker. Applies the chosen allow-set and default together (locked) via
  /// `apply_sponsor_settings`. When the allow-set is narrowed, the default must
  /// be a member; the picker is restricted to the selected set.
  Widget _allowSetTile(
    BuildContext context, {
    required String title,
    required String allowKey,
    required String defaultKey,
    required List<String> platform,
    required List<String> current,
    required String currentDefault,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title ($allowKey)',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          for (final value in platform)
            CheckboxListTile(
              dense: true,
              title: Text(value),
              value: current.contains(value),
              onChanged: (checked) {
                final next = List<String>.from(current);
                if (checked ?? false) {
                  if (!next.contains(value)) next.add(value);
                } else {
                  next.remove(value);
                }
                if (next.isEmpty) return; // never apply an empty allow-set
                final nextDefault = next.contains(currentDefault)
                    ? currentDefault
                    : next.first;
                _applySponsorSettings(context, {
                  allowKey: next,
                  defaultKey: nextDefault,
                });
              },
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Default ($defaultKey): '),
                DropdownButton<String>(
                  value: current.contains(currentDefault)
                      ? currentDefault
                      : null,
                  items: [
                    for (final v in current)
                      DropdownMenuItem<String>(value: v, child: Text(v)),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      _applySponsorSettings(context, {defaultKey: v});
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
