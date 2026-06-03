// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00081: Patient Task System

/// Types of tasks displayed at the top of the patient's mobile app screen.
///
/// Per REQ-CAL-p00081-B, tasks are ordered by priority (1 = highest).
enum TaskType {
  /// Priority 1: Study Coordinator sent a questionnaire to fill out.
  /// Removed when: patient submits OR coordinator deletes.
  questionnaire(1, 'questionnaire', 'Questionnaire to fill out'),

  /// Priority 2: Patient saved a partial diary entry.
  /// Removed when: patient completes the entry.
  incompleteRecord(2, 'incomplete_record', 'Incomplete record'),

  /// Priority 3: New day began without yesterday's diary entry.
  /// Removed when: patient enters yesterday's data.
  yesterdayReminder(3, 'yesterday_reminder', 'Yesterday reminder'),

  /// Priority 4: Calendar day passed without any diary entry.
  /// Removed when: patient enters data for that day.
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
