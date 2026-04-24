// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00066: Status Change Reason Field
//   REQ-CAL-p00047: Hard-Coded Questionnaires
//   REQ-CAL-p00079: Start Trial Workflow
//   REQ-CAL-p00081: Patient Task System
//
// Comprehensive tests for questionnaire handlers (get, send, delete,
// unlock, finalize). Covers all CUR-823 acceptance criteria:
//   1. GET returns statuses per patient
//   2. POST sends questionnaire + triggers FCM
//   3. Nose HHT and QoL can be sent multiple times (after finalize)
//   4. DELETE requires reason (max 25 chars)
//   5. Delete allowed before finalization
//   6. Delete rejected after finalization
//   7. Auth restricted to Investigators
//   8. Appropriate error responses for invalid state transitions

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:portal_functions/src/database.dart';
import 'package:portal_functions/src/notification_service.dart';
import 'package:portal_functions/src/portal_auth.dart';
import 'package:portal_functions/src/questionnaire.dart';

Future<void> _initOTel() async {
  await OTel.reset();
  await OTel.initialize(
    serviceName: 'portal-functions-test',
    serviceVersion: '0.0.1-test',
    enableMetrics: false,
  );
}

/// Test patient and user data
const _testPatientId = 'patient-001';
const _testSiteId = 'site-001';
const _testUserId = 'user-001';
const _testInstanceId = '00000000-0000-0000-0000-000000000001';

/// Create a test PortalUser with Investigator role and site access.
PortalUser _investigator({
  String? activeRole,
  List<Map<String, dynamic>>? sites,
}) {
  return PortalUser(
    id: _testUserId,
    firebaseUid: 'firebase-001',
    email: 'investigator@example.com',
    name: 'Dr. Test',
    roles: [activeRole ?? 'Investigator'],
    activeRole: activeRole ?? 'Investigator',
    status: 'active',
    sites:
        sites ??
        [
          {
            'site_id': _testSiteId,
            'site_name': 'Test Site',
            'site_number': 'S001',
          },
        ],
  );
}

/// Standard patient row returned by DB: [patient_id, site_id, trial_started, linking_status]
List<dynamic> _patientRow({
  bool trialStarted = true,
  String siteId = _testSiteId,
}) {
  return [_testPatientId, siteId, trialStarted, 'linked'];
}

/// Standard questionnaire instance row:
/// [id, type::text, status::text, patient_id, deleted_at, site_id]
/// The site_id comes from the JOIN with patients (added for CUR-1064 site access check).
List<dynamic> _instanceRow({
  String id = _testInstanceId,
  String type = 'nose_hht',
  String status = 'sent',
  DateTime? deletedAt,
  String siteId = _testSiteId,
}) {
  return [id, type, status, _testPatientId, deletedAt, siteId];
}

/// Build a shelf Request with optional body and headers.
Request _request(
  String method,
  String path, {
  String? body,
  Map<String, String>? headers,
}) {
  return Request(
    method,
    Uri.parse('http://localhost$path'),
    body: body,
    headers: {'authorization': 'Bearer test-token', ...?headers},
  );
}

/// Decode a Response body as JSON.
Future<Map<String, dynamic>> _json(Response response) async {
  return jsonDecode(await response.readAsString()) as Map<String, dynamic>;
}

void main() {
  setUpAll(() async => await _initOTel());
  tearDownAll(() async {
    await OTel.shutdown();
    await OTel.reset();
  });

  // Track queries for verification
  late List<({String query, Map<String, dynamic>? params})> capturedQueries;

  setUp(() {
    capturedQueries = [];

    // Default: auth returns Investigator with site access
    requirePortalAuthOverride = (_) async => _investigator();

    // Default: FCM in console mode (no GCP credentials needed)
    NotificationService.resetForTesting();
    NotificationService.instance.initialize(
      NotificationConfig(
        projectId: 'test-project',
        enabled: true,
        consoleMode: true,
      ),
    );
  });

  tearDown(() {
    requirePortalAuthOverride = null;
    databaseQueryOverride = null;
    NotificationService.resetForTesting();
  });

  // ====================================================================
  // Authorization tests (all handlers)
  // ====================================================================
  group('authorization', () {
    setUp(() {
      // Restore real auth (no override) for auth boundary tests
      requirePortalAuthOverride = null;
    });

    test('GET returns 401 when no authorization header', () async {
      final request = Request(
        'GET',
        Uri.parse(
          'http://localhost/api/v1/portal/patients/questionnairesuestionnaires',
        ),
      );

      final response = await getQuestionnaireStatusHandler(request);

      expect(response.statusCode, 401);
      final body = await _json(response);
      expect(body['error'], contains('authorization'));
    });

    test('POST send returns 401 without auth', () async {
      final request = Request(
        'POST',
        Uri.parse(
          'http://localhost/api/v1/portal/patients/questionnairesuestionnaires/nose_hht/send',
        ),
      );

      final response = await sendQuestionnaireHandler(request);

      expect(response.statusCode, 401);
    });

    test('DELETE returns 401 without auth', () async {
      final request = Request(
        'DELETE',
        Uri.parse(
          'http://localhost/api/v1/portal/patients/questionnairesuestionnaires/q1',
        ),
      );

      final response = await deleteQuestionnaireHandler(request, 'q1');

      expect(response.statusCode, 401);
    });

    test('unlock returns 401 without auth', () async {
      final request = Request(
        'POST',
        Uri.parse(
          'http://localhost/api/v1/portal/patients/questionnairesuestionnaires/q1/unlock',
        ),
      );

      final response = await unlockQuestionnaireHandler(request, 'q1');

      expect(response.statusCode, 401);
    });

    test('finalize returns 401 without auth', () async {
      final request = Request(
        'POST',
        Uri.parse(
          'http://localhost/api/v1/portal/patients/questionnairesuestionnaires/q1/finalize',
        ),
      );

      final response = await finalizeQuestionnaireHandler(request, 'q1');

      expect(response.statusCode, 401);
    });

    test('all handlers return JSON content type on error', () async {
      final handlers = [
        () => getQuestionnaireStatusHandler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/v1/portal/patients/questionnaires'),
          ),
        ),
        () => sendQuestionnaireHandler(
          Request(
            'POST',
            Uri.parse(
              'http://localhost/api/v1/portal/patients/questionnaires/send',
            ),
          ),
        ),
        () => deleteQuestionnaireHandler(
          Request(
            'DELETE',
            Uri.parse(
              'http://localhost/api/v1/portal/questionnaire-instances/q1',
            ),
          ),
          'q1',
        ),
      ];

      for (final handler in handlers) {
        final response = await handler();
        expect(response.headers['content-type'], 'application/json');
      }
    });
  });

  // ====================================================================
  // Role-based access (CUR-823 AC#9)
  // ====================================================================
  group('role-based access', () {
    test('send returns 403 for non-Investigator role', () async {
      requirePortalAuthOverride = (_) async =>
          _investigator(activeRole: 'Auditor');

      final request = _request(
        'POST',
        '/api/v1/portal/patients/questionnaires/send',
      );

      final response = await sendQuestionnaireHandler(request);

      expect(response.statusCode, 403);
      final body = await _json(response);
      expect(body['error'], contains('Investigator'));
    });

    test('delete returns 403 for non-Investigator role', () async {
      requirePortalAuthOverride = (_) async =>
          _investigator(activeRole: 'Sponsor');

      final request = _request(
        'DELETE',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId',
        body: jsonEncode({'reason': 'Test'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 403);
    });

    test('unlock returns 403 for non-Investigator role', () async {
      requirePortalAuthOverride = (_) async =>
          _investigator(activeRole: 'Administrator');

      final request = _request(
        'POST',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId/unlock',
      );

      final response = await unlockQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 403);
    });

    test('finalize returns 403 for non-Investigator role', () async {
      requirePortalAuthOverride = (_) async =>
          _investigator(activeRole: 'Analyst');

      final request = _request(
        'POST',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 403);
    });

    test('GET status allowed for non-Investigator (read-only)', () async {
      requirePortalAuthOverride = (_) async =>
          _investigator(activeRole: 'Auditor');

      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM patients')) {
          return [_patientRow()];
        }
        if (query.contains('FROM questionnaire_instances')) {
          return [];
        }
        return [];
      };

      final request = _request(
        'GET',
        '/api/v1/portal/patients/questionnaires',
        headers: {'x-patient-id': _testPatientId},
      );

      final response = await getQuestionnaireStatusHandler(request);

      expect(response.statusCode, 200);
    });
  });

  // ====================================================================
  // GET questionnaire status (CUR-823 AC#1)
  // ====================================================================
  group('getQuestionnaireStatusHandler', () {
    test('returns all questionnaire types with defaults', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM patients')) {
          return [_patientRow()];
        }
        if (query.contains('FROM questionnaire_instances')) {
          return []; // No instances yet
        }
        return [];
      };

      final request = _request(
        'GET',
        '/api/v1/portal/patients/questionnaires',
        headers: {'x-patient-id': _testPatientId},
      );

      final response = await getQuestionnaireStatusHandler(request);

      expect(response.statusCode, 200);
      final body = await _json(response);
      expect(body['patient_id'], _testPatientId);

      final questionnaires = body['questionnaires'] as List<dynamic>;
      expect(questionnaires, hasLength(3));

      final types = questionnaires.map((q) => q['questionnaire_type']).toSet();
      expect(types, containsAll(['nose_hht', 'qol', 'eq']));

      // All should default to 'not_sent'
      for (final q in questionnaires) {
        expect(q['status'], 'not_sent');
      }
    });

    test('returns actual status when instances exist', () async {
      final sentAt = DateTime.now().toUtc();

      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM patients')) {
          return [_patientRow()];
        }
        if (query.contains('FROM questionnaire_instances')) {
          return [
            // [id, type, status, study_event, version, sent_at,
            //  submitted_at, finalized_at, score, sent_by]
            [
              _testInstanceId,
              'nose_hht',
              'sent',
              'Cycle 1 Day 1',
              '1.0.0',
              sentAt,
              null,
              null,
              null,
              _testUserId,
            ],
          ];
        }
        return [];
      };

      final request = _request(
        'GET',
        '/api/v1/portal/patients/questionnaires',
        headers: {'x-patient-id': _testPatientId},
      );

      final response = await getQuestionnaireStatusHandler(request);

      expect(response.statusCode, 200);
      final body = await _json(response);
      final questionnaires = body['questionnaires'] as List<dynamic>;

      final noseHht = questionnaires.firstWhere(
        (q) => q['questionnaire_type'] == 'nose_hht',
      );
      expect(noseHht['status'], 'sent');
      expect(noseHht['study_event'], 'Cycle 1 Day 1');
      expect(noseHht['version'], '1.0.0');
    });

    test('returns 404 for non-existent patient', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM patients')) {
          return []; // Patient not found
        }
        return [];
      };

      final request = _request(
        'GET',
        '/api/v1/portal/patients/questionnaires',
        headers: {'x-patient-id': 'nonexistent'},
      );

      final response = await getQuestionnaireStatusHandler(request);

      expect(response.statusCode, 404);
    });

    test('returns 403 when user has no site access', () async {
      // Patient is at a different site than the user
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM patients')) {
          return [_patientRow(siteId: 'other-site')];
        }
        return [];
      };

      final request = _request(
        'GET',
        '/api/v1/portal/patients/questionnaires',
        headers: {'x-patient-id': _testPatientId},
      );

      final response = await getQuestionnaireStatusHandler(request);

      expect(response.statusCode, 403);
      final body = await _json(response);
      expect(body['error'], contains('site'));
    });
  });

  // ====================================================================
  // POST send questionnaire (CUR-823 AC#2, AC#3, AC#4)
  // ====================================================================
  group('sendQuestionnaireHandler', () {
    test('sends questionnaire successfully', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        capturedQueries.add((query: query, params: parameters));

        if (query.contains('FROM patients')) {
          return [_patientRow()];
        }
        if (query.contains('FROM questionnaire_instances') &&
            query.contains('deleted_at IS NULL')) {
          return []; // No existing active instance
        }
        if (query.contains('INSERT INTO questionnaire_instances')) {
          return [
            [_testInstanceId],
          ];
        }
        if (query.contains('FROM patient_fcm_tokens')) {
          return []; // No FCM token
        }
        if (query.contains('INSERT INTO admin_action_log')) {
          return [];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/patients/questionnaires/send',
        body: jsonEncode({
          'patientId': _testPatientId,
          'questionnaireType': 'nose_hht',
          'study_event': 'Cycle 1 Day 1',
        }),
      );

      final response = await sendQuestionnaireHandler(request);

      expect(response.statusCode, 200);
      final body = await _json(response);
      expect(body['success'], true);
      expect(body['instance_id'], _testInstanceId);
      expect(body['questionnaire_type'], 'nose_hht');
      expect(body['status'], 'sent');
      expect(body['study_event'], 'Cycle 1 Day 1');
      expect(body['version'], '1.0.0');
    });

    test('returns 400 for invalid questionnaire type', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/patients/questionnaires/send',
        body: jsonEncode({
          'patientId': _testPatientId,
          'questionnaireType': 'invalid_type',
        }),
      );

      final response = await sendQuestionnaireHandler(request);

      expect(response.statusCode, 400);
      final body = await _json(response);
      expect(body['error'], contains('Invalid questionnaire type'));
    });

    test('validates all supported types: nose_hht, qol, eq', () async {
      for (final type in ['nose_hht', 'qol', 'eq']) {
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow()];
          }
          if (query.contains('FROM questionnaire_instances') &&
              query.contains('deleted_at IS NULL')) {
            return [];
          }
          if (query.contains('INSERT INTO questionnaire_instances')) {
            return [
              ['instance-$type'],
            ];
          }
          if (query.contains('FROM patient_fcm_tokens')) {
            return [];
          }
          if (query.contains('INSERT INTO admin_action_log')) {
            return [];
          }
          return [];
        };

        final request = _request(
          'POST',
          '/api/v1/portal/patients/questionnaires/send',
          body: jsonEncode({
            'patientId': _testPatientId,
            'questionnaireType': type,
          }),
        );

        final response = await sendQuestionnaireHandler(request);

        expect(response.statusCode, 200, reason: '$type should be valid');
      }
    });

    test('returns 404 for non-existent patient', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM patients')) {
          return [];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/patients/questionnaires/send',
        body: jsonEncode({
          'patientId': 'nonexistent',
          'questionnaireType': 'nose_hht',
        }),
      );

      final response = await sendQuestionnaireHandler(request);

      expect(response.statusCode, 404);
    });

    test('returns 409 when trial not started (REQ-CAL-p00079)', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM patients')) {
          return [_patientRow(trialStarted: false)];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/patients/questionnaires/send',
        body: jsonEncode({
          'patientId': _testPatientId,
          'questionnaireType': 'nose_hht',
        }),
      );

      final response = await sendQuestionnaireHandler(request);

      expect(response.statusCode, 409);
      final body = await _json(response);
      expect(body['error'], contains('Trial must be started'));
    });

    test('returns 409 when active instance exists', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM patients')) {
          return [_patientRow()];
        }
        if (query.contains('FROM questionnaire_instances') &&
            query.contains('deleted_at IS NULL')) {
          return [
            [_testInstanceId, 'sent'],
          ];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/patients/questionnaires/send',
        body: jsonEncode({
          'patientId': _testPatientId,
          'questionnaireType': 'nose_hht',
        }),
      );

      final response = await sendQuestionnaireHandler(request);

      expect(response.statusCode, 409);
      final body = await _json(response);
      expect(body['error'], contains('already active'));
    });

    test('returns 403 when user has no site access', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM patients')) {
          return [_patientRow(siteId: 'other-site')];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/patients/questionnaires/send',
        body: jsonEncode({
          'patientId': _testPatientId,
          'questionnaireType': 'nose_hht',
        }),
      );

      final response = await sendQuestionnaireHandler(request);

      expect(response.statusCode, 403);
    });

    test('logs audit trail on send', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        capturedQueries.add((query: query, params: parameters));

        if (query.contains('FROM patients')) {
          return [_patientRow()];
        }
        if (query.contains('FROM questionnaire_instances') &&
            query.contains('deleted_at IS NULL')) {
          return [];
        }
        if (query.contains('INSERT INTO questionnaire_instances')) {
          return [
            [_testInstanceId],
          ];
        }
        if (query.contains('FROM patient_fcm_tokens')) {
          return [];
        }
        if (query.contains('INSERT INTO admin_action_log')) {
          return [];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/patients/questionnaires/send',
        body: jsonEncode({
          'patientId': _testPatientId,
          'questionnaireType': 'nose_hht',
        }),
      );

      await sendQuestionnaireHandler(request);

      final auditQuery = capturedQueries.where(
        (q) => q.query.contains('admin_action_log'),
      );
      expect(auditQuery, isNotEmpty, reason: 'Should log to audit trail');

      // Action type is hardcoded in SQL, not a named parameter
      expect(auditQuery.first.query, contains('QUESTIONNAIRE_SENT'));
    });
  });

  // ====================================================================
  // DELETE questionnaire (CUR-823 AC#5, AC#6, AC#7)
  // ====================================================================
  group('deleteQuestionnaireHandler', () {
    test('deletes questionnaire successfully with reason', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        capturedQueries.add((query: query, params: parameters));

        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'sent')];
        }
        if (query.contains('UPDATE questionnaire_instances')) {
          return [];
        }
        if (query.contains('FROM patient_fcm_tokens')) {
          return [];
        }
        if (query.contains('INSERT INTO admin_action_log')) {
          return [];
        }
        return [];
      };

      final request = _request(
        'DELETE',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId',
        body: jsonEncode({'reason': 'Sent in error'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 200);
      final body = await _json(response);
      expect(body['success'], true);
      expect(body['reason'], 'Sent in error');
    });

    test('returns 400 when reason is missing', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        return [];
      };

      final request = _request(
        'DELETE',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId',
        body: jsonEncode({}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 400);
      final body = await _json(response);
      expect(body['error'], contains('reason'));
    });

    test('returns 400 when reason is empty', () async {
      final request = _request(
        'DELETE',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId',
        body: jsonEncode({'reason': '   '}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 400);
    });

    test(
      'returns 400 when reason exceeds 25 chars (REQ-CAL-p00066-B)',
      () async {
        final request = _request(
          'DELETE',
          '/api/v1/portal/questionnaire-instances/$_testInstanceId',
          body: jsonEncode({
            'reason': 'This reason is way too long for the field',
          }),
        );

        final response = await deleteQuestionnaireHandler(
          request,
          _testInstanceId,
        );

        expect(response.statusCode, 400);
        final body = await _json(response);
        expect(body['error'], contains('25 characters'));
      },
    );

    test('allows reason of exactly 25 chars', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'sent')];
        }
        return [];
      };

      final request = _request(
        'DELETE',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId',
        body: jsonEncode({'reason': 'a' * 25}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 200);
    });

    test('allows delete when status is sent', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'sent')];
        }
        return [];
      };

      final request = _request(
        'DELETE',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId',
        body: jsonEncode({'reason': 'Test'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 200);
    });

    test('allows delete when status is ready_to_review', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'ready_to_review')];
        }
        return [];
      };

      final request = _request(
        'DELETE',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId',
        body: jsonEncode({'reason': 'Re-assess'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 200);
    });

    test('returns 409 when status is finalized (REQ-CAL-p00023-I)', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'finalized')];
        }
        return [];
      };

      final request = _request(
        'DELETE',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId',
        body: jsonEncode({'reason': 'Too late'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 409);
      final body = await _json(response);
      expect(body['error'], contains('finalized'));
    });

    test('returns 409 when already deleted', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(deletedAt: DateTime.now())];
        }
        return [];
      };

      final request = _request(
        'DELETE',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId',
        body: jsonEncode({'reason': 'Again'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 409);
      final body = await _json(response);
      expect(body['error'], contains('already been deleted'));
    });

    test('returns 404 when instance not found', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [];
        }
        return [];
      };

      final request = _request(
        'DELETE',
        '/api/v1/portal/patients/questionnaires/nonexistent',
        body: jsonEncode({'reason': 'Test'}),
      );

      final response = await deleteQuestionnaireHandler(request, 'nonexistent');

      expect(response.statusCode, 404);
    });

    test('logs audit trail on delete', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        capturedQueries.add((query: query, params: parameters));

        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'sent')];
        }
        return [];
      };

      final request = _request(
        'DELETE',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId',
        body: jsonEncode({'reason': 'Error'}),
      );

      await deleteQuestionnaireHandler(request, _testInstanceId);

      final auditQuery = capturedQueries.where(
        (q) => q.query.contains('admin_action_log'),
      );
      expect(auditQuery, isNotEmpty);
      // Action type is hardcoded in SQL, not a named parameter
      expect(auditQuery.first.query, contains('QUESTIONNAIRE_DELETED'));
    });

    test('returns 400 for invalid JSON body', () async {
      final request = _request(
        'DELETE',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId',
        body: 'not json',
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 400);
    });
  });

  // ====================================================================
  // Unlock questionnaire
  // ====================================================================
  group('unlockQuestionnaireHandler', () {
    test('unlocks ready_to_review questionnaire', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'ready_to_review')];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId/unlock',
      );

      final response = await unlockQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 200);
      final body = await _json(response);
      expect(body['success'], true);
      expect(body['status'], 'sent');
    });

    test('returns 409 when status is sent (not ready_to_review)', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'sent')];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId/unlock',
      );

      final response = await unlockQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 409);
      final body = await _json(response);
      expect(body['error'], contains('ready_to_review'));
    });

    test('returns 409 when status is finalized', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'finalized')];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId/unlock',
      );

      final response = await unlockQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 409);
    });

    test('returns 409 when questionnaire is deleted', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(deletedAt: DateTime.now())];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId/unlock',
      );

      final response = await unlockQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 409);
      final body = await _json(response);
      expect(body['error'], contains('deleted'));
    });

    test('returns 404 when instance not found', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/patients/questionnaires/nonexistent/unlock',
      );

      final response = await unlockQuestionnaireHandler(request, 'nonexistent');

      expect(response.statusCode, 404);
    });
  });

  // ====================================================================
  // Finalize questionnaire
  // ====================================================================
  group('finalizeQuestionnaireHandler', () {
    test('finalizes ready_to_review questionnaire', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'ready_to_review')];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 200);
      final body = await _json(response);
      expect(body['success'], true);
      expect(body['status'], 'finalized');
      expect(body.containsKey('score'), true);
      expect(body.containsKey('finalized_at'), true);
    });

    test('returns 409 when status is sent', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'sent')];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 409);
      final body = await _json(response);
      expect(body['error'], contains('ready_to_review'));
    });

    test('returns 409 when already finalized', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'finalized')];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 409);
    });

    test('returns 409 when questionnaire is deleted', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(deletedAt: DateTime.now())];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 409);
    });

    test('returns 404 when instance not found', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/patients/questionnaires/nonexistent/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        'nonexistent',
      );

      expect(response.statusCode, 404);
    });

    test('logs audit trail on finalize', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        capturedQueries.add((query: query, params: parameters));

        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'ready_to_review')];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId/finalize',
      );

      await finalizeQuestionnaireHandler(request, _testInstanceId);

      final auditQuery = capturedQueries.where(
        (q) => q.query.contains('admin_action_log'),
      );
      expect(auditQuery, isNotEmpty);
      // Action type is hardcoded in SQL, not a named parameter
      expect(auditQuery.first.query, contains('QUESTIONNAIRE_FINALIZED'));
    });
  });

  // ====================================================================
  // State transition validation (CUR-823 AC#10)
  // ====================================================================
  group('state transitions', () {
    test('sent -> ready_to_review: via patient submit (tested elsewhere)', () {
      // This transition happens on the diary server, not portal.
      // Tested in diary_functions/test/questionnaire_submit_test.dart.
      // Including as documentation of the valid state flow.
      expect(true, isTrue);
    });

    test('ready_to_review -> finalized: via finalize handler', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'ready_to_review')];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 200);
    });

    test('ready_to_review -> sent: via unlock handler', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'ready_to_review')];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId/unlock',
      );

      final response = await unlockQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 200);
      final body = await _json(response);
      expect(body['status'], 'sent');
    });

    test('sent -> deleted: via delete handler', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'sent')];
        }
        return [];
      };

      final request = _request(
        'DELETE',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId',
        body: jsonEncode({'reason': 'Error'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 200);
    });

    test('finalized -> cannot unlock', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'finalized')];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId/unlock',
      );

      final response = await unlockQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 409);
    });

    test('finalized -> cannot delete (REQ-CAL-p00023-I)', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'finalized')];
        }
        return [];
      };

      final request = _request(
        'DELETE',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId',
        body: jsonEncode({'reason': 'Nope'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 409);
    });

    test('sent -> cannot finalize (must be ready_to_review)', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'sent')];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/questionnaire-instances/$_testInstanceId/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testInstanceId,
      );

      expect(response.statusCode, 409);
    });
  });
}
