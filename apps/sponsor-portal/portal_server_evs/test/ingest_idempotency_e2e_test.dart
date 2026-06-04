// Verifies: DIARY-DEV-participant-ingest/C — /ingest is idempotent under
//   redelivery: re-POSTing the exact wire bytes of an already-ingested batch
//   reports every event as a duplicate, writes nothing new, and is stable
//   across repeats. The device retries on transient failures, so the receiving
//   node must dedupe by event identity rather than double-applying.
//
// The dedupe itself (eventId + arrival_hash compare, identity-mismatch -> 422)
// lives in event_sourcing's EventStore and is covered by that library's tests;
// here we verify the portal /ingest endpoint exposes that guarantee end-to-end,
// over the same store the server runs in production. The compare is
// backend-agnostic (it keys on the stored event row, not on a Postgres unique
// index), so the in-memory store exercises the identical code path the
// Postgres-backed server uses; the Tier-C device runbook re-confirms it on a
// live Postgres backend.
import 'package:test/test.dart';

import 'link_ingest_harness.dart';

void main() {
  test(
      'redelivering the exact captured batch bytes -> all duplicate, no new '
      'rows, stable across repeats', () async {
    final h = await bootPortal(dbName: 'idem');
    addTearDown(h.dispose);
    await seedParticipant(h.eventStore, participantId: 'P-SELF');
    await seedCoordinator(h.eventStore);
    final jwt = await linkDevice(h,
        participantId: 'P-SELF', idempotencyKey: 'idem-issue');

    final dest = CapturingDest(client: portalBridge(h.boot), token: jwt);
    final device = await bootDevice(destination: dest);
    addTearDown(device.close);

    // First delivery: one finalized day-marker ships and materializes.
    await appendDiaryEntry(device,
        entryType: 'no_epistaxis_event',
        aggregateId: 'P-SELF:2025-10-15',
        data: const {'date': '2025-10-15'});
    await drainDevice(device);

    expect(dest.sentPayloads, hasLength(1),
        reason: 'exactly one batch should have shipped');
    final rowsAfterFirst = (await diaryRows(h)).length;
    expect(
      (await diaryRows(h)).map((r) => r['aggregateId']),
      contains('P-SELF:2025-10-15'),
      reason: 'the first delivery must materialize',
    );

    // Re-deliver the EXACT captured bytes -> all duplicate, nothing new.
    final batch = dest.sentPayloads.first;
    final redeliver = await postIngest(h, batch, jwt);
    expect(redeliver.status, 200);
    expect(redeliver.body['ingested'], 0,
        reason: 'a verbatim redelivery ingests no new events');
    expect(redeliver.body['duplicate'], greaterThanOrEqualTo(1),
        reason: 'every event in the redelivered batch is a duplicate');
    expect((await diaryRows(h)).length, rowsAfterFirst,
        reason: 'redelivery must not add materialized rows');

    // Idempotent under repeat: a third identical delivery is still a no-op.
    final third = await postIngest(h, batch, jwt);
    expect(third.body['ingested'], 0);
    expect((await diaryRows(h)).length, rowsAfterFirst);
  });

  test('a distinct second batch ingests as new and is independently idempotent',
      () async {
    final h = await bootPortal(dbName: 'idem2');
    addTearDown(h.dispose);
    await seedParticipant(h.eventStore, participantId: 'P-SELF');
    await seedCoordinator(h.eventStore);
    final jwt = await linkDevice(h,
        participantId: 'P-SELF', idempotencyKey: 'idem2-issue');

    final dest = CapturingDest(client: portalBridge(h.boot), token: jwt);
    final device = await bootDevice(destination: dest);
    addTearDown(device.close);

    await appendDiaryEntry(device,
        entryType: 'no_epistaxis_event',
        aggregateId: 'P-SELF:2025-10-15',
        data: const {'date': '2025-10-15'});
    await drainDevice(device);
    final rowsAfterFirst = (await diaryRows(h)).length;

    // A different day -> a genuinely new event in a new batch.
    await appendDiaryEntry(device,
        entryType: 'no_epistaxis_event',
        aggregateId: 'P-SELF:2025-10-16',
        data: const {'date': '2025-10-16'});
    await drainDevice(device);

    expect(dest.sentPayloads, hasLength(2));
    expect((await diaryRows(h)).length, greaterThan(rowsAfterFirst),
        reason: 'the distinct second batch must add a row');
    final rowsAfterSecond = (await diaryRows(h)).length;

    // Redelivering the second batch alone is a no-op.
    final redeliverSecond = await postIngest(h, dest.sentPayloads[1], jwt);
    expect(redeliverSecond.body['ingested'], 0);
    expect((await diaryRows(h)).length, rowsAfterSecond);

    // ...and so is redelivering the first.
    final redeliverFirst = await postIngest(h, dest.sentPayloads[0], jwt);
    expect(redeliverFirst.body['ingested'], 0);
    expect((await diaryRows(h)).length, rowsAfterSecond);
  });
}
