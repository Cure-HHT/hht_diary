// Unit tests for TaskService.syncTasks()

import 'dart:convert';

import 'package:clinical_diary/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trial_data_types/trial_data_types.dart';

import '../helpers/mock_enrollment_service.dart';
import '../test_helpers/flavor_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestFlavor();

  // Verifies: DIARY-GUI-participant-task-list/A+C+D
  // Verifies: DIARY-PRD-questionnaire-portal-sent-rules
  group('TaskService', () {
    late MockEnrollmentService mockEnrollment;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockEnrollment = MockEnrollmentService()
        ..jwtToken = 'test-jwt'
        ..backendUrl = 'https://test-backend.example.com';
    });

    group('syncTasks', () {
      test('adds new tasks from server response', () async {
        final client = MockClient((request) async {
          expect(request.url.path, equals('/api/v1/user/tasks'));
          expect(request.headers['Authorization'], equals('Bearer test-jwt'));

          return http.Response(
            jsonEncode({
              'tasks': [
                {
                  'questionnaire_instance_id': 'inst-001',
                  'questionnaire_type': 'eq',
                  'status': 'sent',
                  'study_event': 'screening',
                  'version': 1,
                  'sent_at': '2024-01-01T00:00:00Z',
                },
                {
                  'questionnaire_instance_id': 'inst-002',
                  'questionnaire_type': 'nose_hht',
                  'status': 'sent',
                  'study_event': 'visit_1',
                  'version': 1,
                  'sent_at': '2024-01-02T00:00:00Z',
                },
              ],
              'mobileLinkingStatus': 'connected',
              'isDisconnected': false,
            }),
            200,
          );
        });

        final service = TaskService(httpClient: client);
        await service.syncTasks(mockEnrollment);

        // eq is filtered out (CUR-1050), only nose_hht task added
        expect(service.taskCount, equals(1));
        expect(service.tasks[0].id, equals('inst-002'));
        expect(service.tasks[0].taskType, equals(TaskType.questionnaire));
      });

      test('removes local questionnaire tasks not on server', () async {
        // First sync: add two tasks
        var callCount = 0;
        final client = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response(
              jsonEncode({
                'tasks': [
                  {
                    'questionnaire_instance_id': 'inst-001',
                    'questionnaire_type': 'eq',
                    'status': 'sent',
                  },
                  {
                    'questionnaire_instance_id': 'inst-002',
                    'questionnaire_type': 'nose_hht',
                    'status': 'sent',
                  },
                ],
                'isDisconnected': false,
              }),
              200,
            );
          }
          // Second sync: only one task remains
          return http.Response(
            jsonEncode({
              'tasks': [
                {
                  'questionnaire_instance_id': 'inst-002',
                  'questionnaire_type': 'nose_hht',
                  'status': 'sent',
                },
              ],
              'isDisconnected': false,
            }),
            200,
          );
        });

        final service = TaskService(httpClient: client);

        // First sync: eq is filtered, only nose_hht added (CUR-1050)
        await service.syncTasks(mockEnrollment);
        expect(service.taskCount, equals(1));

        await service.syncTasks(mockEnrollment);
        expect(service.taskCount, equals(1));
        expect(service.tasks[0].id, equals('inst-002'));
      });

      test('leaves non-questionnaire tasks untouched', () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'tasks': <Map<String, dynamic>>[],
              'isDisconnected': false,
            }),
            200,
          );
        });

        final service = TaskService(httpClient: client)
          // Add a non-questionnaire task manually
          ..addTask(
            Task(
              id: 'incomplete-1',
              taskType: TaskType.incompleteRecord,
              title: 'Incomplete Record',
              createdAt: DateTime.now(),
            ),
          );

        expect(service.taskCount, equals(1));

        // Sync returns empty tasks — should not remove the incomplete record
        await service.syncTasks(mockEnrollment);

        expect(service.taskCount, equals(1));
        expect(service.tasks[0].id, equals('incomplete-1'));
        expect(service.tasks[0].taskType, equals(TaskType.incompleteRecord));
      });

      test('handles 401 gracefully', () async {
        final client = MockClient((request) async {
          return http.Response('{"error": "Unauthorized"}', 401);
        });

        final service = TaskService(httpClient: client);
        // Should not throw
        await service.syncTasks(mockEnrollment);
        expect(service.taskCount, equals(0));
      });

      test('handles 500 gracefully', () async {
        final client = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final service = TaskService(httpClient: client);
        await service.syncTasks(mockEnrollment);
        expect(service.taskCount, equals(0));
      });

      test('handles empty tasks list', () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'tasks': <Map<String, dynamic>>[],
              'isDisconnected': false,
            }),
            200,
          );
        });

        final service = TaskService(httpClient: client);
        await service.syncTasks(mockEnrollment);
        expect(service.taskCount, equals(0));
      });

      test('skips sync when no JWT', () async {
        mockEnrollment.jwtToken = null;
        var requestMade = false;

        final client = MockClient((request) async {
          requestMade = true;
          return http.Response('', 200);
        });

        final service = TaskService(httpClient: client);
        await service.syncTasks(mockEnrollment);

        expect(requestMade, isFalse);
      });

      test('skips sync when no backend URL', () async {
        mockEnrollment.backendUrl = null;
        var requestMade = false;

        final client = MockClient((request) async {
          requestMade = true;
          return http.Response('', 200);
        });

        final service = TaskService(httpClient: client);
        await service.syncTasks(mockEnrollment);

        expect(requestMade, isFalse);
      });

      test('processes disconnection status from response', () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'tasks': <Map<String, dynamic>>[],
              'mobileLinkingStatus': 'disconnected',
              'isDisconnected': true,
            }),
            200,
          );
        });

        final service = TaskService(httpClient: client);
        await service.syncTasks(mockEnrollment);

        expect(await mockEnrollment.isDisconnected(), isTrue);
      });

      test('does not duplicate existing tasks', () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'tasks': [
                {
                  'questionnaire_instance_id': 'inst-001',
                  'questionnaire_type': 'eq',
                  'status': 'sent',
                },
              ],
              'isDisconnected': false,
            }),
            200,
          );
        });

        final service = TaskService(httpClient: client);

        // Sync twice — eq is filtered out, task count stays 0 (CUR-1050)
        await service.syncTasks(mockEnrollment);
        await service.syncTasks(mockEnrollment);

        expect(service.taskCount, equals(0));
      });

      test('handles network error gracefully', () async {
        final client = MockClient((request) async {
          throw Exception('Network error');
        });

        final service = TaskService(httpClient: client);
        // Should not throw
        await service.syncTasks(mockEnrollment);
        expect(service.taskCount, equals(0));
      });

      test(
        'carries portal-reported status through sync (characterization)',
        () async {
          // Verifies: DIARY-GUI-participant-task-list/J — portal-reported status
          //   survives the full syncTasks path end-to-end.
          final client = MockClient((request) async {
            return http.Response(
              jsonEncode({
                'tasks': [
                  {
                    'questionnaire_instance_id': 'inst-fin-001',
                    'questionnaire_type': 'nose_hht',
                    'status': 'finalized',
                    'study_event': 'visit_1',
                    'version': 1,
                    'sent_at': '2024-01-01T00:00:00Z',
                  },
                ],
                'isDisconnected': false,
              }),
              200,
            );
          });

          final service = TaskService(httpClient: client);
          await service.syncTasks(mockEnrollment);

          expect(service.taskCount, equals(1));
          expect(service.tasks.single.status, equals('finalized'));
        },
      );

      test('refreshes the status of an already-present task when the server '
          'reports a new status (sent -> finalized)', () async {
        // Verifies: DIARY-GUI-participant-task-list/J — a synced status change
        //   on an already-present task is reflected on the in-memory Task, so
        //   the read-only / completed gate can engage on portal finalization.
        var callCount = 0;
        final client = MockClient((request) async {
          callCount++;
          final status = callCount == 1 ? 'sent' : 'finalized';
          return http.Response(
            jsonEncode({
              'tasks': [
                {
                  'questionnaire_instance_id': 'inst-xfer',
                  'questionnaire_type': 'nose_hht',
                  'status': status,
                  'study_event': 'visit_1',
                  'version': 1,
                  'sent_at': '2024-01-01T00:00:00Z',
                },
              ],
              'isDisconnected': false,
            }),
            200,
          );
        });

        final service = TaskService(httpClient: client);

        // First sync: the task arrives as 'sent'.
        await service.syncTasks(mockEnrollment);
        expect(service.taskCount, equals(1));
        expect(service.tasks.single.status, equals('sent'));

        // Second sync: same instance, now 'finalized'. The already-present
        // task must be refreshed (not frozen at 'sent').
        var notified = false;
        service.addListener(() => notified = true);
        await service.syncTasks(mockEnrollment);

        expect(service.taskCount, equals(1));
        expect(service.tasks.single.status, equals('finalized'));
        // A status change must notify listeners (drives the home-screen gate).
        expect(notified, isTrue);

        // Persistence: a fresh service loading from storage sees 'finalized'.
        final reloaded = TaskService(
          httpClient: MockClient((_) async => http.Response('', 200)),
        );
        await reloaded.loadTasks();
        expect(reloaded.tasks.single.status, equals('finalized'));
      });

      test(
        'an unchanged already-present task does not re-notify or re-add',
        () async {
          final client = MockClient((request) async {
            return http.Response(
              jsonEncode({
                'tasks': [
                  {
                    'questionnaire_instance_id': 'inst-stable',
                    'questionnaire_type': 'nose_hht',
                    'status': 'sent',
                  },
                ],
                'isDisconnected': false,
              }),
              200,
            );
          });

          final service = TaskService(httpClient: client);
          await service.syncTasks(mockEnrollment);
          expect(service.taskCount, equals(1));

          var notified = false;
          service.addListener(() => notified = true);
          // Re-sync identical data: no change, no duplicate, no notify.
          await service.syncTasks(mockEnrollment);

          expect(service.taskCount, equals(1));
          expect(notified, isFalse);
        },
      );

      test(
        // Verifies: DIARY-DEV-inbound-event-on-receipt/B (recalled status carried into the Task model)
        'a recalled task with null questionnaire_type is parsed without crashing',
        () async {
          final client = MockClient((request) async {
            return http.Response(
              jsonEncode({
                'tasks': [
                  {
                    'questionnaire_instance_id': 'QI-9',
                    'questionnaire_type': null,
                    'status': 'recalled',
                    'study_event': 'Cycle 4 Day 1',
                  },
                ],
                'isDisconnected': false,
              }),
              200,
            );
          });

          final service = TaskService(httpClient: client);
          await service.syncTasks(mockEnrollment);

          expect(service.taskCount, equals(1));
          expect(service.tasks.single.id, equals('QI-9'));
          expect(service.tasks.single.status, equals('recalled'));
          expect(service.tasks.single.questionnaireType, isNull);
        },
      );

      test('skips eq type tasks (CUR-1050)', () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'tasks': [
                {
                  'questionnaire_instance_id': 'eq-inst-001',
                  'questionnaire_type': 'eq',
                  'status': 'sent',
                },
              ],
              'isDisconnected': false,
            }),
            200,
          );
        });

        final service = TaskService(httpClient: client);
        await service.syncTasks(mockEnrollment);

        // EQ tasks must never appear in the participant to-do list
        expect(service.taskCount, equals(0));
      });
    });

    group('handleFcmMessage', () {
      test('questionnaire_sent adds questionnaire task for nose_hht', () {
        final service =
            TaskService(
              httpClient: MockClient((_) async => http.Response('', 200)),
            )..handleFcmMessage({
              'type': 'questionnaire_sent',
              'questionnaire_instance_id': 'nose-inst-001',
              'questionnaire_type': 'nose_hht',
              'status': 'sent',
            });

        expect(service.taskCount, equals(1));
        expect(service.tasks[0].id, equals('nose-inst-001'));
      });

      test('questionnaire_sent ignores eq type (CUR-1050)', () {
        final service =
            TaskService(
              httpClient: MockClient((_) async => http.Response('', 200)),
            )..handleFcmMessage({
              'type': 'questionnaire_sent',
              'questionnaire_instance_id': 'eq-inst-001',
              'questionnaire_type': 'eq',
              'status': 'sent',
            });

        // EQ tasks must never appear in the participant to-do list
        expect(service.taskCount, equals(0));
      });

      test('questionnaire_deleted removes existing task', () {
        final service =
            TaskService(
              httpClient: MockClient((_) async => http.Response('', 200)),
            )..handleFcmMessage({
              'type': 'questionnaire_sent',
              'questionnaire_instance_id': 'nose-inst-001',
              'questionnaire_type': 'nose_hht',
              'status': 'sent',
            });
        expect(service.taskCount, equals(1));

        service.handleFcmMessage({
          'type': 'questionnaire_deleted',
          'questionnaire_instance_id': 'nose-inst-001',
        });
        expect(service.taskCount, equals(0));
      });

      test('questionnaire_assigned invokes onSyncRequested exactly once', () {
        var syncCount = 0;
        TaskService(httpClient: MockClient((_) async => http.Response('', 200)))
          ..onSyncRequested = (() async => syncCount++)
          ..handleFcmMessage({
            'type': 'questionnaire_assigned',
            'flowToken': 'tok-abc123',
          });

        expect(syncCount, equals(1));
      });

      test('questionnaire_assigned does not create a phantom task', () {
        var syncCount = 0;
        final service =
            TaskService(
                httpClient: MockClient((_) async => http.Response('', 200)),
              )
              ..onSyncRequested = (() async => syncCount++)
              // Nudge carries no instance data — it must only trigger a sync,
              // never fabricate a task locally.
              ..handleFcmMessage({
                'type': 'questionnaire_assigned',
                'flowToken': 'tok-abc123',
              });

        expect(service.taskCount, equals(0));
        expect(syncCount, equals(1));
      });

      test('questionnaire_assigned is a no-op when no callback wired', () {
        // No onSyncRequested set — must not throw, must not add a task.
        final service =
            TaskService(
              httpClient: MockClient((_) async => http.Response('', 200)),
            )..handleFcmMessage({
              'type': 'questionnaire_assigned',
              'flowToken': 'tok-abc123',
            });

        expect(service.taskCount, equals(0));
      });

      test('unknown message type is a no-op', () {
        var syncCount = 0;
        final service =
            TaskService(
                httpClient: MockClient((_) async => http.Response('', 200)),
              )
              ..onSyncRequested = (() async => syncCount++)
              ..handleFcmMessage({'type': 'something_else'});

        expect(service.taskCount, equals(0));
        expect(syncCount, equals(0));
      });
    });

    group('removeTask (completion transition)', () {
      test('removes the task, notifies, and persists', () async {
        final service =
            TaskService(
              httpClient: MockClient((_) async => http.Response('', 200)),
            )..handleFcmMessage({
              'type': 'questionnaire_sent',
              'questionnaire_instance_id': 'nose-inst-001',
              'questionnaire_type': 'nose_hht',
              'status': 'sent',
            });
        expect(service.taskCount, equals(1));

        var notified = false;
        service
          ..addListener(() => notified = true)
          // Simulate the home_screen onComplete path.
          ..removeTask('nose-inst-001');

        expect(service.taskCount, equals(0));
        expect(notified, isTrue);

        // Persistence: a fresh service loading from storage sees no task.
        final reloaded = TaskService(
          httpClient: MockClient((_) async => http.Response('', 200)),
        );
        await reloaded.loadTasks();
        expect(reloaded.taskCount, equals(0));
      });
    });
  });
}
