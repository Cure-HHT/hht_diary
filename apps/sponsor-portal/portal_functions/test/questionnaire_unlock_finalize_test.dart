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
/// [id, type::text, status::text, patient_id, deleted_at, study_event]
List<dynamic> _instanceRow({
  String id = _testInstanceId,
  String type = 'nose_hht',
  String status = 'sent',
  DateTime? deletedAt,
  String? studyEvent = 'Cycle 1 Day 1',
}) {
  return [id, type, status, _testPatientId, deletedAt, studyEvent];
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
        Uri.parse('http://localhost/api/v1/portal/patients/p1/questionnaires'),
      );

      final response = await getQuestionnaireStatusHandler(request, 'p1');

      expect(response.statusCode, 401);
      final body = await _json(response);
      expect(body['error'], contains('authorization'));
    });

    test('POST send returns 401 without auth', () async {
      final request = Request(
        'POST',
        Uri.parse(
          'http://localhost/api/v1/portal/patients/p1/questionnaires/nose_hht/send',
        ),
      );

      final response = await sendQuestionnaireHandler(
        request,
        'p1',
        'nose_hht',
      );

      expect(response.statusCode, 401);
    });

    test('DELETE returns 401 without auth', () async {
      final request = Request(
        'DELETE',
        Uri.parse(
          'http://localhost/api/v1/portal/patients/p1/questionnaires/q1',
        ),
      );

      final response = await deleteQuestionnaireHandler(request, 'p1', 'q1');

      expect(response.statusCode, 401);
    });

    test('unlock returns 401 without auth', () async {
      final request = Request(
        'POST',
        Uri.parse(
          'http://localhost/api/v1/portal/patients/p1/questionnaires/q1/unlock',
        ),
      );

      final response = await unlockQuestionnaireHandler(request, 'p1', 'q1');

      expect(response.statusCode, 401);
    });

    test('finalize returns 401 without auth', () async {
      final request = Request(
        'POST',
        Uri.parse(
          'http://localhost/api/v1/portal/patients/p1/questionnaires/q1/finalize',
        ),
      );

      final response = await finalizeQuestionnaireHandler(request, 'p1', 'q1');

      expect(response.statusCode, 401);
    });

    test('all handlers return JSON content type on error', () async {
      final handlers = [
        () => getQuestionnaireStatusHandler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/v1/portal/patients/p1/q'),
          ),
          'p1',
        ),
        () => sendQuestionnaireHandler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/v1/portal/patients/p1/q/nose/s'),
          ),
          'p1',
          'nose_hht',
        ),
        () => deleteQuestionnaireHandler(
          Request(
            'DELETE',
            Uri.parse('http://localhost/api/v1/portal/patients/p1/q/q1'),
          ),
          'p1',
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/nose_hht/send',
      );

      final response = await sendQuestionnaireHandler(
        request,
        _testPatientId,
        'nose_hht',
      );

      expect(response.statusCode, 403);
      final body = await _json(response);
      expect(body['error'], contains('Investigator'));
    });

    test('delete returns 403 for non-Investigator role', () async {
      requirePortalAuthOverride = (_) async =>
          _investigator(activeRole: 'Sponsor');

      final request = _request(
        'DELETE',
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId',
        body: jsonEncode({'reason': 'Test'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testPatientId,
        _testInstanceId,
      );

      expect(response.statusCode, 403);
    });

    test('unlock returns 403 for non-Investigator role', () async {
      requirePortalAuthOverride = (_) async =>
          _investigator(activeRole: 'Administrator');

      final request = _request(
        'POST',
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/unlock',
      );

      final response = await unlockQuestionnaireHandler(
        request,
        _testPatientId,
        _testInstanceId,
      );

      expect(response.statusCode, 403);
    });

    test('finalize returns 403 for non-Investigator role', () async {
      requirePortalAuthOverride = (_) async =>
          _investigator(activeRole: 'Analyst');

      final request = _request(
        'POST',
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires',
      );

      final response = await getQuestionnaireStatusHandler(
        request,
        _testPatientId,
      );

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
        '/api/v1/portal/patients/$_testPatientId/questionnaires',
      );

      final response = await getQuestionnaireStatusHandler(
        request,
        _testPatientId,
      );

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
        // CUR-856: Last-finalized query (2-column result)
        if (query.contains("status = 'finalized'") &&
            query.contains('finalized_at')) {
          return [];
        }
        // CUR-856: End-event blocking query
        if (query.contains('end_event IS NOT NULL')) {
          return [];
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires',
      );

      final response = await getQuestionnaireStatusHandler(
        request,
        _testPatientId,
      );

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
        '/api/v1/portal/patients/nonexistent/questionnaires',
      );

      final response = await getQuestionnaireStatusHandler(
        request,
        'nonexistent',
      );

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
        '/api/v1/portal/patients/$_testPatientId/questionnaires',
      );

      final response = await getQuestionnaireStatusHandler(
        request,
        _testPatientId,
      );

      expect(response.statusCode, 403);
      final body = await _json(response);
      expect(body['error'], contains('site'));
    });

    test('shows blocked next_cycle_info and end_event metadata after terminal '
        'cycle finalization (REQ-CAL-p00080-G)', () async {
      // Scenario: nose_hht Cycle 5 Day 1 was finalized with
      // end_event='end_of_treatment'. The handler must:
      //   1. Transform 'finalized' → 'not_sent' so the type shows as sendable
      //   2. Still expose last_finalized_study_event
      //   3. Call _computeNextCycleInfo which detects the end_event and
      //      returns blocked=true with end_event / ended_on_study_event fields
      final finalizedAt = DateTime.now().toUtc();

      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM patients')) {
          return [_patientRow()];
        }
        // Last-finalized query (runs per type to populate last_finalized_*)
        if (query.contains("status = 'finalized'") &&
            query.contains('finalized_at')) {
          return [
            [finalizedAt, 'Cycle 5 Day 1'],
          ];
        }
        // End-event blocking query — terminal cycle still active (not deleted)
        if (query.contains('end_event IS NOT NULL')) {
          return [
            ['end_of_treatment', 'Cycle 5 Day 1'],
          ];
        }
        // Main instances query: nose_hht is finalized on Cycle 5 Day 1
        // columns: [id, type, status, study_event, version,
        //           sent_at, submitted_at, finalized_at, score, sent_by]
        if (query.contains('FROM questionnaire_instances')) {
          return [
            [
              _testInstanceId,
              'nose_hht',
              'finalized',
              'Cycle 5 Day 1',
              '1.0.0',
              finalizedAt,
              finalizedAt,
              finalizedAt,
              null,
              _testUserId,
            ],
          ];
        }
        return [];
      };

      final request = _request(
        'GET',
        '/api/v1/portal/patients/$_testPatientId/questionnaires',
      );

      final response = await getQuestionnaireStatusHandler(
        request,
        _testPatientId,
      );

      expect(response.statusCode, 200);
      final body = await _json(response);
      final questionnaires = body['questionnaires'] as List<dynamic>;

      final noseHht = questionnaires.firstWhere(
        (q) => q['questionnaire_type'] == 'nose_hht',
      );

      // Finalized status is exposed as not_sent — ready for next-cycle send
      expect(noseHht['status'], 'not_sent');
      // Last finalized metadata is preserved so the UI can display it
      expect(noseHht['last_finalized_study_event'], 'Cycle 5 Day 1');
      // Terminal cycle blocks further sends
      final nextCycleInfo = noseHht['next_cycle_info'] as Map<String, dynamic>;
      expect(nextCycleInfo['blocked'], true);
      expect(nextCycleInfo['end_event'], 'end_of_treatment');
      expect(nextCycleInfo['ended_on_study_event'], 'Cycle 5 Day 1');
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/nose_hht/send',
        body: jsonEncode({'study_event': 'Cycle 1 Day 1'}),
      );

      final response = await sendQuestionnaireHandler(
        request,
        _testPatientId,
        'nose_hht',
      );

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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/invalid_type/send',
      );

      final response = await sendQuestionnaireHandler(
        request,
        _testPatientId,
        'invalid_type',
      );

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

        // CUR-856: nose_hht and qol require study_event per REQ-CAL-p00080
        final body = (type == 'nose_hht' || type == 'qol')
            ? jsonEncode({'study_event': 'Cycle 1 Day 1'})
            : null;

        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/questionnaires/$type/send',
          body: body,
        );

        final response = await sendQuestionnaireHandler(
          request,
          _testPatientId,
          type,
        );

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
        '/api/v1/portal/patients/nonexistent/questionnaires/nose_hht/send',
      );

      final response = await sendQuestionnaireHandler(
        request,
        'nonexistent',
        'nose_hht',
      );

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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/nose_hht/send',
      );

      final response = await sendQuestionnaireHandler(
        request,
        _testPatientId,
        'nose_hht',
      );

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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/nose_hht/send',
      );

      final response = await sendQuestionnaireHandler(
        request,
        _testPatientId,
        'nose_hht',
      );

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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/nose_hht/send',
      );

      final response = await sendQuestionnaireHandler(
        request,
        _testPatientId,
        'nose_hht',
      );

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

      // CUR-856: study_event required per REQ-CAL-p00080
      final request = _request(
        'POST',
        '/api/v1/portal/patients/$_testPatientId/questionnaires/nose_hht/send',
        body: jsonEncode({'study_event': 'Cycle 1 Day 1'}),
      );

      await sendQuestionnaireHandler(request, _testPatientId, 'nose_hht');

      final auditQuery = capturedQueries.where(
        (q) => q.query.contains('admin_action_log'),
      );
      expect(auditQuery, isNotEmpty, reason: 'Should log to audit trail');

      // Action type is hardcoded in SQL, not a named parameter
      expect(auditQuery.first.query, contains('QUESTIONNAIRE_SENT'));
    });

    test('returns 409 with user-readable error when study_event conflicts '
        'with an existing non-deleted instance (REQ-CAL-p00080-E)', () async {
      // Scenario: Cycle 1 is finalized. System auto-suggests Cycle 2.
      // But another concurrent send already created Cycle 2 Day 1 (e.g.
      // race condition or manual override). The conflict check must return
      // a clean 409 before the INSERT reaches the DB constraint.
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM patients')) {
          return [_patientRow()];
        }
        // No active non-finalized instance
        if (query.contains("status != 'finalized'")) {
          return [];
        }
        // No terminal cycle block
        if (query.contains('end_event IS NOT NULL')) {
          return [];
        }
        // Finalized cycles: Cycle 1 exists → auto-suggests Cycle 2
        if (query.contains("status = 'finalized'") &&
            query.contains('study_event ~')) {
          return [
            ['Cycle 1 Day 1'],
          ];
        }
        // study_event conflict check — Cycle 2 Day 1 already taken
        if (query.contains('study_event = @studyEvent')) {
          return [
            [1],
          ];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/patients/$_testPatientId/questionnaires/nose_hht/send',
        body: jsonEncode({'study_event': 'Cycle 2 Day 1'}),
      );

      final response = await sendQuestionnaireHandler(
        request,
        _testPatientId,
        'nose_hht',
      );

      expect(response.statusCode, 409);
      final body = await _json(response);
      expect(body['error'], contains('Cycle 2 Day 1'));
      expect(body['error'], contains('already exists'));
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId',
        body: jsonEncode({'reason': 'Sent in error'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId',
        body: jsonEncode({}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testPatientId,
        _testInstanceId,
      );

      expect(response.statusCode, 400);
      final body = await _json(response);
      expect(body['error'], contains('reason'));
    });

    test('returns 400 when reason is empty', () async {
      final request = _request(
        'DELETE',
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId',
        body: jsonEncode({'reason': '   '}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testPatientId,
        _testInstanceId,
      );

      expect(response.statusCode, 400);
    });

    test('returns 400 when reason exceeds 25 chars (REQ-CAL-p00066-B)', () async {
      final request = _request(
        'DELETE',
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId',
        body: jsonEncode({
          'reason': 'This reason is way too long for the field',
        }),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testPatientId,
        _testInstanceId,
      );

      expect(response.statusCode, 400);
      final body = await _json(response);
      expect(body['error'], contains('25 characters'));
    });

    test('allows reason of exactly 25 chars', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'sent')];
        }
        return [];
      };

      final request = _request(
        'DELETE',
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId',
        body: jsonEncode({'reason': 'a' * 25}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId',
        body: jsonEncode({'reason': 'Test'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId',
        body: jsonEncode({'reason': 'Re-assess'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId',
        body: jsonEncode({'reason': 'Too late'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId',
        body: jsonEncode({'reason': 'Again'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/nonexistent',
        body: jsonEncode({'reason': 'Test'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testPatientId,
        'nonexistent',
      );

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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId',
        body: jsonEncode({'reason': 'Error'}),
      );

      await deleteQuestionnaireHandler(
        request,
        _testPatientId,
        _testInstanceId,
      );

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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId',
        body: 'not json',
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/unlock',
      );

      final response = await unlockQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/unlock',
      );

      final response = await unlockQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/unlock',
      );

      final response = await unlockQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/unlock',
      );

      final response = await unlockQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/nonexistent/unlock',
      );

      final response = await unlockQuestionnaireHandler(
        request,
        _testPatientId,
        'nonexistent',
      );

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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/nonexistent/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/finalize',
      );

      await finalizeQuestionnaireHandler(
        request,
        _testPatientId,
        _testInstanceId,
      );

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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/unlock',
      );

      final response = await unlockQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId',
        body: jsonEncode({'reason': 'Error'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/unlock',
      );

      final response = await unlockQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId',
        body: jsonEncode({'reason': 'Nope'}),
      );

      final response = await deleteQuestionnaireHandler(
        request,
        _testPatientId,
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testPatientId,
        _testInstanceId,
      );

      expect(response.statusCode, 409);
    });
  });

  // ====================================================================
  // Phase 2: End Events (CUR-856, REQ-CAL-p00080 Assertions F, G)
  // ====================================================================
  group('finalizeQuestionnaireHandler — end events (CUR-856)', () {
    test('stores end_event when provided in body', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        capturedQueries.add((query: query, params: parameters));
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'ready_to_review')];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/finalize',
        body: jsonEncode({'end_event': 'end_of_treatment'}),
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testPatientId,
        _testInstanceId,
      );

      expect(response.statusCode, 200);
      final body = await _json(response);
      expect(body['end_event'], 'end_of_treatment');

      // Verify end_event was passed to the UPDATE query
      final updateQuery = capturedQueries.where(
        (q) => q.query.contains('UPDATE questionnaire_instances'),
      );
      expect(updateQuery, isNotEmpty);
      expect(updateQuery.first.params?['endEvent'], 'end_of_treatment');
    });

    test('stores end_of_study end_event', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'ready_to_review')];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/finalize',
        body: jsonEncode({'end_event': 'end_of_study'}),
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testPatientId,
        _testInstanceId,
      );

      expect(response.statusCode, 200);
      final body = await _json(response);
      expect(body['end_event'], 'end_of_study');
    });

    test('end_event is null when not provided (normal finalization)', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        capturedQueries.add((query: query, params: parameters));
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'ready_to_review')];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/finalize',
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testPatientId,
        _testInstanceId,
      );

      expect(response.statusCode, 200);
      final body = await _json(response);
      expect(body['end_event'], isNull);

      final updateQuery = capturedQueries.where(
        (q) => q.query.contains('UPDATE questionnaire_instances'),
      );
      expect(updateQuery.first.params?['endEvent'], isNull);
    });

    test('returns 400 for invalid end_event string', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM questionnaire_instances')) {
          return [_instanceRow(status: 'ready_to_review')];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/patients/$_testPatientId/questionnaires/$_testInstanceId/finalize',
        body: jsonEncode({'end_event': 'invalid value'}),
      );

      final response = await finalizeQuestionnaireHandler(
        request,
        _testPatientId,
        _testInstanceId,
      );

      expect(response.statusCode, 400);
      final body = await _json(response);
      expect(body['error'], contains('Invalid end_event'));
    });
  });

  group('sendQuestionnaireHandler — end event blocking (CUR-856)', () {
    test('returns 409 when end event is finalized for that type', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM patients')) {
          return [_patientRow()];
        }
        // No active non-finalized instance
        if (query.contains('FROM questionnaire_instances') &&
            query.contains("status != 'finalized'")) {
          return [];
        }
        // End event check — return a finalized end event
        if (query.contains('end_event IS NOT NULL')) {
          return [
            ['end_of_treatment', 'Cycle 5 Day 1'],
          ];
        }
        return [];
      };

      final request = _request(
        'POST',
        '/api/v1/portal/patients/$_testPatientId/questionnaires/nose_hht/send',
        body: jsonEncode({'study_event': 'Cycle 6 Day 1'}),
      );

      final response = await sendQuestionnaireHandler(
        request,
        _testPatientId,
        'nose_hht',
      );

      expect(response.statusCode, 409);
      final body = await _json(response);
      expect(body['error'], contains('Cannot send questionnaire'));
      expect(body['error'], contains('end_of_treatment'));
    });

    test('does not block when no end event finalized', () async {
      databaseQueryOverride = (query, {parameters, required context}) async {
        if (query.contains('FROM patients')) {
          return [_patientRow()];
        }
        if (query.contains('FROM questionnaire_instances') &&
            query.contains("status != 'finalized'")) {
          return [];
        }
        // End event check — none found
        if (query.contains('end_event IS NOT NULL')) {
          return [];
        }
        // Finalized cycles for auto-increment
        if (query.contains("status = 'finalized'") &&
            query.contains('study_event')) {
          return [
            ['Cycle 3 Day 1'],
          ];
        }
        if (query.contains('INSERT INTO questionnaire_instances')) {
          return [
            ['new-instance-id'],
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
        '/api/v1/portal/patients/$_testPatientId/questionnaires/nose_hht/send',
      );

      final response = await sendQuestionnaireHandler(
        request,
        _testPatientId,
        'nose_hht',
      );

      expect(response.statusCode, 200);
    });
  });

  // REQ-CAL-p00080-E: when a questionnaire is deleted before finalization,
  // the system SHALL reassign the same Cycle value to the next questionnaire.
  // The implementation satisfies this because Next Cycle is always
  // (max FINALIZED cycle + 1) — deleted cycles are never finalized, so
  // they are transparently re-suggested.
  group('sendQuestionnaireHandler — deleted cycle re-suggestion (REQ-CAL-p00080-E)', () {
    test(
      'reassigns deleted cycle as next cycle when no newer finalized cycle exists',
      () async {
        // Scenario:
        //   Cycle 1 sent → finalized  (Finalized Cycle = 1)
        //   Cycle 2 sent → deleted before finalization
        //
        // Expected: system auto-assigns Cycle 2 Day 1 (not Cycle 3 Day 1),
        // because Next Cycle = Finalized Cycle (1) + 1 = 2.
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow()];
          }
          // No active non-finalized instance — Cycle 2 was soft-deleted
          if (query.contains('FROM questionnaire_instances') &&
              query.contains("status != 'finalized'")) {
            return [];
          }
          // No terminal cycle finalized
          if (query.contains('end_event IS NOT NULL')) {
            return [];
          }
          // Only Cycle 1 is finalized; Cycle 2 was deleted, never finalized
          if (query.contains("status = 'finalized'") &&
              query.contains('study_event')) {
            return [
              ['Cycle 1 Day 1'],
            ];
          }
          if (query.contains('INSERT INTO questionnaire_instances')) {
            return [
              ['new-instance-id'],
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

        // No study_event in the request — system must auto-compute it
        final request = _request(
          'POST',
          '/api/v1/portal/patients/$_testPatientId/questionnaires/nose_hht/send',
        );

        final response = await sendQuestionnaireHandler(
          request,
          _testPatientId,
          'nose_hht',
        );

        expect(response.statusCode, 200);
        final body = await _json(response);
        // Must re-assign Cycle 2 (the deleted cycle), NOT skip to Cycle 3
        expect(body['study_event'], equals('Cycle 2 Day 1'));
      },
    );

    test(
      'skips multiple deleted cycles and re-assigns the first un-finalized one',
      () async {
        // Scenario:
        //   Cycle 1 finalized, Cycle 2 finalized  (Finalized Cycle = 2)
        //   Cycle 3 sent → deleted
        //   Cycle 4 sent → deleted
        //
        // Expected: system assigns Cycle 3 Day 1 (Finalized Cycle 2 + 1),
        // not Cycle 5.
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow()];
          }
          if (query.contains('FROM questionnaire_instances') &&
              query.contains("status != 'finalized'")) {
            return [];
          }
          if (query.contains('end_event IS NOT NULL')) {
            return [];
          }
          // Cycles 1 and 2 finalized; Cycles 3 and 4 were deleted
          if (query.contains("status = 'finalized'") &&
              query.contains('study_event')) {
            return [
              ['Cycle 1 Day 1'],
              ['Cycle 2 Day 1'],
            ];
          }
          if (query.contains('INSERT INTO questionnaire_instances')) {
            return [
              ['new-instance-id'],
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
          '/api/v1/portal/patients/$_testPatientId/questionnaires/nose_hht/send',
        );

        final response = await sendQuestionnaireHandler(
          request,
          _testPatientId,
          'nose_hht',
        );

        expect(response.statusCode, 200);
        final body = await _json(response);
        expect(body['study_event'], equals('Cycle 3 Day 1'));
      },
    );
  });

  // ====================================================================
  // Terminal cycle: soft-delete allows resend (REQ-CAL-p00080-G)
  // ====================================================================
  //
  // The end_event IS NOT NULL query includes `deleted_at IS NULL`, so a
  // soft-deleted terminal-cycle row does not permanently block further sends.
  // This verifies the database query correctly excludes deleted rows.
  group('sendQuestionnaireHandler — terminal cycle soft-delete allows resend '
      '(REQ-CAL-p00080-G)', () {
    test(
      'permits send after terminal-cycle questionnaire is soft-deleted',
      () async {
        // Scenario:
        //   A questionnaire was sent for a terminal cycle (end_of_treatment)
        //   but was soft-deleted before finalization (end_event was never set).
        //   Because the end_event IS NOT NULL query has deleted_at IS NULL,
        //   the deleted row is excluded — the type is unblocked.
        //
        // Expected: 200 — system allows a new send.
        databaseQueryOverride = (query, {parameters, required context}) async {
          if (query.contains('FROM patients')) {
            return [_patientRow()];
          }
          // No active non-finalized instance (deleted one is excluded)
          if (query.contains('FROM questionnaire_instances') &&
              query.contains("status != 'finalized'")) {
            return [];
          }
          // Terminal-cycle row is soft-deleted → excluded by deleted_at IS NULL
          if (query.contains('end_event IS NOT NULL')) {
            return [];
          }
          // No finalized cycles remain
          if (query.contains("status = 'finalized'") &&
              query.contains('study_event')) {
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
          '/api/v1/portal/patients/$_testPatientId/questionnaires/nose_hht/send',
          body: jsonEncode({'study_event': 'Cycle 1 Day 1'}),
        );

        final response = await sendQuestionnaireHandler(
          request,
          _testPatientId,
          'nose_hht',
        );

        expect(response.statusCode, 200);
        final body = await _json(response);
        expect(body['success'], true);
        expect(body['study_event'], 'Cycle 1 Day 1');
      },
    );
  });
}
