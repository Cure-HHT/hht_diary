// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00081: Participant Task System

/// Types of tasks displayed at the top of the participant's mobile app screen.
///
/// Per REQ-CAL-p00081-B, tasks are ordered by priority (1 = highest).
enum TaskType {
  /// Priority 1: Study Coordinator sent a questionnaire to fill out.
  /// Removed when: participant submits OR coordinator deletes.
  questionnaire(1, 'questionnaire', 'Questionnaire to fill out'),

  /// Priority 1.5: Notification that a previously-sent questionnaire
  /// was cancelled (tombstoned) by the coordinator. Renders like a
  /// questionnaire task; tapping it dismisses (no navigation).
  /// CUR-1292.
  cancelledQuestionnaire(
    1,
    'cancelled_questionnaire',
    'Questionnaire cancelled',
  ),

  /// Priority 2: Participant saved a partial diary entry.
  /// Removed when: participant completes the entry.
  incompleteRecord(2, 'incomplete_record', 'Incomplete record'),

  /// Priority 3: New day began without yesterday's diary entry.
  /// Removed when: participant enters yesterday's data.
  yesterdayReminder(3, 'yesterday_reminder', 'Yesterday reminder'),

  /// Priority 4: Calendar day passed without any diary entry.
  /// Removed when: participant enters data for that day.
  missingDays(4, 'missing_days', 'Days with no entries');

  const TaskType(this.priority, this.value, this.displayName);

  /// Display priority (1 = highest, shown first per REQ-CAL-p00081-C)
  final int priority;

  /// Wire format value (used in JSON, API)
  final String value;

  /// Human-readable display name
  final String displayName;

  /// Parse from wire format string. Throws [ArgumentError] if unknown.
  static TaskType fromValue(String value) {
    return TaskType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => throw ArgumentError('Unknown task type: $value'),
    );
  }
}
