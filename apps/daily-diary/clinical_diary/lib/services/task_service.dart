// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00081: Patient Task System
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//
// Task service manages the list of actionable tasks displayed at the
// top of the patient's mobile app screen per REQ-CAL-p00081.

import 'dart:async';
import 'dart:convert';

import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  TaskService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const _storageKey = 'patient_tasks';

  final http.Client _httpClient;
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

  /// Sync tasks from the diary server.
  ///
  /// Polls GET /api/v1/user/tasks to discover pending questionnaire tasks.
  /// Uses a replace-and-merge strategy: questionnaire tasks are replaced
  /// with the server's list, while non-questionnaire tasks are untouched.
  ///
  /// REQ-CAL-p00081: Patient Task System
  /// REQ-CAL-p00023: Questionnaire discovery via polling
  Future<void> syncTasks(EnrollmentService enrollmentService) async {
    try {
      final jwt = await enrollmentService.getJwtToken();
      if (jwt == null) {
        debugPrint('[TaskService] No JWT — skipping task sync');
        return;
      }

      final backendUrl = await enrollmentService.getBackendUrl();
      if (backendUrl == null) {
        debugPrint('[TaskService] No backend URL — skipping task sync');
        return;
      }

      final url = '$backendUrl/api/v1/user/tasks';
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode != 200) {
        debugPrint('[TaskService] Task sync failed: ${response.statusCode}');
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      // Process disconnection status (same pattern as nosebleed_service)
      enrollmentService.processDisconnectionStatus(body);

      final serverTasks = body['tasks'] as List<dynamic>? ?? [];

      // Build set of server task IDs for efficient lookup
      final serverTaskIds = <String>{};
      final newTasks = <Task>[];

      for (final taskJson in serverTasks) {
        final data = taskJson as Map<String, dynamic>;
        final instanceId = data['questionnaire_instance_id'] as String?;
        if (instanceId == null) continue;

        serverTaskIds.add(instanceId);

        // Only add if not already present locally
        if (!_tasks.any((t) => t.id == instanceId)) {
          try {
            final task = Task.fromFcmData(data);
            newTasks.add(task);
          } catch (e) {
            debugPrint('[TaskService] Failed to create task from sync: $e');
          }
        }
      }

      // Remove local questionnaire tasks that are no longer on the server
      final removedCount = _tasks.length;
      _tasks.removeWhere(
        (t) =>
            t.taskType == TaskType.questionnaire &&
            !serverTaskIds.contains(t.id),
      );
      final afterRemove = _tasks.length;

      // Add new tasks from server
      _tasks.addAll(newTasks);

      final removed = removedCount - afterRemove;
      if (newTasks.isNotEmpty || removed > 0) {
        debugPrint(
          '[TaskService] Sync: +${newTasks.length} added, '
          '-$removed removed, ${_tasks.length} total',
        );
        notifyListeners();
        unawaited(_saveTasks());
      } else {
        debugPrint('[TaskService] Sync: no changes');
      }
    } catch (e) {
      debugPrint('[TaskService] Task sync error: $e');
    }
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
