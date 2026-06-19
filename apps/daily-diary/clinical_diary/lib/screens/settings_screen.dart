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

import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/config/font_option.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/notifications/epistaxis_reminder_schedule.dart';
import 'package:clinical_diary/notifications/yesterday_reminder_schedule.dart';
import 'package:clinical_diary/scope/sponsor_ui_config_scope.dart';
import 'package:clinical_diary/screens/advanced_settings_screen.dart';
import 'package:clinical_diary/screens/epistaxis_reminder_editor_screen.dart';
import 'package:clinical_diary/settings/app_preferences_scope.dart';
import 'package:clinical_diary/settings/user_preferences.dart';
import 'package:clinical_diary/utils/app_page_route.dart';
import 'package:diary_shared_model/diary_shared_model.dart'
    show SettingPayload, settingsViewName;
import 'package:event_sourcing/event_sourcing.dart' show ActionSubmission;
import 'package:flutter/material.dart' hide ViewBuilder;
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
    final uiConfig = SponsorUiConfigScope.of(context);
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
                    // CUR-1438: hidden for the Callisto UAT build (dark mode is
                    // not enabled). Logic retained; gated by config so it can be
                    // re-shown without a rebuild.
                    if (AppConfig.showUatRestrictedSettings) ...[
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
                    ],

                    // Accessibility Section
                    _buildSectionHeader(
                      context,
                      AppLocalizations.of(context).accessibility,
                      AppLocalizations.of(context).accessibilityDescription,
                    ),
                    const SizedBox(height: 16),
                    // CUR-528: Font selection dropdown (shown only when the
                    // sponsor/deployment allow-set offers a real choice).
                    if (_shouldShowFontSelector(uiConfig.availableFonts))
                      _buildFontSelector(context, prefs),
                    if (_shouldShowFontSelector(uiConfig.availableFonts))
                      const SizedBox(height: 12),
                    // CUR-1438: accessibility is limited to fonts for the
                    // Callisto UAT build — the "Larger text and controls" toggle
                    // is hidden (logic retained, config-gated).
                    if (AppConfig.showUatRestrictedSettings)
                      _buildAccessibilityOption(
                        context,
                        title: AppLocalizations.of(
                          context,
                        ).largerTextAndControls,
                        subtitle: AppLocalizations.of(
                          context,
                        ).largerTextDescription,
                        value: prefs.largerTextAndControls,
                        onChanged: (value) =>
                            _setSetting(context, prefLargerText, value),
                      ),
                    // Use Animation option — shown only when the sponsor enables
                    // the animation capability.
                    if (uiConfig.useAnimations) ...[
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

                    // Language Section
                    // CUR-1438: hidden for the Callisto UAT build (translations
                    // are not yet professionally validated). The language
                    // preference + selector logic is retained; gated by config
                    // so it can be re-shown without a rebuild.
                    if (AppConfig.showUatRestrictedSettings) ...[
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        context,
                        AppLocalizations.of(context).language,
                        AppLocalizations.of(context).languageDescription,
                      ),
                      const SizedBox(height: 16),
                      // Only the languages the sponsor/deployment allow-set
                      // permits are offered; the participant picks among them.
                      for (final code in uiConfig.availableLanguages) ...[
                        _buildLanguageOption(
                          context,
                          code: code,
                          name: _languageNames[code] ?? code,
                          isSelected: prefs.languageCode == code,
                          onTap: () =>
                              _setSetting(context, prefLanguageCode, code),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],

                    // Nosebleed reminders — personal Ongoing Epistaxis Reminder
                    // Schedule. Editable when no study (Sponsor) schedule is in
                    // effect; read-only and study-controlled when one is.
                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      context,
                      'Nosebleed reminders',
                      'Remind me to finish an ongoing nosebleed entry',
                    ),
                    const SizedBox(height: 16),
                    _buildReminderSection(context),

                    // Daily reminder — the Yesterday Entry Reminder time + enable
                    // toggle. Read-only when a study (Sponsor) policy controls it.
                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      context,
                      'Daily reminder',
                      "A morning reminder to record yesterday's diary",
                    ),
                    const SizedBox(height: 16),
                    _buildYesterdayReminderSection(context, prefs),

                    // Advanced — detailed clinical entry rules. Available to
                    // ALL users (not dev-gated); most leave them at "Off".
                    const SizedBox(height: 32),
                    _buildSectionHeader(context, 'Advanced', 'Entry rules'),
                    const SizedBox(height: 16),
                    _buildNavigationOption(
                      context,
                      icon: Icons.tune,
                      title: 'Advanced',
                      subtitle: 'Justification, locking, and duration checks',
                      onTap: () {
                        Navigator.push(
                          context,
                          AppPageRoute<void>(
                            builder: (context) =>
                                const AdvancedSettingsScreen(),
                          ),
                        );
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

  /// Language display names for the supported platform language codes.
  static const Map<String, String> _languageNames = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
  };

  /// The font selector is offered only when the allow-set provides a real choice
  /// (more than just the default Roboto).
  bool _shouldShowFontSelector(List<String> fonts) {
    if (fonts.isEmpty) return false;
    if (fonts.length == 1 && fonts.first == 'Roboto') return false;
    return true;
  }

  /// CUR-528: Build font selection dropdown
  Widget _buildFontSelector(BuildContext context, UserPreferences prefs) {
    final l10n = AppLocalizations.of(context);
    final parsedFonts = SponsorUiConfigScope.of(context).availableFonts
        .map(FontOption.fromString)
        .whereType<FontOption>()
        .toList();
    // Guard against an allow-set that parses to nothing (e.g. all unknown
    // family names) so the `.first` reads below can never throw.
    final availableFonts = parsedFonts.isEmpty
        ? <FontOption>[FontOption.roboto]
        : parsedFonts;

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
          // The font family the dropdown currently reflects (falls back to the
          // first available font when the stored preference is unknown). Hoisted
          // so the selector value and the active-font readout below stay in sync.
          Builder(
            builder: (context) {
              final activeFont =
                  availableFonts.any((f) => f.fontFamily == prefs.selectedFont)
                  ? prefs.selectedFont
                  : availableFonts.first.fontFamily;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // CUR-1307: identified for Playwright web automation.
                  Semantics(
                    identifier: 'font-selector',
                    container: true,
                    explicitChildNodes: true,
                    child: DropdownButtonFormField<String>(
                      value: activeFont,
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
                          // CUR-1307: each option targetable when the menu is open.
                          child: Semantics(
                            identifier: 'font-option-${font.fontFamily}',
                            child: Text(font.displayName),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _setSetting(context, prefSelectedFont, value);
                        }
                      },
                    ),
                  ),
                  // CUR-1307: machine-readable readout of the active font selection
                  // for Playwright assertions (surfaces via the node's aria-label).
                  // A zero-size semantics node gets pruned from the web tree, so the
                  // readout carries a 1x1 footprint to keep its node alive.
                  Semantics(
                    identifier: 'active-font',
                    value: activeFont,
                    container: true,
                    child: const SizedBox(width: 1, height: 1),
                  ),
                ],
              );
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

  static String _formatMinutes(List<int> minutes) =>
      minutes.isEmpty ? 'Off' : minutes.map((m) => '$m min').join(', ');

  /// Personal Reminder Schedule entry point. When a Sponsor schedule is in
  /// effect it is shown read-only (the study controls the cadence, assertion J);
  /// otherwise a navigation row opens the editable schedule screen, summarising
  /// the current schedule. When nothing has been configured the CUR-863
  /// personal-use default ([kDefaultEpistaxisReminderScheduleMinutes]) is shown
  /// so reminders work without a Sponsor connection.
  // Implements: DIARY-PRD-notification-ongoing-epistaxis/H+J
  Widget _buildReminderSection(BuildContext context) {
    return ViewBuilder<Map<String, Object?>>(
      viewName: settingsViewName,
      mapper: (r) => r,
      aggregateIdOf: (r) => r['aggregateId'] as String,
      builder: (context, state) {
        final rows = switch (state) {
          Ready<Map<String, Object?>>(:final rows) => rows,
          Stale<Map<String, Object?>>(:final lastRows) => lastRows,
          _ => const <Map<String, Object?>>[],
        };
        Object? sponsorValue;
        Map<String, Object?>? personalRow;
        for (final row in rows) {
          final key = row['key'];
          if (key == reminderEpistaxisScheduleSponsorKey) {
            sponsorValue = row['value'];
          } else if (key == reminderEpistaxisScheduleKey) {
            personalRow = row;
          }
        }

        // A Sponsor schedule is "in effect" when its key holds a list value; it
        // overrides any personal schedule (assertion J).
        if (sponsorValue is List) {
          final sponsorMinutes = sponsorValue
              .whereType<num>()
              .map((n) => n.toInt())
              .toList();
          return _buildSponsorReminderNotice(context, sponsorMinutes);
        }

        // Current personal schedule: a present key (incl. an explicit empty
        // "Off") wins; otherwise the never-configured default is shown.
        final List<int> current;
        if (personalRow != null) {
          final value = personalRow['value'];
          current = value is List
              ? value.whereType<num>().map((n) => n.toInt()).toList()
              : const <int>[];
        } else {
          current = kDefaultEpistaxisReminderScheduleMinutes;
        }

        return _buildNavigationOption(
          context,
          icon: Icons.notifications_active_outlined,
          title: 'Reminder schedule',
          subtitle: _formatMinutes(current),
          onTap: () {
            Navigator.push(
              context,
              AppPageRoute<void>(
                builder: (_) =>
                    EpistaxisReminderEditorScreen(initialMinutes: current),
              ),
            );
          },
        );
      },
    );
  }

  static String _formatTimeOfDay(BuildContext context, int minutes) {
    final tod = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return tod.format(context);
  }

  /// Daily Yesterday Entry Reminder controls: an enable toggle + a Reminder Time
  /// picker. When a Sponsor policy force-enables or pins the time, the section is
  /// shown read-only ("Managed by your study").
  // Implements: DIARY-PRD-notification-yesterday-entry/F
  Widget _buildYesterdayReminderSection(
    BuildContext context,
    UserPreferences prefs,
  ) {
    return ViewBuilder<Map<String, Object?>>(
      viewName: settingsViewName,
      mapper: (r) => r,
      aggregateIdOf: (r) => r['aggregateId'] as String,
      builder: (context, state) {
        final rows = switch (state) {
          Ready<Map<String, Object?>>(:final rows) => rows,
          Stale<Map<String, Object?>>(:final lastRows) => lastRows,
          _ => const <Map<String, Object?>>[],
        };
        var sponsorControlled = false;
        for (final row in rows) {
          final key = row['key'];
          if (key == reminderYesterdayEnabledSponsorKey &&
              row['value'] is bool) {
            sponsorControlled = true;
          } else if (key == reminderYesterdayTimeMinutesSponsorKey &&
              row['value'] is num) {
            sponsorControlled = true;
          }
        }

        // The effective config (sponsor-over-personal) drives the read-only
        // display; the personal prefs drive the editable controls.
        final settingsMap = <String, SettingPayload>{
          for (final row in rows)
            SettingPayload.fromJson(row).key: SettingPayload.fromJson(row),
        };
        final effective = resolveYesterdayReminderConfig(settingsMap);

        if (sponsorControlled) {
          final summary = effective.enabled
              ? 'On at ${_formatTimeOfDay(context, effective.timeMinutes)}'
              : 'Off';
          return _buildSponsorControlledNotice(context, summary);
        }

        return Column(
          children: [
            _buildAccessibilityOption(
              context,
              title: 'Enable daily reminder',
              subtitle: 'Remind me each morning to record yesterday',
              value: prefs.yesterdayReminderEnabled,
              onChanged: (value) =>
                  _setSetting(context, reminderYesterdayEnabledKey, value),
            ),
            if (prefs.yesterdayReminderEnabled) ...[
              const SizedBox(height: 12),
              _buildNavigationOption(
                context,
                icon: Icons.schedule,
                title: 'Reminder time',
                subtitle: _formatTimeOfDay(
                  context,
                  prefs.yesterdayReminderTimeMinutes,
                ),
                onTap: () => _pickReminderTime(context, prefs),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    UserPreferences prefs,
  ) async {
    final current = TimeOfDay(
      hour: prefs.yesterdayReminderTimeMinutes ~/ 60,
      minute: prefs.yesterdayReminderTimeMinutes % 60,
    );
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null || !context.mounted) return;
    // Snap to the nearest half-hour (the reminder grid).
    final raw = picked.hour * 60 + picked.minute;
    final snapped = ((raw + 15) ~/ 30) * 30;
    final clamped = snapped.clamp(0, 23 * 60 + 30);
    _setSetting(context, reminderYesterdayTimeMinutesKey, clamped);
  }

  /// Read-only notice shown when a study policy controls the daily reminder.
  Widget _buildSponsorControlledNotice(BuildContext context, String summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Managed by your study',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Read-only notice shown when the study controls the reminder schedule.
  Widget _buildSponsorReminderNotice(
    BuildContext context,
    List<int> sponsorMinutes,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Managed by your study',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatMinutes(sponsorMinutes),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
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
