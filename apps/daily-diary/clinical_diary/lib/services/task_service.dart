// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00081: Patient Task System
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//
// Task service manages the list of actionable tasks displayed at the
// top of the patient's mobile app screen per REQ-CAL-p00081.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Service for managing patient tasks.
///
/// Per REQ-CAL-p00081:
/// - A: Tasks are actionable items at the top of the screen
/// - B: Supports questionnaire, incomplete record, yesterday reminder, missing days
/// - C: Tasks displayed in priority order
/// - D: Each task links to the relevant screen
/// - E: Tasks auto-removed when removal condition met
/// - F: Task list updates in real-time
class TaskService extends ChangeNotifier {
  static const _storageKey = 'patient_tasks';

  final List<Task> _tasks = [];

  /// Current list of active tasks, sorted by priority (REQ-CAL-p00081-C)
  List<Task> get tasks => List.unmodifiable(
    _tasks..sort((a, b) => a.priority.compareTo(b.priority)),
  );

  /// Whether there are any active tasks
  bool get hasTasks => _tasks.isNotEmpty;

  /// Number of active tasks
  int get taskCount => _tasks.length;

  /// Load persisted tasks from local storage
  Future<void> loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getString(_storageKey);

      if (tasksJson != null) {
        final tasksList = jsonDecode(tasksJson) as List<dynamic>;
        _tasks.clear();
        for (final taskJson in tasksList) {
          try {
            _tasks.add(Task.fromJson(taskJson as Map<String, dynamic>));
          } catch (e) {
            debugPrint('[TaskService] Failed to parse task: $e');
          }
        }
        debugPrint('[TaskService] Loaded ${_tasks.length} tasks from storage');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[TaskService] Failed to load tasks: $e');
    }
  }

  /// Handle an FCM data message.
  ///
  /// Routes the message to the appropriate handler based on the 'type' field.
  void handleFcmMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    debugPrint('[TaskService] Handling FCM message type: $type');

    switch (type) {
      case 'questionnaire_sent':
        _handleQuestionnaireSent(data);
      case 'questionnaire_deleted':
        _handleQuestionnaireDeleted(data);
      default:
        debugPrint('[TaskService] Unknown message type: $type');
    }
  }

  /// Handle a questionnaire_sent FCM message.
  ///
  /// Per REQ-CAL-p00023-D: Creates a task at the top of the screen.
  void _handleQuestionnaireSent(Map<String, dynamic> data) {
    final instanceId = data['questionnaire_instance_id'] as String?;
    if (instanceId == null) {
      debugPrint('[TaskService] Missing questionnaire_instance_id');
      return;
    }

    // Check if task already exists (idempotency)
    if (_tasks.any((t) => t.id == instanceId)) {
      debugPrint('[TaskService] Task already exists for: $instanceId');
      return;
    }

    try {
      final task = Task.fromFcmData(data);
      _tasks.add(task);
      debugPrint(
        '[TaskService] Added questionnaire task: ${task.title} ($instanceId)',
      );
      notifyListeners();
      unawaited(_saveTasks());
    } catch (e) {
      debugPrint('[TaskService] Failed to create task from FCM data: $e');
    }
  }

  /// Handle a questionnaire_deleted FCM message.
  ///
  /// Per REQ-CAL-p00023-H & REQ-CAL-p00081-E: Removes the task.
  void _handleQuestionnaireDeleted(Map<String, dynamic> data) {
    final instanceId = data['questionnaire_instance_id'] as String?;
    if (instanceId == null) {
      debugPrint('[TaskService] Missing questionnaire_instance_id');
      return;
    }

    final hadTask = _tasks.any((t) => t.id == instanceId);
    _tasks.removeWhere((t) => t.id == instanceId);
    if (hadTask) {
      debugPrint('[TaskService] Removed task for: $instanceId');
      notifyListeners();
      unawaited(_saveTasks());
    } else {
      debugPrint('[TaskService] No task found for: $instanceId');
    }
  }

  /// Remove a task by ID.
  ///
  /// Per REQ-CAL-p00081-E: Tasks auto-removed when removal condition met.
  /// Call this when the patient completes or submits a questionnaire.
  void removeTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    debugPrint('[TaskService] Removed task: $taskId');
    notifyListeners();
    unawaited(_saveTasks());
  }

  /// Add a task manually (e.g., for incomplete records or missing days).
  void addTask(Task task) {
    // Avoid duplicates
    if (_tasks.any((t) => t.id == task.id)) return;
    _tasks.add(task);
    notifyListeners();
    unawaited(_saveTasks());
  }

  /// Persist tasks to local storage
  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = jsonEncode(_tasks.map((t) => t.toJson()).toList());
      await prefs.setString(_storageKey, tasksJson);
    } catch (e) {
      debugPrint('[TaskService] Failed to save tasks: $e');
    }
  }

  /// Clear all tasks (e.g., on logout or trial end)
  Future<void> clearAll() async {
    _tasks.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('[TaskService] Failed to clear tasks: $e');
    }
  }
}
