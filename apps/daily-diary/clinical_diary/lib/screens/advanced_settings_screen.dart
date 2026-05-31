// Implements: DIARY-DEV-action-write-path/A — each control writes one
//   `set_user_setting` action (source: user, unlocked) through the scope's
//   actionSubmitter; the screen holds no authoritative state.
// Implements: DIARY-DEV-reactive-read-path/A — current values come from the
//   event-sourced settings projection via [ClinicalRulesScope].
//
// "Advanced" settings: the participant's own clinical entry rules (justification
// / lock time-window, short+long duration confirmations, review screen). These
// are NOT developer-only — they are detailed settings most users leave at the
// default ("no restriction"). The same `clinical.*` keys a sponsor sets during a
// study are user-settable here outside one (see the sponsor-rule-enforcement
// design). Sponsor-locked keys are shown read-only (added with the sponsor path).
import 'dart:async';

import 'package:clinical_diary/settings/clinical_rules_scope.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart' show ActionSubmission;
import 'package:flutter/material.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

class AdvancedSettingsScreen extends StatelessWidget {
  const AdvancedSettingsScreen({super.key});

  void _set(BuildContext context, String key, Object? value) {
    // Fire-and-forget: the settings projection is the source of truth and the
    // app-root ViewBuilder rebuilds the tree (and ClinicalRulesScope) on the
    // resulting event.
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
    final rules = ClinicalRulesScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                  const SizedBox(width: 16),
                  Text('Advanced', style: theme.textTheme.titleLarge),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _sectionHeader(context, 'Entry timing'),
                  // Require justification after N hours (null = off).
                  _hoursTile(
                    context,
                    title: 'Require a reason for late entries',
                    subtitle:
                        'Ask for a reason when adding/editing an entry older '
                        'than the selected age.',
                    currentHours: rules.gate.justificationThreshold?.inHours,
                    presetHours: const [24, 48, 72],
                    onChanged: (h) =>
                        _set(context, justificationThresholdHoursKey, h),
                  ),
                  // Lock entries after N hours (null = off).
                  _hoursTile(
                    context,
                    title: 'Lock entries after a while',
                    subtitle:
                        'Once an entry is older than the selected age it '
                        'becomes read-only (no add/edit/delete for that day).',
                    currentHours: rules.gate.lockThreshold?.inHours,
                    presetHours: const [24, 48, 72, 168],
                    onChanged: (h) => _set(context, lockThresholdHoursKey, h),
                  ),
                  const Divider(),
                  _sectionHeader(context, 'Duration checks'),
                  SwitchListTile(
                    title: const Text('Confirm very short nosebleeds'),
                    subtitle: const Text(
                      'Ask to confirm a nosebleed of one minute or less.',
                    ),
                    value: rules.shortDurationConfirm,
                    onChanged: (v) => _set(context, shortDurationConfirmKey, v),
                  ),
                  // Long-duration confirmation: one control sets both the bool
                  // and the threshold (null = off).
                  _longDurationTile(context, rules),
                  const Divider(),
                  _sectionHeader(context, 'Recording'),
                  SwitchListTile(
                    title: const Text('Show a review step before saving'),
                    subtitle: const Text(
                      'Review the entry on a summary screen before it is saved.',
                    ),
                    value: rules.useReviewScreen,
                    onChanged: (v) => _set(context, useReviewScreenKey, v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  /// A row whose trailing dropdown selects an "Off / after N hours" value.
  Widget _hoursTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int? currentHours,
    required List<int> presetHours,
    required ValueChanged<int?> onChanged,
  }) {
    // Include the current value in the options so a non-preset (e.g. sponsor-set)
    // value never trips the DropdownButton's single-selection assertion.
    final values = <int?>[
      null,
      ...presetHours,
      if (currentHours != null && !presetHours.contains(currentHours))
        currentHours,
    ];
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<int?>(
        value: currentHours,
        items: [
          for (final v in values)
            DropdownMenuItem<int?>(value: v, child: Text(_hoursLabel(v))),
        ],
        onChanged: onChanged,
      ),
    );
  }

  String _hoursLabel(int? hours) {
    if (hours == null) return 'Off';
    if (hours % 168 == 0) {
      final w = hours ~/ 168;
      return w == 1 ? '1 week' : '$w weeks';
    }
    if (hours % 24 == 0) {
      final d = hours ~/ 24;
      return d == 1 ? '1 day' : '$d days';
    }
    return '$hours hours';
  }

  Widget _longDurationTile(BuildContext context, ClinicalRules rules) {
    final currentMinutes = rules.longDurationConfirm
        ? rules.longDurationThresholdMinutes
        : null;
    const presets = <int>[60, 120, 240];
    final values = <int?>[
      null,
      ...presets,
      if (currentMinutes != null && !presets.contains(currentMinutes))
        currentMinutes,
    ];
    return ListTile(
      title: const Text('Confirm very long nosebleeds'),
      subtitle: const Text(
        'Ask to confirm a nosebleed longer than the selected duration.',
      ),
      trailing: DropdownButton<int?>(
        value: currentMinutes,
        items: [
          for (final v in values)
            DropdownMenuItem<int?>(value: v, child: Text(_minutesLabel(v))),
        ],
        onChanged: (minutes) {
          if (minutes == null) {
            _set(context, longDurationConfirmKey, false);
          } else {
            _set(context, longDurationConfirmKey, true);
            _set(context, longDurationThresholdMinutesKey, minutes);
          }
        },
      ),
    );
  }

  String _minutesLabel(int? minutes) {
    if (minutes == null) return 'Off';
    if (minutes % 60 == 0) {
      final h = minutes ~/ 60;
      return h == 1 ? '1 hour' : '$h hours';
    }
    return '$minutes min';
  }
}
