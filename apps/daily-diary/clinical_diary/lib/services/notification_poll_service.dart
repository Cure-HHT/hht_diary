// IMPLEMENTS REQUIREMENTS:
//   REQ-d00195: Mobile Notifications Polling
//   REQ-d00195-K: Lifecycle reset (clearCursor)
//
// Envelope-based polling service. FCM is treated as a wake-up hint;
// the truth comes from GET /api/v1/notifications?since=...&limit=50.
// Hooks into the existing 5-source trigger chain via the bootstrap's
// onAfterSync callback — no separate 60 s timer needed.

import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:comms/comms.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for the ISO 8601 cursor.
const _kLastSeenKey = 'notification_lastSeen';

/// SharedPreferences key for the rolling dedupe set.
const _kRecentIdsKey = 'notification_recent_ids';

/// Maximum number of IDs kept in the dedupe set (FIFO, oldest trimmed first).
const _kRecentIdsCap = 500;

/// Bootstrap window when no cursor is persisted: 30 days ago.
const _kBootstrapWindow = Duration(days: 30);

class NotificationPollService {
  NotificationPollService({
    required EnrollmentService enrollmentService,
    required TaskService taskService,
    http.Client? httpClient,
  }) : _enrollmentService = enrollmentService,
       _taskService = taskService,
       _httpClient = httpClient ?? http.Client();

  final EnrollmentService _enrollmentService;
  final TaskService _taskService;
  final http.Client _httpClient;

  /// Main entry point — called after every sync cycle tick.
  ///
  /// Resolves JWT + backend URL, fetches envelopes since cursor,
  /// dedupes, dispatches, and advances the cursor. Skips gracefully
  /// when pre-enrollment or on error.
  Future<void> poll() async {
    try {
      final jwt = await _enrollmentService.getJwtToken();
      if (jwt == null) {
        debugPrint('[NotificationPoll] No JWT — skipping (pre-enrollment)');
        return;
      }

      final backendUrl = await _enrollmentService.getBackendUrl();
      if (backendUrl == null) {
        debugPrint('[NotificationPoll] No backend URL — skipping');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final cursor = _readCursor(prefs);

      final fetcher = EnvelopeFetcher(
        httpClient: _httpClient,
        baseUrl: Uri.parse(backendUrl),
      );

      final page = await fetcher.fetchSince(cursor, authHeader: 'Bearer $jwt');

      if (page.envelopes.isEmpty) {
        // Advance cursor even when empty so the window doesn't re-scan.
        _writeCursor(prefs, page.nextCursor);
        return;
      }

      // Dedupe against recently-seen IDs.
      final recentIds = _readRecentIds(prefs);
      final novel = <Envelope>[];
      for (final envelope in page.envelopes) {
        if (!recentIds.contains(envelope.notificationId)) {
          novel.add(envelope);
        }
      }

      // Dispatch novel envelopes.
      for (final envelope in novel) {
        _dispatch(envelope);
        recentIds.add(envelope.notificationId);
      }

      // Trim to cap (FIFO — oldest first).
      while (recentIds.length > _kRecentIdsCap) {
        recentIds.removeAt(0);
      }

      _writeRecentIds(prefs, recentIds);
      _writeCursor(prefs, page.nextCursor);

      debugPrint(
        '[NotificationPoll] Processed ${novel.length} novel envelope(s) '
        '(${page.envelopes.length - novel.length} deduped)',
      );
    } catch (e, stack) {
      debugPrint('[NotificationPoll] Error: $e\n$stack');
    }
  }

  /// REQ-d00195-K: Clear cursor + dedupe set on lifecycle reset
  /// (end clinical trial). Static so callers don't need to thread
  /// the service instance through the widget tree.
  static Future<void> clearCursor() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastSeenKey);
    await prefs.remove(_kRecentIdsKey);
    debugPrint('[NotificationPoll] Cursor cleared (lifecycle reset)');
  }

  // ---------------------------------------------------------------------------
  // Dispatch
  // ---------------------------------------------------------------------------

  void _dispatch(Envelope envelope) {
    switch (envelope.type) {
      case NotificationType.questionnaireUpdate:
        _taskService.handleEnvelopeQuestionnaireUpdate(envelope);
      case NotificationType.patientStatusUpdate:
        _enrollmentService.handleEnvelopeStatusUpdate(envelope);
      case NotificationType.reminder:
        debugPrint(
          '[NotificationPoll] Reminder envelope ignored: '
          '${envelope.notificationId}',
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Cursor persistence
  // ---------------------------------------------------------------------------

  DateTime _readCursor(SharedPreferences prefs) {
    final raw = prefs.getString(_kLastSeenKey);
    if (raw != null) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.toUtc();
    }
    // Bootstrap: 30 days ago.
    return DateTime.now().toUtc().subtract(_kBootstrapWindow);
  }

  void _writeCursor(SharedPreferences prefs, DateTime cursor) {
    prefs.setString(_kLastSeenKey, cursor.toUtc().toIso8601String());
  }

  // ---------------------------------------------------------------------------
  // Dedupe set persistence
  // ---------------------------------------------------------------------------

  List<String> _readRecentIds(SharedPreferences prefs) {
    return List<String>.from(prefs.getStringList(_kRecentIdsKey) ?? <String>[]);
  }

  void _writeRecentIds(SharedPreferences prefs, List<String> ids) {
    prefs.setStringList(_kRecentIdsKey, ids);
  }
}
