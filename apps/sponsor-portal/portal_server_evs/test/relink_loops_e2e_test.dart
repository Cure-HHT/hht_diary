// Verifies: DIARY-PRD-action-inventory/A+C — the reconnect (ACT-PAT-004) and
//   reactivate (ACT-PAT-006) coordinator actions, dispatched for real, chain
//   through the LinkingCodeLifecycleReactor to a successful second /link.
// Verifies: DIARY-DEV-linking-code-lifecycle/A+D — a fresh issue supersedes the
//   prior active code for the same participant.
// Verifies: DIARY-DEV-relink-device-gate/B — a real disconnect dispatch clears
//   the device binding so a different device may relink end-to-end.
// Verifies: DIARY-PRD-participant-disconnection/G — disconnect-then-reconnect
//   lets a Participant complete reconnection on the same or a different device.
// Verifies: DIARY-PRD-participant-reactivate/D — a reactivated Participant may
//   reconnect on the same or a different device.
//
// Scope note: the pure /link gate MATRIX (same/different/omitted appUuid,
// unknown/expired/used codes) is already covered at the handler level in
// patient_link_handler_test.dart. This suite covers only what the full
// dispatch + reactor + router LOOP adds on top of that.
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

import 'link_ingest_harness.dart';

void main() {
  test(
      'reconnect loop (same device): issue -> link(DEVICE-A) -> disconnect '
      '-> reconnect -> link(DEVICE-A) all via real dispatch; status journey '
      'is connected -> disconnected -> connected', () async {
    final h = await bootPortal(dbName: 'relink-reconnect');
    addTearDown(h.dispose);
    await seedParticipant(h.eventStore, participantId: 'P-1');
    await seedCoordinator(h.eventStore);

    // 1. Issue + redeem to DEVICE-A.
    final issued = await dispatchOk<LinkParticipantResult>(
      h,
      'ACT-PAT-001',
      const {'siteId': 'S-1', 'participantId': 'P-1'},
      idempotencyKey: 'reconn-issue',
    );
    await settleReactor();
    final firstLink =
        await redeemCode(h, issued.linkingCode, appUuid: 'DEVICE-A');
    expect(firstLink.status, 200);
    expect((await participantRecord(h, 'P-1'))['mobile_linking_status'],
        'connected');

    // 2. Disconnect (real ACT-PAT-003) flips status to disconnected.
    await dispatchOk<DisconnectParticipantResult>(
      h,
      'ACT-PAT-003',
      const {'siteId': 'S-1', 'participantId': 'P-1', 'reason': 'lost phone'},
      idempotencyKey: 'reconn-disc',
    );
    await settleReactor();
    expect((await participantRecord(h, 'P-1'))['mobile_linking_status'],
        'disconnected');

    // 3. Reconnect (real ACT-PAT-004) issues a fresh code...
    final reconn = await dispatchOk<ReconnectParticipantResult>(
      h,
      'ACT-PAT-004',
      const {'siteId': 'S-1', 'participantId': 'P-1'},
      idempotencyKey: 'reconn-reconnect',
    );
    await settleReactor();
    expect(reconn.linkingCode, isNot(issued.linkingCode),
        reason: 'reconnect must mint a new code');

    // 4. ...which the SAME device redeems end-to-end (same-device continuity).
    final relink = await redeemCode(h, reconn.linkingCode, appUuid: 'DEVICE-A');
    expect(relink.status, 200,
        reason: 'same-device reconnect must succeed end-to-end');
    expect(relink.body['jwt'], isNotNull);
    expect((await participantRecord(h, 'P-1'))['mobile_linking_status'],
        'connected');
  });

  test(
      'reconnect to a NEW device succeeds: disconnect releases the device '
      'binding (clears app_uuid) so a new phone can relink after reconnect, '
      'even though the reconnect code re-stamps status to linking_in_progress',
      () async {
    // Regression for the relink gap: ACT-PAT-003 clears app_uuid (durable
    // release), so the gate no longer re-binds the OLD device when ACT-PAT-004
    // re-issues. See DisconnectParticipantAction's event data.
    final h = await bootPortal(dbName: 'relink-reconnect-newdev');
    addTearDown(h.dispose);
    await seedParticipant(h.eventStore, participantId: 'P-1B');
    await seedCoordinator(h.eventStore);

    final issued = await dispatchOk<LinkParticipantResult>(
      h,
      'ACT-PAT-001',
      const {'siteId': 'S-1', 'participantId': 'P-1B'},
      idempotencyKey: 'newdev-issue',
    );
    await settleReactor();
    expect(
        (await redeemCode(h, issued.linkingCode, appUuid: 'DEVICE-A')).status,
        200);

    await dispatchOk<DisconnectParticipantResult>(
      h,
      'ACT-PAT-003',
      const {'siteId': 'S-1', 'participantId': 'P-1B', 'reason': 'lost phone'},
      idempotencyKey: 'newdev-disc',
    );
    await settleReactor();
    // Disconnect must clear the bound device.
    expect((await participantRecord(h, 'P-1B'))['app_uuid'], isNull,
        reason: 'disconnect releases the device binding (app_uuid cleared)');

    final reconn = await dispatchOk<ReconnectParticipantResult>(
      h,
      'ACT-PAT-004',
      const {'siteId': 'S-1', 'participantId': 'P-1B'},
      idempotencyKey: 'newdev-reconnect',
    );
    await settleReactor();

    final relink = await redeemCode(h, reconn.linkingCode, appUuid: 'DEVICE-B');
    expect(relink.status, 200,
        reason: 'a NEW device may relink after disconnect->reconnect');
    expect(relink.body['jwt'], isNotNull);
    final rec = await participantRecord(h, 'P-1B');
    expect(rec['mobile_linking_status'], 'connected');
    expect(rec['app_uuid'], 'DEVICE-B',
        reason: 'the new device is now the bound device');
  });

  test(
      'reactivate loop: issue -> link(DEVICE-A) -> mark-not-participating '
      '-> reactivate -> link(DEVICE-B) all via real dispatch; a NEW device may '
      'relink (mark-not-participating released the old binding)', () async {
    final h = await bootPortal(dbName: 'relink-reactivate');
    addTearDown(h.dispose);
    await seedParticipant(h.eventStore, participantId: 'P-2');
    await seedCoordinator(h.eventStore);

    final issued = await dispatchOk<LinkParticipantResult>(
      h,
      'ACT-PAT-001',
      const {'siteId': 'S-1', 'participantId': 'P-2'},
      idempotencyKey: 'react-issue',
    );
    await settleReactor();
    expect(
        (await redeemCode(h, issued.linkingCode, appUuid: 'DEVICE-A')).status,
        200);

    // Mark not participating (real ACT-PAT-005) releases the device binding.
    await dispatchOk<MarkNotParticipatingResult>(
      h,
      'ACT-PAT-005',
      const {'siteId': 'S-1', 'participantId': 'P-2', 'reason': 'withdrew'},
      idempotencyKey: 'react-mark',
    );
    await settleReactor();
    expect((await participantRecord(h, 'P-2'))['app_uuid'], isNull,
        reason: 'mark-not-participating releases the device binding');

    // Reactivate (real ACT-PAT-006) issues a fresh active code...
    final react = await dispatchOk<ReactivateParticipantResult>(
      h,
      'ACT-PAT-006',
      const {'siteId': 'S-1', 'participantId': 'P-2', 'reason': 're-enrolled'},
      idempotencyKey: 'react-reactivate',
    );
    await settleReactor();
    expect(react.linkingCode, isNot(issued.linkingCode));

    // ...which a NEW device redeems.
    final relink = await redeemCode(h, react.linkingCode, appUuid: 'DEVICE-B');
    expect(relink.status, 200,
        reason: 'reactivation re-opens linking, including for a new device');
    expect(relink.body['jwt'], isNotNull);
    expect((await participantRecord(h, 'P-2'))['app_uuid'], 'DEVICE-B');
  });

  test(
      'supersession: a second real issue revokes the first active code; the '
      'stale code no longer redeems', () async {
    final h = await bootPortal(dbName: 'relink-supersede');
    addTearDown(h.dispose);
    await seedParticipant(h.eventStore, participantId: 'P-3');
    await seedCoordinator(h.eventStore);

    final first = await dispatchOk<LinkParticipantResult>(
      h,
      'ACT-PAT-001',
      const {'siteId': 'S-1', 'participantId': 'P-3'},
      idempotencyKey: 'sup-issue-1',
    );
    await settleReactor();
    final second = await dispatchOk<LinkParticipantResult>(
      h,
      'ACT-PAT-001',
      const {'siteId': 'S-1', 'participantId': 'P-3'},
      idempotencyKey: 'sup-issue-2',
    );
    await settleReactor();
    expect(second.linkingCode, isNot(first.linkingCode));

    // The lifecycle reactor must have superseded the first code.
    final rows = await h.backend.findViewRows('linking_codes');
    final firstRow = rows.firstWhere(
      (r) => r['linking_code'] == first.linkingCode,
      orElse: () => <String, Object?>{},
    );
    expect(firstRow['status'], isNot('active'),
        reason: 'the superseded first code must no longer be active');

    // Redeeming the stale first code fails; the live second code succeeds.
    final staleRedeem = await redeemCode(h, first.linkingCode, appUuid: 'D');
    expect(staleRedeem.status, isNot(200),
        reason: 'a superseded code must not redeem');
    final liveRedeem = await redeemCode(h, second.linkingCode, appUuid: 'D');
    expect(liveRedeem.status, 200);
  });
}
