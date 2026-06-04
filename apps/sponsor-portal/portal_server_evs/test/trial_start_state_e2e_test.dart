// Verifies: DIARY-PRD-questionnaire-system/C — the portal exposes the Trial-Start
//   fact (the watermark the diary gates Diary Data Synchronization on) at
//   GET /api/v1/user/state for the authenticated participant. Before Trial Start
//   it reports trial_started=false; after a real ACT-PAT-002 dispatch it reports
//   trial_started=true with the trial_started_at watermark.
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

import 'link_ingest_harness.dart';

void main() {
  test(
      '/state reports trial_started=false before Send EQ, true + watermark after',
      () async {
    final h = await bootPortal(dbName: 'trial-state');
    addTearDown(h.dispose);
    await seedParticipant(h.eventStore, participantId: 'P-SELF');
    await seedCoordinator(h.eventStore);
    final jwt = await linkDevice(h,
        participantId: 'P-SELF', idempotencyKey: 'state-issue');

    // Linked but trial not started yet.
    final before = await getState(h, jwt);
    expect(before.status, 200);
    expect(before.body['trial_started'], false,
        reason: 'before Send EQ the trial has not started');
    expect(before.body.containsKey('trial_started_at'), false);
    expect(before.body['mobile_linking_status'], 'connected');

    // Coordinator "Send EQ" == real ACT-PAT-002 Start Trial dispatch.
    await dispatchOk<StartTrialResult>(
      h,
      'ACT-PAT-002',
      const {'siteId': 'S-1', 'participantId': 'P-SELF'},
      idempotencyKey: 'state-start',
    );
    await settleReactor();

    // Now the watermark is exposed for the diary to gate on.
    final after = await getState(h, jwt);
    expect(after.status, 200);
    expect(after.body['trial_started'], true);
    expect(after.body['trial_started_at'], isNotNull,
        reason: 'the trial-start watermark must be exposed after Start Trial');
    expect(after.body['mobile_linking_status'], 'connected');
  });

  test('/state without a valid participant token -> 401', () async {
    final h = await bootPortal(dbName: 'trial-state-auth');
    addTearDown(h.dispose);
    final res = await getState(h, 'not-a-jwt');
    expect(res.status, 401);
  });
}
