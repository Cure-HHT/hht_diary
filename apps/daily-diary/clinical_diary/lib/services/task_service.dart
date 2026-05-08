// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00081: Patient Task System
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-d00113: Deleted Questionnaire Submission Handling
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
  TaskService({
    http.Client? httpClient,
    this.onCancelled,
    EnrollmentService? enrollmentService,
  }) : _httpClient = httpClient ?? http.Client(),
       _enrollmentService = enrollmentService;

  /// CUR-1311: held for FCM-driven sync. When an `patient_status_update`,
  /// `questionnaire_unlocked`, or `questionnaire_finalized` push arrives,
  /// [handleFcmMessage] uses this service to call [syncTasks] — FCM is
  /// treated as a wake-up signal rather than a payload to trust.
  /// Optional so existing tests (`TaskService(httpClient: client)`) keep
  /// working without an enrollment service.
  final EnrollmentService? _enrollmentService;

  /// CUR-1292: invoked once per cancelled questionnaire surfaced in
  /// the `/tasks` response's `cancelled` array. Receives the
  /// instance's aggregate id and the entry-type form (e.g.
  /// `nose_hht_survey`). Caller (main.dart) records a local tombstone
  /// event so the timeline card disappears, and queues a
  /// "questionnaire cancelled" notification via
  /// [notifyQuestionnaireCancelled]. This is the pragmatic shim
  /// channel until `/api/v1/user/inbound` exists; both paths are
  /// idempotent so they coexist. Returning a [Future] lets
  /// [syncTasks] block until the local tombstone has landed, so a
  /// subsequent `_loadRecords` reads the post-tombstone materialized
  /// view (otherwise the today/yesterday card lingers until the
  /// next refresh).
  final Future<void> Function(String aggregateId, String entryType)?
  onCancelled;

  static const _storageKey = 'patient_tasks';

  /// CUR-1292: SharedPreferences key for the persisted set of
  /// cancelled-questionnaire aggregate ids the patient has already
  /// dismissed. The /tasks response keeps returning a 30-day window
  /// of cancellations regardless of dismissal, so the diary tracks
  /// dismissal locally and filters before queueing a new
  /// notification. Set is monotonically grown — there's no GC; the
  /// 30-day server window keeps it bounded.
  static const _dismissedCancellationsKey = 'patient_dismissed_cancellations';

  final http.Client _httpClient;
  final List<Task> _tasks = [];
  final Set<String> _dismissedCancellationAggregateIds = <String>{};

  /// REQ-CAL-p00079: When the portal coordinator clicks "Send EQ" the
  /// patient's `trial_started_at` is stamped server-side. The diary
  /// `/tasks` response surfaces it; this notifier transitions from
  /// `null` to that timestamp the first time we observe it. Listeners
  /// (currently the bootstrap in main.dart) activate the legacy-shim
  /// destinations with `setStartDate(value)` on transition. Set once
  /// per session — never reset to null, even if a later sync omits
  /// the field, so a transient server hiccup can't deactivate sync.
  final ValueNotifier<DateTime?> trialStartedAtNotifier = ValueNotifier(null);

  @override
  void dispose() {
    trialStartedAtNotifier.dispose();
    super.dispose();
  }

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

      final dismissedJson = prefs.getStringList(_dismissedCancellationsKey);
      if (dismissedJson != null) {
        _dismissedCancellationAggregateIds
          ..clear()
          ..addAll(dismissedJson);
        debugPrint(
          '[TaskService] Loaded ${_dismissedCancellationAggregateIds.length} '
          'dismissed-cancellation ids from storage',
        );
      }
    } catch (e) {
      debugPrint('[TaskService] Failed to load tasks: $e');
    }
  }

  Future<void> _saveDismissedCancellations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _dismissedCancellationsKey,
        _dismissedCancellationAggregateIds.toList(),
      );
    } catch (e) {
      debugPrint('[TaskService] Failed to save dismissed cancellations: $e');
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
      case 'questionnaire_unlocked':
      case 'questionnaire_finalized':
      case 'patient_status_update':
        // CUR-1311: FCM is just a wake-up. Re-pull /tasks so the task
        // list, disconnection state, not-participating state, and
        // trial-started timestamp all reflect the server's truth. The
        // notifiers fired inside processDisconnectionStatus then drive
        // the home-screen UI without per-action sub-routing here.
        _triggerSync();
      default:
        debugPrint('[TaskService] Unknown message type: $type');
    }
  }

  /// CUR-1311: kick a server pull when an FCM signal arrives. No-op when
  /// the service was constructed without an [EnrollmentService] (tests).
  void _triggerSync() {
    final enrollment = _enrollmentService;
    if (enrollment == null) {
      debugPrint(
        '[TaskService] Sync requested but no EnrollmentService configured',
      );
      return;
    }
    unawaited(syncTasks(enrollment));
  }

  /// Handle a questionnaire_sent FCM message.
  ///
  /// Per REQ-CAL-p00023-D: Creates a task at the top of the screen.
  /// EQ (Epistaxis Questionnaire) is excluded per CUR-1050 — it is handled
  /// via the nosebleed button, not as a scheduled task.
  void _handleQuestionnaireSent(Map<String, dynamic> data) {
    final instanceId = data['questionnaire_instance_id'] as String?;
    if (instanceId == null) {
      debugPrint('[TaskService] Missing questionnaire_instance_id');
      return;
    }

    // EQ is not a scheduled task — skip it (CUR-1050)
    if (data['questionnaire_type'] == 'eq') {
      debugPrint('[TaskService] Skipping EQ questionnaire task (CUR-1050)');
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
  ///
  /// CUR-1292: when the task is a `cancelledQuestionnaire` notification
  /// (patient dismissed it), the aggregate id is recorded in
  /// [_dismissedCancellationAggregateIds] so subsequent task-syncs do
  /// not re-create the notification — the server's `cancelled[]`
  /// window keeps returning the entry for 30 days.
  void removeTask(String taskId) {
    final removed = _tasks.where((t) => t.id == taskId).toList(growable: false);
    _tasks.removeWhere((t) => t.id == taskId);
    debugPrint('[TaskService] Removed task: $taskId');
    var dismissedChanged = false;
    for (final t in removed) {
      if (t.taskType == TaskType.cancelledQuestionnaire) {
        final aggregateId = t.targetId ?? t.id;
        if (_dismissedCancellationAggregateIds.add(aggregateId)) {
          dismissedChanged = true;
        }
      }
    }
    notifyListeners();
    unawaited(_saveTasks());
    if (dismissedChanged) {
      unawaited(_saveDismissedCancellations());
    }
  }

  /// Add a task manually (e.g., for incomplete records or missing days).
  void addTask(Task task) {
    // Avoid duplicates
    if (_tasks.any((t) => t.id == task.id)) return;
    _tasks.add(task);
    notifyListeners();
    unawaited(_saveTasks());
  }

  /// CUR-1292: surface a "questionnaire cancelled" notification when
  /// the coordinator tombstones a previously-sent questionnaire.
  /// Wired to `portalInboundPoll`'s tombstone branch through the
  /// bootstrap so the patient sees a passive notification on the next
  /// title-tap / sync, with a tap-to-dismiss affordance. Also removes
  /// the original questionnaire task — that side already happens via
  /// the regular task-sync (the tombstoned instance falls out of
  /// /tasks), but doing it here too is idempotent and makes the
  /// notification appear instantly on the same gesture.
  void notifyQuestionnaireCancelled({
    required String aggregateId,
    required String displayName,
  }) {
    // CUR-1292: a dismissed cancellation stays dismissed even if the
    // server keeps reporting it for the rest of the 30-day window.
    if (_dismissedCancellationAggregateIds.contains(aggregateId)) return;

    _tasks.removeWhere((t) => (t.targetId ?? t.id) == aggregateId);
    final notifId = 'cancelled-$aggregateId';
    if (_tasks.any((t) => t.id == notifId)) {
      // Already notified; no need to re-add.
      notifyListeners();
      unawaited(_saveTasks());
      return;
    }
    _tasks.add(
      Task(
        id: notifId,
        taskType: TaskType.cancelledQuestionnaire,
        title: displayName,
        subtitle: 'This questionnaire was cancelled',
        createdAt: DateTime.now().toUtc(),
        targetId: aggregateId,
      ),
    );
    debugPrint(
      '[TaskService] Cancelled-notification queued for $displayName ($aggregateId)',
    );
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
  /// REQ-d00113-E: Deleted questionnaires no longer appear as actionable items
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

      // REQ-CAL-p00079: surface the trial-start timestamp from the
      // patient's row. Once set, never reset — a transient server-side
      // omission must not deactivate the patient's outbound sync.
      final trialStartedAtStr = body['trial_started_at'] as String?;
      if (trialStartedAtStr != null) {
        final parsed = DateTime.tryParse(trialStartedAtStr);
        if (parsed != null) {
          trialStartedAtNotifier.value = parsed.toUtc();
        }
      }

      // CUR-1292: process cancelled questionnaires from the response.
      // Awaiting the handler here is important — it records a local
      // tombstone event so the timeline card disappears, and the
      // caller (e.g. the home-screen title-tap) reads the
      // materialized view immediately after this method returns.
      final cancelled = body['cancelled'] as List<dynamic>? ?? [];
      final hook = onCancelled;
      if (hook != null) {
        for (final c in cancelled) {
          if (c is! Map) continue;
          final aggregateId = c['questionnaire_instance_id'] as String?;
          final type = c['questionnaire_type'] as String?;
          if (aggregateId == null || type == null) continue;
          await hook(aggregateId, '${type}_survey');
        }
      }

      final serverTasks = body['tasks'] as List<dynamic>? ?? [];

      // Build set of server task IDs for efficient lookup
      final serverTaskIds = <String>{};
      final newTasks = <Task>[];

      for (final taskJson in serverTasks) {
        final data = taskJson as Map<String, dynamic>;
        final instanceId = data['questionnaire_instance_id'] as String?;
        if (instanceId == null) continue;

        // EQ is not a scheduled task — skip it (CUR-1050)
        if (data['questionnaire_type'] == 'eq') continue;

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
