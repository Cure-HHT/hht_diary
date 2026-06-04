// Verifies: DIARY-DEV-shared-events-catalog/A+C+E — every shape of clinical
//   diary entry the device authors (epistaxis with a per-event uuid aggregate,
//   the per-day no_epistaxis / unknown_day markers, and a dynamically-registered
//   survey) ships through /ingest and folds into the canonical diary_entries
//   view on the portal.
// Verifies: DIARY-DEV-participant-ingest/E — the ownership gate admits an
//   epistaxis event whose aggregate id carries NO participant prefix (the
//   documented bare-uuid residual), and rejects a participant-prefixed batch
//   naming a DIFFERENT participant (403).
//
// Scope note: fcm_token_registered / fcm_message_received / setting_applied /
// participant_linked are device-authored but are NOT DiaryEntry aggregates, so
// they intentionally do not flow to the portal's diary_entries view — they are
// out of scope for portal materialization and not asserted here.
import 'package:test/test.dart';

import 'link_ingest_harness.dart';

void main() {
  test(
      'diverse clinical entry types all materialize on the portal: epistaxis '
      '(bare-uuid aggregate), no_epistaxis + unknown_day (per-day markers), '
      'and a dynamic survey', () async {
    final h = await bootPortal(dbName: 'evt-types');
    addTearDown(h.dispose);
    await seedParticipant(h.eventStore, participantId: 'P-SELF');
    await seedCoordinator(h.eventStore);
    final jwt = await linkDevice(h,
        participantId: 'P-SELF', idempotencyKey: 'evt-issue');

    final dest = CapturingDest(client: portalBridge(h.boot), token: jwt);
    final device = await bootDevice(
      destination: dest,
      extraEntryTypes: [surveyEntryType('phq9_survey')],
    );
    addTearDown(device.close);

    // Append + drain each entry (drain-per-append avoids a multi-batch race).
    // 1. Epistaxis: fresh per-event uuid aggregate (NO participant prefix), so
    //    it both materializes AND passes the ownership gate's non-prefixed path.
    await appendDiaryEntry(device,
        entryType: 'epistaxis_event',
        aggregateId: 'epx-7f3a-0001',
        data: const {
          'startTime': '2025-10-15T08:30:00',
          'startTimeZone': 'America/New_York',
          'severity': 'moderate',
        });
    await drainDevice(device);
    // 2. Per-day no-bleed marker (participant-prefixed aggregate).
    await appendDiaryEntry(device,
        entryType: 'no_epistaxis_event',
        aggregateId: 'P-SELF:2025-10-16',
        data: const {'date': '2025-10-16'});
    await drainDevice(device);
    // 3. Per-day unknown-day marker (participant-prefixed aggregate).
    await appendDiaryEntry(device,
        entryType: 'unknown_day_event',
        aggregateId: 'P-SELF:2025-10-17',
        data: const {'date': '2025-10-17'});
    await drainDevice(device);
    // 4. A dynamically-registered survey entry (portal-assigned instance id).
    await appendDiaryEntry(device,
        entryType: 'phq9_survey',
        aggregateId: 'phq9-inst-001',
        data: const {'score': 12, 'completed': true});
    await drainDevice(device);

    final ids = (await diaryRows(h)).map((r) => r['aggregateId']).toSet();
    expect(
      ids,
      containsAll(<String>[
        'epx-7f3a-0001',
        'P-SELF:2025-10-16',
        'P-SELF:2025-10-17',
        'phq9-inst-001',
      ]),
      reason:
          'every diverse clinical entry type must materialize on the portal',
    );
  });

  test(
      'a cross-participant entry ships but the ownership gate blocks it: '
      'nothing materializes (end-to-end)', () async {
    // The direct-POST 403 is covered in link_then_ingest_e2e_test.dart; this
    // covers the full device->/ingest path: a foreign-prefixed aggregate is
    // shipped by the device but rejected at the edge, so no row appears.
    final h = await bootPortal(dbName: 'evt-ownership');
    addTearDown(h.dispose);
    await seedParticipant(h.eventStore, participantId: 'P-SELF');
    await seedCoordinator(h.eventStore);
    final jwt = await linkDevice(h,
        participantId: 'P-SELF', idempotencyKey: 'evt-own-issue');

    final dest = CapturingDest(client: portalBridge(h.boot), token: jwt);
    final device = await bootDevice(destination: dest);
    addTearDown(device.close);

    await appendDiaryEntry(device,
        entryType: 'no_epistaxis_event',
        aggregateId: 'P-OTHER:2025-10-16',
        data: const {'date': '2025-10-16'});
    await drainDevice(device);

    expect(dest.sentPayloads, hasLength(1),
        reason: 'the device does attempt to ship the (foreign) batch');
    expect(await diaryRows(h), isEmpty,
        reason: 'the ownership gate rejects it (403) so nothing materializes');
  });
}
