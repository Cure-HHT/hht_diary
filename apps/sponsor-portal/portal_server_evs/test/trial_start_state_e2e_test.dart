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

  // Verifies: DIARY-DEV-participant-state-poll/A+B — /state exposes the lifecycle
  //   facts the diary acts on: is_disconnected (pause sync) and is_not_participating
  //   (forget JWT + stop syncing). They are mutually exclusive because each reflects
  //   the latest lifecycle entryType: mark-not-participating supersedes disconnected.
  test(
      '/state exposes is_disconnected after disconnect, then is_not_participating '
      'after mark-not-participating (latest lifecycle wins)', () async {
    final h = await bootPortal(dbName: 'lifecycle-state');
    addTearDown(h.dispose);
    await seedParticipant(h.eventStore, participantId: 'P-SELF');
    await seedCoordinator(h.eventStore);
    final jwt = await linkDevice(h,
        participantId: 'P-SELF', idempotencyKey: 'lc-issue');
    await dispatchOk<StartTrialResult>(
      h,
      'ACT-PAT-002',
      const {'siteId': 'S-1', 'participantId': 'P-SELF'},
      idempotencyKey: 'lc-start',
    );
    await settleReactor();

    // Trial active: neither lifecycle flag set.
    final active = await getState(h, jwt);
    expect(active.body['is_disconnected'], false);
    expect(active.body['is_not_participating'], false);

    // Disconnect -> is_disconnected true.
    await dispatchOk<DisconnectParticipantResult>(
      h,
      'ACT-PAT-003',
      const {'siteId': 'S-1', 'participantId': 'P-SELF', 'reason': 'test'},
      idempotencyKey: 'lc-disc',
    );
    await settleReactor();
    final disc = await getState(h, jwt);
    expect(disc.body['is_disconnected'], true);
    expect(disc.body['is_not_participating'], false);

    // Mark not participating (reachable from disconnected) -> the flag flips:
    // is_not_participating true, is_disconnected false (latest entryType wins).
    await dispatchOk<MarkNotParticipatingResult>(
      h,
      'ACT-PAT-005',
      const {'siteId': 'S-1', 'participantId': 'P-SELF', 'reason': 'test'},
      idempotencyKey: 'lc-mnp',
    );
    await settleReactor();
    final mnp = await getState(h, jwt);
    expect(mnp.body['is_disconnected'], false);
    expect(mnp.body['is_not_participating'], true);
  });

  test('/state without a valid participant token -> 401', () async {
    final h = await bootPortal(dbName: 'trial-state-auth');
    addTearDown(h.dispose);
    final res = await getState(h, 'not-a-jwt');
    expect(res.status, 401);
  });
}
