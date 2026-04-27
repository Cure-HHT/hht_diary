import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _minimalMap({Object? initiator, Object? flowToken}) => {
  'event_id': 'e',
  'aggregate_id': 'a',
  'aggregate_type': 'DiaryEntry',
  'entry_type': 'epistaxis_event',
  'entry_type_version': 1,
  'lib_format_version': 1,
  'event_type': 'finalized',
  'sequence_number': 1,
  'data': const {
    'answers': {'x': 1},
  },
  'metadata': const {'change_reason': 'initial', 'provenance': <Object?>[]},
  'initiator': initiator ?? const {'type': 'user', 'user_id': 'u'},
  'flow_token': flowToken,
  'client_timestamp': '2026-04-22T00:00:00.000Z',
  'event_hash': 'h',
};

Map<String, Object?> _validEventMap() => <String, Object?>{
  'event_id': 'e-1',
  'aggregate_id': 'a-1',
  'aggregate_type': 'DiaryEntry',
  'entry_type': 'demo_note',
  'event_type': 'finalized',
  'sequence_number': 1,
  'data': <String, Object?>{},
  'metadata': <String, Object?>{},
  'initiator': const UserInitiator('u-1').toJson(),
  'flow_token': null,
  'client_timestamp': DateTime.utc(2026, 4, 26).toIso8601String(),
  'event_hash': 'hash-1',
  'previous_event_hash': null,
  'entry_type_version': 1,
  'lib_format_version': 1,
};

void main() {
  group('StoredEvent Phase 4.4 shape', () {
    // Verifies: REQ-d00135-C — initiator replaces top-level user_id and
    // round-trips through fromMap/toMap.
    test('REQ-d00135-C: initiator round-trips through fromMap/toMap', () {
      final map = _minimalMap();
      final ev = StoredEvent.fromMap(map, 7);
      expect(ev.initiator, const UserInitiator('u'));
      expect(ev.toMap()['initiator'], {'type': 'user', 'user_id': 'u'});
    });

    // Verifies: REQ-d00136-A — flowToken is nullable and round-trips.
    test('REQ-d00136-A: flowToken is nullable and round-trips', () {
      final mapNull = _minimalMap();
      final ev1 = StoredEvent.fromMap(mapNull, 7);
      expect(ev1.flowToken, isNull);
      expect(ev1.toMap()['flow_token'], isNull);

      final mapWithToken = _minimalMap(flowToken: 'invite:ABC');
      final ev2 = StoredEvent.fromMap(mapWithToken, 7);
      expect(ev2.flowToken, 'invite:ABC');
      expect(ev2.toMap()['flow_token'], 'invite:ABC');
    });

    // Verifies: REQ-d00135-C — top-level user_id/device_id/software_version
    // removed from the serialized map.
    test(
      'REQ-d00135-C: top-level user_id / device_id / software_version fields '
      'are not emitted',
      () {
        final ev = StoredEvent.fromMap(_minimalMap(), 7);
        final map = ev.toMap();
        expect(map.containsKey('user_id'), isFalse);
        expect(map.containsKey('device_id'), isFalse);
        expect(map.containsKey('software_version'), isFalse);
      },
    );

    test('fromMap throws FormatException on missing initiator', () {
      final map = _minimalMap()..remove('initiator');
      expect(() => StoredEvent.fromMap(map, 7), throwsFormatException);
    });

    test('fromMap throws FormatException on non-string flow_token', () {
      final map = _minimalMap()..['flow_token'] = 42;
      expect(() => StoredEvent.fromMap(map, 7), throwsFormatException);
    });

    test('fromMap accepts AutomationInitiator via JSON', () {
      final map = _minimalMap(
        initiator: const {
          'type': 'automation',
          'service': 'retention-policy',
          'triggering_event_id': null,
        },
      );
      final ev = StoredEvent.fromMap(map, 7);
      expect(
        ev.initiator,
        const AutomationInitiator(service: 'retention-policy'),
      );
    });
  });

  group('StoredEvent.synthetic', () {
    test('constructs a minimally-valid StoredEvent for test fixtures', () {
      final ev = StoredEvent.synthetic(
        eventId: 'x',
        aggregateId: 'a',
        entryType: 't',
        initiator: const UserInitiator('u'),
        eventHash: 'h',
        clientTimestamp: DateTime.utc(2026, 4, 22),
      );
      expect(ev.eventId, 'x');
      expect(ev.aggregateId, 'a');
      expect(ev.initiator, const UserInitiator('u'));
      expect(ev.sequenceNumber, 0);
      expect(ev.data, isEmpty);
      expect(ev.metadata, isEmpty);
      expect(ev.flowToken, isNull);
    });
  });

  group('REQ-d00118-E,F: entry_type_version + lib_format_version fields', () {
    // Verifies: REQ-d00118-E
    test('REQ-d00118-E: toMap includes entry_type_version', () {
      final e = StoredEvent.synthetic(
        eventId: 'e-1',
        aggregateId: 'a-1',
        entryType: 'demo_note',
        initiator: const UserInitiator('u-1'),
        clientTimestamp: DateTime.utc(2026, 4, 26),
        eventHash: 'hash-1',
        entryTypeVersion: 7,
      );
      expect(e.toMap()['entry_type_version'], 7);
    });

    // Verifies: REQ-d00118-F
    test('REQ-d00118-F: toMap includes lib_format_version', () {
      final e = StoredEvent.synthetic(
        eventId: 'e-1',
        aggregateId: 'a-1',
        entryType: 'demo_note',
        initiator: const UserInitiator('u-1'),
        clientTimestamp: DateTime.utc(2026, 4, 26),
        eventHash: 'hash-1',
        libFormatVersion: 3,
      );
      expect(e.toMap()['lib_format_version'], 3);
    });

    // Verifies: REQ-d00118-E
    test('REQ-d00118-E: fromMap rejects missing entry_type_version', () {
      final m = _validEventMap()..remove('entry_type_version');
      expect(() => StoredEvent.fromMap(m, 0), throwsFormatException);
    });

    // Verifies: REQ-d00118-E
    test('REQ-d00118-E: fromMap rejects non-int entry_type_version', () {
      final m = _validEventMap()..['entry_type_version'] = 'not-an-int';
      expect(() => StoredEvent.fromMap(m, 0), throwsFormatException);
    });

    // Verifies: REQ-d00118-F
    test('REQ-d00118-F: fromMap rejects missing lib_format_version', () {
      final m = _validEventMap()..remove('lib_format_version');
      expect(() => StoredEvent.fromMap(m, 0), throwsFormatException);
    });

    // Verifies: REQ-d00118-F
    test('REQ-d00118-F: fromMap rejects non-int lib_format_version', () {
      final m = _validEventMap()..['lib_format_version'] = true;
      expect(() => StoredEvent.fromMap(m, 0), throwsFormatException);
    });

    // Verifies: REQ-d00118-E, REQ-d00118-F
    test('REQ-d00118-E,F: round-trip preserves both fields', () {
      final m = _validEventMap()
        ..['entry_type_version'] = 11
        ..['lib_format_version'] = 1;
      final e = StoredEvent.fromMap(m, 0);
      expect(e.entryTypeVersion, 11);
      expect(e.libFormatVersion, 1);
    });

    // Verifies: REQ-d00141-E
    test('REQ-d00141-E: currentLibFormatVersion is 1', () {
      expect(StoredEvent.currentLibFormatVersion, 1);
    });
  });
}
