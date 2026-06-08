// Verifies: DIARY-BASE-questionnaire-coordinator-workflow/C — the Send Now /
//   Start Next Cycle POST helper maps each server response to the right
//   SendOutcome the modal flow switches on.
// Verifies: DIARY-BASE-questionnaire-manage-modal/I+J — the 422 first-send
//   response routes to cycle selection; the explicit-cycle re-POST carries the
//   chosen studyEvent.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_ui_evs/src/send_questionnaire_flow.dart';

void main() {
  const serverUrl = 'http://portal.test';
  const bearer = 'cred|StudyCoordinator';

  http.Client respondWith(
    int status,
    Object? jsonBody, {
    void Function(http.Request req)? onRequest,
  }) => MockClient((req) async {
    onRequest?.call(req);
    return http.Response(
      jsonBody == null ? '' : jsonEncode(jsonBody),
      status,
      headers: const {'content-type': 'application/json'},
    );
  });

  test('200 -> SendSent carrying instanceId + studyEvent', () async {
    final client = respondWith(200, <String, Object?>{
      'instanceId': 'inst-9',
      'studyEvent': 'Cycle 3 Day 1',
    });
    final outcome = await postSend(client, serverUrl, bearer, <String, Object?>{
      'siteId': 'S-1',
      'participantId': 'P-1',
      'questionnaireType': 'nose_hht',
    });
    expect(outcome, isA<SendSent>());
    final sent = outcome as SendSent;
    expect(sent.instanceId, 'inst-9');
    expect(sent.studyEvent, 'Cycle 3 Day 1');
  });

  test(
    'POST targets /admin/questionnaire/send with the Bearer + body',
    () async {
      http.Request? captured;
      final client = respondWith(200, <String, Object?>{
        'instanceId': 'i',
        'studyEvent': null,
      }, onRequest: (r) => captured = r);
      await postSend(client, serverUrl, bearer, <String, Object?>{
        'siteId': 'S-1',
        'participantId': 'P-1',
        'questionnaireType': 'qol',
      });
      expect(captured, isNotNull);
      expect(captured!.url.toString(), '$serverUrl/admin/questionnaire/send');
      expect(captured!.headers['Authorization'], 'Bearer $bearer');
      final body = jsonDecode(captured!.body) as Map<String, Object?>;
      expect(body['questionnaireType'], 'qol');
      expect(body.containsKey('studyEvent'), isFalse);
    },
  );

  test(
    '422 -> SendNeedsCycleSelection (route to Select Starting Cycle)',
    () async {
      final client = respondWith(422, <String, Object?>{
        'error': 'needs_initial_cycle_selection',
      });
      final outcome = await postSend(
        client,
        serverUrl,
        bearer,
        <String, Object?>{
          'siteId': 'S-1',
          'participantId': 'P-1',
          'questionnaireType': 'nose_hht',
        },
      );
      expect(outcome, isA<SendNeedsCycleSelection>());
    },
  );

  test(
    'explicit-cycle re-POST carries studyEvent and yields SendSent',
    () async {
      http.Request? captured;
      final client = respondWith(200, <String, Object?>{
        'instanceId': 'inst-1',
        'studyEvent': 'Cycle 5 Day 1',
      }, onRequest: (r) => captured = r);
      final outcome =
          await postSend(client, serverUrl, bearer, <String, Object?>{
            'siteId': 'S-1',
            'participantId': 'P-1',
            'questionnaireType': 'nose_hht',
            'studyEvent': 'Cycle 5 Day 1',
          });
      expect(outcome, isA<SendSent>());
      final body = jsonDecode(captured!.body) as Map<String, Object?>;
      expect(body['studyEvent'], 'Cycle 5 Day 1');
    },
  );

  test('409 -> SendBlocked surfaces the server reason', () async {
    final client = respondWith(409, <String, Object?>{
      'error': 'an open instance already exists',
    });
    final outcome = await postSend(client, serverUrl, bearer, <String, Object?>{
      'siteId': 'S-1',
      'participantId': 'P-1',
      'questionnaireType': 'nose_hht',
    });
    expect(outcome, isA<SendBlocked>());
    expect((outcome as SendBlocked).reason, 'an open instance already exists');
  });

  test('403 -> SendError', () async {
    final client = respondWith(403, <String, Object?>{
      'error': 'not authorized to send for this site',
    });
    final outcome = await postSend(client, serverUrl, bearer, <String, Object?>{
      'siteId': 'S-1',
      'participantId': 'P-1',
      'questionnaireType': 'nose_hht',
    });
    expect(outcome, isA<SendError>());
    expect(
      (outcome as SendError).message,
      'not authorized to send for this site',
    );
  });

  test('500 with no body still maps to SendError', () async {
    final client = respondWith(500, null);
    final outcome = await postSend(client, serverUrl, bearer, <String, Object?>{
      'siteId': 'S-1',
      'participantId': 'P-1',
      'questionnaireType': 'nose_hht',
    });
    expect(outcome, isA<SendError>());
  });

  test('transport failure -> SendError', () async {
    final client = MockClient((_) async => throw Exception('boom'));
    final outcome = await postSend(client, serverUrl, bearer, <String, Object?>{
      'siteId': 'S-1',
      'participantId': 'P-1',
      'questionnaireType': 'nose_hht',
    });
    expect(outcome, isA<SendError>());
  });
}
