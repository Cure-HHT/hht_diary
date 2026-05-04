// IMPLEMENTS REQUIREMENTS:
//   REQ-d00154-A: StoredEvent.originatorHop returns provenance.first; throws
//                 StateError on empty provenance.
//
// Convention: per-test `// Verifies: REQ-d00154-A — <prose>` annotations and
// the assertion ID `REQ-d00154-A` at the start of each test description.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';

StoredEvent _eventWithProvenance(List<Map<String, Object?>> provenance) =>
    StoredEvent(
      key: 0,
      eventId: 'ev-1',
      aggregateId: 'agg-1',
      aggregateType: 'DiaryEntry',
      entryType: 'epistaxis_event',
      entryTypeVersion: 1,
      libFormatVersion: 1,
      eventType: 'finalized',
      sequenceNumber: 1,
      data: const <String, Object?>{},
      metadata: <String, Object?>{
        'change_reason': 'initial',
        'provenance': provenance,
      },
      initiator: const UserInitiator('u1'),
      clientTimestamp: DateTime.utc(2026, 4, 26),
      eventHash: 'hash-1',
    );

void main() {
  // Verifies: REQ-d00154-A — originatorHop returns the first ProvenanceEntry,
  // materialized from metadata.provenance[0].
  test('REQ-d00154-A: originatorHop returns provenance.first', () {
    final event = _eventWithProvenance(<Map<String, Object?>>[
      <String, Object?>{
        'hop': 'mobile-device',
        'received_at': '2026-04-26T00:00:00.000Z',
        'identifier': 'install-A',
        'software_version': 'clinical_diary@1.0.0',
      },
      <String, Object?>{
        'hop': 'portal-server',
        'received_at': '2026-04-26T00:00:01.000Z',
        'identifier': 'portal-1',
        'software_version': 'portal@0.1.0',
      },
    ]);

    final originator = event.originatorHop;
    expect(originator.identifier, 'install-A');
    expect(originator.hop, 'mobile-device');
  });

  // Verifies: REQ-d00154-A — empty provenance throws StateError because
  // REQ-d00115 requires every event to carry at least one entry.
  test('REQ-d00154-A: empty provenance throws StateError', () {
    final event = _eventWithProvenance(const <Map<String, Object?>>[]);
    expect(() => event.originatorHop, throwsStateError);
  });
}
