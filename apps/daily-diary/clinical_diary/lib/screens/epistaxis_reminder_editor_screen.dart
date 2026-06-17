// Implements: DIARY-PRD-notification-ongoing-epistaxis/H — the participant edits
//   their own Ongoing Epistaxis Reminder Schedule: add, remove, and change each
//   interval (whole minutes), then save. The schedule is written as a single
//   `set_user_setting(reminder.epistaxisSchedule, List<int>)`; an empty list is
//   an explicit "Off". A Sponsor schedule, when in effect, overrides this and is
//   shown read-only on the settings screen (assertion J) — this editor is only
//   reachable when no Sponsor schedule is in effect.

import 'dart:async';

import 'package:clinical_diary/notifications/epistaxis_reminder_schedule.dart';
import 'package:diary_shared_model/diary_shared_model.dart' show SettingSource;
import 'package:event_sourcing/event_sourcing.dart' show ActionSubmission;
import 'package:flutter/material.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

/// Minimum and maximum minutes allowed for a single reminder interval.
const int _kMinInterval = 1;
const int _kMaxInterval = 59;

/// Default minutes used when the participant adds a new interval.
const int _kNewIntervalMinutes = 5;

/// Editor for the participant's personal Reminder Schedule. Pass the current
/// minutes via [initialMinutes]; on save the new schedule is submitted and the
/// screen pops.
class EpistaxisReminderEditorScreen extends StatefulWidget {
  const EpistaxisReminderEditorScreen({
    required this.initialMinutes,
    super.key,
  });

  /// The schedule the editor opens with (ordered whole-minute intervals).
  final List<int> initialMinutes;

  @override
  State<EpistaxisReminderEditorScreen> createState() =>
      _EpistaxisReminderEditorScreenState();
}

class _EpistaxisReminderEditorScreenState
    extends State<EpistaxisReminderEditorScreen> {
  late List<int> _minutes;

  @override
  void initState() {
    super.initState();
    _minutes = List<int>.of(widget.initialMinutes);
  }

  void _adjust(int index, int delta) {
    setState(() {
      _minutes[index] = (_minutes[index] + delta).clamp(
        _kMinInterval,
        _kMaxInterval,
      );
    });
  }

  void _remove(int index) => setState(() => _minutes.removeAt(index));

  void _add() => setState(() => _minutes.add(_kNewIntervalMinutes));

  void _resetToDefault() => setState(
    () => _minutes = List<int>.of(kDefaultEpistaxisReminderScheduleMinutes),
  );

  void _save() {
    // Fire-and-forget through the action dispatcher; the settings projection is
    // the source of truth and the app-root ViewBuilder rebuilds on the event.
    unawaited(
      ReActionScope.of(context).actionSubmitter.submit(
        ActionSubmission(
          actionName: 'set_user_setting',
          rawInput: <String, Object?>{
            'key': reminderEpistaxisScheduleKey,
            'value': List<int>.of(_minutes),
            'source': SettingSource.user.name,
          },
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder schedule'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Remind me to finish an ongoing nosebleed entry. Each reminder is '
              'measured from the previous one — the first from your last activity '
              'on the record.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            if (_minutes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Reminders are off. Add one below, or reset to the '
                  'recommended schedule.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              for (var i = 0; i < _minutes.length; i++) ...[
                _buildIntervalRow(context, i),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Add reminder'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _resetToDefault,
              child: const Text('Reset to recommended (5, 10, 15, 30 min)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalRow(BuildContext context, int index) {
    final theme = Theme.of(context);
    final minutes = _minutes[index];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Reminder ${index + 1}',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: minutes > _kMinInterval
                ? () => _adjust(index, -1)
                : null,
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Decrease',
          ),
          SizedBox(
            width: 64,
            child: Text(
              '$minutes min',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          IconButton(
            onPressed: minutes < _kMaxInterval ? () => _adjust(index, 1) : null,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Increase',
          ),
          IconButton(
            onPressed: () => _remove(index),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}
