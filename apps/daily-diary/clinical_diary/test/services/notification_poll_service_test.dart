// IMPLEMENTS REQUIREMENTS:
//   REQ-d00195: Mobile Notifications Polling
//   REQ-d00195-K: Lifecycle reset (clearCursor)
//
// Unit tests for NotificationPollService.

import 'dart:convert';

import 'package:clinical_diary/services/notification_poll_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_enrollment_service.dart';
import '../test_helpers/flavor_setup.dart';

/// Helper to build a notification JSON object for the /notifications response.
Map<String, dynamic> _buildEnvelope({
  required String id,
  String type = 'questionnaire_update',
  String action = 'sent',
  String patientId = 'patient-1',
  String title = 'Test',
  DateTime? createdAt,
  Map<String, dynamic>? extraPayload,
}) {
  final payload = <String, dynamic>{'action': action, ...?extraPayload};
  return {
    'notification_id': id,
    'patient_id': patientId,
    'type': type,
    'title': title,
    'user_visible': true,
    'payload': payload,
    'status': 'sent',
    'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
  };
}

/// Returns a MockClient that responds to GET /api/v1/notifications with items.
MockClient _mockClient(
  List<Map<String, dynamic>> items, {
  DateTime? nextCursor,
}) {
  return MockClient((request) async {
    if (request.url.path == '/api/v1/notifications') {
      return http.Response(
        jsonEncode({
          'items': items,
          'next_cursor': (nextCursor ?? DateTime.now().toUtc())
              .toIso8601String(),
        }),
        200,
      );
    }
    return http.Response('not found', 404);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestFlavor();

  late MockEnrollmentService mockEnrollment;
  late TaskService taskService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockEnrollment = MockEnrollmentService()
      ..jwtToken = 'test-jwt'
      ..backendUrl = 'https://diary.example.com';
    taskService = TaskService();
  });

  group('NotificationPollService — poll basics', () {
    test('skips when no JWT (pre-enrollment)', () async {
      mockEnrollment.jwtToken = null;
      final client = _mockClient([]);
      final service = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client,
      );

      // Should complete without error
      await service.poll();
    });

    test('skips when no backend URL', () async {
      mockEnrollment.backendUrl = null;
      final client = _mockClient([]);
      final service = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client,
      );

      await service.poll();
    });

    test('uses bootstrap window (now - 30d) when no cursor persisted', () async {
      final before = DateTime.now().toUtc().subtract(const Duration(days: 30));
      DateTime? capturedSince;

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/notifications') {
          capturedSince = DateTime.parse(request.url.queryParameters['since']!);
          return http.Response(
            jsonEncode({
              'items': <dynamic>[],
              'next_cursor': DateTime.now().toUtc().toIso8601String(),
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final service = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client,
      );

      await service.poll();

      expect(capturedSince, isNotNull);
      // Bootstrap cursor should be approximately 30 days ago (within 2 seconds tolerance)
      final after = DateTime.now().toUtc().subtract(const Duration(days: 30));
      expect(
        capturedSince!.isAfter(before.subtract(const Duration(seconds: 2))),
        isTrue,
      );
      expect(
        capturedSince!.isBefore(after.add(const Duration(seconds: 2))),
        isTrue,
      );
    });

    test('advances cursor after successful poll', () async {
      final nextCursor = DateTime.utc(2025, 6, 1, 12, 0, 0);
      final client = _mockClient([], nextCursor: nextCursor);

      final service = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client,
      );

      await service.poll();

      // Second poll should use the advanced cursor
      DateTime? capturedSince;
      final client2 = MockClient((request) async {
        if (request.url.path == '/api/v1/notifications') {
          capturedSince = DateTime.parse(request.url.queryParameters['since']!);
          return http.Response(
            jsonEncode({
              'items': <dynamic>[],
              'next_cursor': DateTime.now().toUtc().toIso8601String(),
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final service2 = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client2,
      );

      await service2.poll();
      expect(capturedSince, equals(nextCursor));
    });

    test('handles server error gracefully', () async {
      final client = MockClient((request) async {
        return http.Response('internal server error', 500);
      });

      final service = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client,
      );

      // Should not throw
      await service.poll();
    });
  });

  group('NotificationPollService — deduplication', () {
    test('skips already-seen notification IDs', () async {
      SharedPreferences.setMockInitialValues({
        'notification_recent_ids': ['env-1'],
      });

      final envelopes = [
        _buildEnvelope(id: 'env-1', action: 'sent'),
        _buildEnvelope(
          id: 'env-2',
          action: 'sent',
          extraPayload: {
            'questionnaire_instance_id': 'inst-new',
            'questionnaire_type': 'nose_hht',
          },
        ),
      ];
      final client = _mockClient(envelopes);

      final service = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client,
      );

      await service.poll();

      // Only env-2 should have been dispatched (env-1 was deduped)
      final prefs = await SharedPreferences.getInstance();
      final recentIds = prefs.getStringList('notification_recent_ids')!;
      expect(recentIds, contains('env-1'));
      expect(recentIds, contains('env-2'));
    });

    test('trims dedupe set to 500-cap FIFO', () async {
      // Pre-fill with 499 IDs
      final existingIds = List.generate(499, (i) => 'old-$i');
      SharedPreferences.setMockInitialValues({
        'notification_recent_ids': existingIds,
      });

      // Add 3 new envelopes (total would be 502, expect trim to 500)
      final envelopes = [
        _buildEnvelope(id: 'new-1', action: 'sent'),
        _buildEnvelope(id: 'new-2', action: 'sent'),
        _buildEnvelope(id: 'new-3', action: 'sent'),
      ];
      final client = _mockClient(envelopes);

      final service = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client,
      );

      await service.poll();

      final prefs = await SharedPreferences.getInstance();
      final recentIds = prefs.getStringList('notification_recent_ids')!;
      expect(recentIds.length, equals(500));
      // Oldest entries should be trimmed (old-0, old-1 gone)
      expect(recentIds, isNot(contains('old-0')));
      expect(recentIds, isNot(contains('old-1')));
      // Newest should be present
      expect(recentIds, contains('new-1'));
      expect(recentIds, contains('new-2'));
      expect(recentIds, contains('new-3'));
    });

    test('cross-cycle dedupe — second poll skips already-dispatched', () async {
      final envelopes = [
        _buildEnvelope(
          id: 'env-A',
          action: 'sent',
          extraPayload: {
            'questionnaire_instance_id': 'inst-A',
            'questionnaire_type': 'nose_hht',
          },
        ),
      ];
      final client = _mockClient(envelopes);

      final service = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client,
      );

      await service.poll();

      // Second poll with same envelope
      final service2 = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client,
      );

      await service2.poll();

      // Task only added once
      expect(taskService.taskCount, equals(1));
    });
  });

  group('NotificationPollService — dispatch routing', () {
    test('questionnaire_update + sent → handleQuestionnaireSent', () async {
      final envelopes = [
        _buildEnvelope(
          id: 'q-sent-1',
          type: 'questionnaire_update',
          action: 'sent',
          extraPayload: {
            'questionnaire_instance_id': 'inst-100',
            'questionnaire_type': 'nose_hht',
            'status': 'sent',
            'study_event': 'visit_1',
            'version': 1,
            'sent_at': '2024-01-01T00:00:00Z',
          },
        ),
      ];
      final client = _mockClient(envelopes);

      final service = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client,
      );

      await service.poll();
      expect(taskService.taskCount, equals(1));
      expect(taskService.tasks[0].id, equals('inst-100'));
    });

    test('questionnaire_update + new_task (legacy) → adds task', () async {
      final envelopes = [
        _buildEnvelope(
          id: 'q-new-1',
          type: 'questionnaire_update',
          action: 'new_task',
          extraPayload: {
            'questionnaire_instance_id': 'inst-200',
            'questionnaire_type': 'qol',
            'status': 'sent',
            'study_event': 'visit_2',
            'version': 1,
            'sent_at': '2024-02-01T00:00:00Z',
          },
        ),
      ];
      final client = _mockClient(envelopes);

      final service = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client,
      );

      await service.poll();
      expect(taskService.taskCount, equals(1));
      expect(taskService.tasks[0].id, equals('inst-200'));
    });

    test('questionnaire_update + deleted → removes task', () async {
      // Pre-add a task via sent
      final sentEnvelopes = [
        _buildEnvelope(
          id: 'q-add',
          type: 'questionnaire_update',
          action: 'sent',
          extraPayload: {
            'questionnaire_instance_id': 'inst-300',
            'questionnaire_type': 'nose_hht',
            'status': 'sent',
            'study_event': 'visit_1',
            'version': 1,
            'sent_at': '2024-01-01T00:00:00Z',
          },
        ),
      ];
      final client1 = _mockClient(sentEnvelopes);
      final service1 = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client1,
      );
      await service1.poll();
      expect(taskService.taskCount, equals(1));

      // Now delete it
      final deletedEnvelopes = [
        _buildEnvelope(
          id: 'q-del',
          type: 'questionnaire_update',
          action: 'deleted',
          extraPayload: {'questionnaire_instance_id': 'inst-300'},
        ),
      ];
      final client2 = _mockClient(deletedEnvelopes);
      final service2 = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client2,
      );
      await service2.poll();
      expect(taskService.taskCount, equals(0));
    });

    test(
      'questionnaire_update + remove_task (legacy) → removes task',
      () async {
        // Pre-add
        final sentEnvelopes = [
          _buildEnvelope(
            id: 'q-add2',
            type: 'questionnaire_update',
            action: 'new_task',
            extraPayload: {
              'questionnaire_instance_id': 'inst-301',
              'questionnaire_type': 'qol',
              'status': 'sent',
              'study_event': 'visit_1',
              'version': 1,
              'sent_at': '2024-01-01T00:00:00Z',
            },
          ),
        ];
        final client1 = _mockClient(sentEnvelopes);
        final service1 = NotificationPollService(
          enrollmentService: mockEnrollment,
          taskService: taskService,
          httpClient: client1,
        );
        await service1.poll();
        expect(taskService.taskCount, equals(1));

        // Remove
        final delEnvelopes = [
          _buildEnvelope(
            id: 'q-rm',
            type: 'questionnaire_update',
            action: 'remove_task',
            extraPayload: {'questionnaire_instance_id': 'inst-301'},
          ),
        ];
        final client2 = _mockClient(delEnvelopes);
        final service2 = NotificationPollService(
          enrollmentService: mockEnrollment,
          taskService: taskService,
          httpClient: client2,
        );
        await service2.poll();
        expect(taskService.taskCount, equals(0));
      },
    );

    test('patient_status_update + disconnect → sets disconnected', () async {
      final envelopes = [
        _buildEnvelope(
          id: 'ps-1',
          type: 'patient_status_update',
          action: 'disconnect',
        ),
      ];
      final client = _mockClient(envelopes);

      final service = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client,
      );

      await service.poll();
      expect(await mockEnrollment.isDisconnected(), isTrue);
    });

    test('patient_status_update + reconnect → clears disconnected', () async {
      await mockEnrollment.setDisconnected(true);

      final envelopes = [
        _buildEnvelope(
          id: 'ps-2',
          type: 'patient_status_update',
          action: 'reconnect',
        ),
      ];
      final client = _mockClient(envelopes);

      final service = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client,
      );

      await service.poll();
      expect(await mockEnrollment.isDisconnected(), isFalse);
    });

    test(
      'patient_status_update + mark_not_participating → sets state',
      () async {
        final envelopes = [
          _buildEnvelope(
            id: 'ps-3',
            type: 'patient_status_update',
            action: 'mark_not_participating',
          ),
        ];
        final client = _mockClient(envelopes);

        final service = NotificationPollService(
          enrollmentService: mockEnrollment,
          taskService: taskService,
          httpClient: client,
        );

        await service.poll();
        expect(await mockEnrollment.isNotParticipating(), isTrue);
      },
    );

    test(
      'patient_status_update + reactivate → clears not-participating',
      () async {
        await mockEnrollment.setNotParticipating(true, at: DateTime.now());

        final envelopes = [
          _buildEnvelope(
            id: 'ps-4',
            type: 'patient_status_update',
            action: 'reactivate',
          ),
        ];
        final client = _mockClient(envelopes);

        final service = NotificationPollService(
          enrollmentService: mockEnrollment,
          taskService: taskService,
          httpClient: client,
        );

        await service.poll();
        expect(await mockEnrollment.isNotParticipating(), isFalse);
      },
    );

    test('patient_status_update + start_trial → no-op', () async {
      final envelopes = [
        _buildEnvelope(
          id: 'ps-5',
          type: 'patient_status_update',
          action: 'start_trial',
        ),
      ];
      final client = _mockClient(envelopes);

      final service = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client,
      );

      await service.poll();
      // No state change
      expect(await mockEnrollment.isDisconnected(), isFalse);
      expect(await mockEnrollment.isNotParticipating(), isFalse);
    });

    test('reminder type → ignored (no state change)', () async {
      final envelopes = [
        _buildEnvelope(id: 'rem-1', type: 'reminder', action: 'yesterday'),
      ];
      final client = _mockClient(envelopes);

      final service = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client,
      );

      await service.poll();
      expect(taskService.taskCount, equals(0));
    });
  });

  group('NotificationPollService — lifecycle reset', () {
    test('clearCursor removes both keys', () async {
      SharedPreferences.setMockInitialValues({
        'notification_lastSeen': '2025-01-01T00:00:00.000Z',
        'notification_recent_ids': ['id-1', 'id-2'],
      });

      await NotificationPollService.clearCursor();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('notification_lastSeen'), isNull);
      expect(prefs.getStringList('notification_recent_ids'), isNull);
    });

    test('after clearCursor, poll uses bootstrap window', () async {
      // Set a cursor in the future to prove it gets cleared
      SharedPreferences.setMockInitialValues({
        'notification_lastSeen': '2099-01-01T00:00:00.000Z',
      });

      await NotificationPollService.clearCursor();

      DateTime? capturedSince;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/notifications') {
          capturedSince = DateTime.parse(request.url.queryParameters['since']!);
          return http.Response(
            jsonEncode({
              'items': <dynamic>[],
              'next_cursor': DateTime.now().toUtc().toIso8601String(),
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final service = NotificationPollService(
        enrollmentService: mockEnrollment,
        taskService: taskService,
        httpClient: client,
      );

      await service.poll();

      // Should use bootstrap window (~30 days ago), not 2099
      expect(capturedSince!.year, isNot(equals(2099)));
      expect(capturedSince!.isBefore(DateTime.now().toUtc()), isTrue);
    });
  });
}
