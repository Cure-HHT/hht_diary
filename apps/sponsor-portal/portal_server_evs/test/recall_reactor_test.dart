// Verifies: DIARY-DEV-outgoing-intent-correlation/A+C (intent enriched; flow token carried)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/src/recall_reactor.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  late EventStore store;
  late RecallReactor reactor;

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('rr.db');
    store = await openPortalEventStore(backend: SembastBackend(database: db));
    reactor = RecallReactor(eventStore: store, backend: store.backend);
  });

  Future<List<StoredEvent>> noticesFor(String instanceId) async {
    final all = await store.backend.readEventsReverse().toList();
    return all
        .where((e) =>
            e.entryType == 'questionnaire_recall_notice' &&
            e.data['instance_id'] == instanceId)
        .toList();
  }

  test(
      'called_back yields a recall_notice carrying participant_id + flow token',
      () async {
    await store.append(
      entryType: 'questionnaire_assigned',
      aggregateType: 'questionnaire_instance',
      aggregateId: 'QI1',
      eventType: 'questionnaire_assigned',
      data: <String, Object?>{
        'participant_id': 'P1',
        'type': 'qol',
        'study_event': 'Cycle 4 Day 1',
      },
      initiator: const AutomationInitiator(service: 'test'),
    );
    final calledBack = StoredEvent.synthetic(
      eventId: 'syn-cb1',
      aggregateId: 'QI1',
      aggregateType: 'questionnaire_instance',
      entryType: 'questionnaire_called_back',
      eventType: 'questionnaire_called_back',
      flowToken: 'QST000009',
      data: <String, dynamic>{'by': 'sc@x', 'reason': 'wrong cycle'},
      initiator: const AutomationInitiator(service: 'test'),
      clientTimestamp: DateTime.utc(2026, 6, 20),
      eventHash: 'h',
    );

    await reactor.handleCalledBack(calledBack);

    final notices = await noticesFor('QI1');
    expect(notices, hasLength(1));
    expect(notices.single.aggregateId, 'P1:recall:QI1');
    expect(notices.single.data['participant_id'], 'P1');
    expect(notices.single.data['study_event'], 'Cycle 4 Day 1');
    expect(notices.single.data['flow_token'], 'QST000009');
    expect(notices.single.data['instance_id'], 'QI1');
    expect(
      notices.single.data['recalled_at'],
      DateTime.utc(2026, 6, 20).toIso8601String(),
    );

    // Idempotent: re-processing the same called_back emits no second notice.
    await reactor.handleCalledBack(calledBack);
    expect(await noticesFor('QI1'), hasLength(1));
  });

  tearDown(() => store.close());
}
