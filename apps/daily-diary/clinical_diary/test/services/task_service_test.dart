// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00081: Patient Task System
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//
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

        expect(service.taskCount, equals(2));
        expect(service.tasks[0].id, equals('inst-001'));
        expect(service.tasks[1].id, equals('inst-002'));
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

        await service.syncTasks(mockEnrollment);
        expect(service.taskCount, equals(2));

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

        // Sync twice — task count should still be 1
        await service.syncTasks(mockEnrollment);
        await service.syncTasks(mockEnrollment);

        expect(service.taskCount, equals(1));
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
    });
  });
}
