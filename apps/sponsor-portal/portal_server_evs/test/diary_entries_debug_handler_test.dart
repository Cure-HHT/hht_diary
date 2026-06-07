// Verifies the debug-only diary-entries read: filters a single participant's
// rows and sorts them by CLINICAL event date (canonicalEntryDate from the
// captured startTime), NOT the action/finalize append order. Auth gating is
// exercised separately via the bootstrap route; this unit-tests the
// sort/filter core through the no-auth test seam.
import 'dart:convert';

import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/src/diary_entries_debug_handler.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Future<void> _appendEpistaxis(
  EventStore store, {
  required String aggregateId,
  required String participantId,
  required String startTime,
}) async {
  await store.append(
    entryType: 'epistaxis_event',
    aggregateType: diaryEntryAggregateType,
    aggregateId: aggregateId,
    eventType: 'finalized',
    data: EpistaxisEventPayload(
      participantId: participantId,
      startTime: startTime,
      startTimeZone: 'America/New_York',
      startTimeUtcOffset: '-04:00',
    ).toJson(),
    initiator: const AutomationInitiator(service: 'test'),
  );
}

void main() {
  test(
      'returns one participant\'s diary entries sorted by clinical date '
      '(ascending), excluding other participants', () async {
    final store = await openPortalEventStore(
      backend: SembastBackend(
          database: await newDatabaseFactoryMemory().openDatabase('dbg-1')),
    );
    addTearDown(store.close);

    // Appended OUT of clinical-date order: the LATER clinical date first, then
    // the EARLIER one, so a passing sort cannot be an accident of insert order.
    await _appendEpistaxis(store,
        aggregateId: 'epx-late',
        participantId: 'P-1',
        startTime: '2025-10-20T08:30:00-04:00');
    await _appendEpistaxis(store,
        aggregateId: 'epx-early',
        participantId: 'P-1',
        startTime: '2025-10-15T09:00:00-04:00');
    // A different participant proves the filter excludes foreign rows.
    await _appendEpistaxis(store,
        aggregateId: 'epx-other',
        participantId: 'P-2',
        startTime: '2025-10-17T07:00:00-04:00');

    final handler = diaryEntriesDebugHandlerForTest(store);
    final response = await handler(
      Request('GET',
          Uri.parse('http://localhost/debug/diary-entries?participant=P-1')),
    );
    expect(response.statusCode, 200);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, Object?>;
    final rows = (body['rows'] as List).cast<Map<String, Object?>>();
    final ids = rows.map((r) => r['aggregateId']).toList();
    expect(ids, ['epx-early', 'epx-late'],
        reason: 'sorted by clinical date ascending, P-2 excluded');
    expect(body['count'], 2);
  });

  test('400 when the participant query param is missing', () async {
    final store = await openPortalEventStore(
      backend: SembastBackend(
          database: await newDatabaseFactoryMemory().openDatabase('dbg-2')),
    );
    addTearDown(store.close);

    final handler = diaryEntriesDebugHandlerForTest(store);
    final response = await handler(
      Request('GET', Uri.parse('http://localhost/debug/diary-entries')),
    );
    expect(response.statusCode, 400);
  });
}
