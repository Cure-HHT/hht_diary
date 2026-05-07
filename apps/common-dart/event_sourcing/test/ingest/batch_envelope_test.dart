import 'dart:convert';
import 'dart:typed_data';

import 'package:event_sourcing_datastore/src/ingest/batch_envelope.dart';
import 'package:event_sourcing_datastore/src/ingest/ingest_errors.dart';
import 'package:flutter_test/flutter_test.dart';

// Minimal fake StoredEvent-shaped maps for envelope tests; we're exercising
// the envelope codec, not StoredEvent validation.
Map<String, Object?> _fakeEventMap(String eventId) => <String, Object?>{
  'event_id': eventId,
  'aggregate_id': 'agg-$eventId',
  'aggregate_type': 'diary_entry',
  'entry_type': 'diary',
  'event_type': 'checkpoint',
  'sequence_number': 1,
  'data': const {},
  'metadata': const {'change_reason': 'initial', 'provenance': <Object?>[]},
  'initiator': const {'kind': 'system'},
  'flow_token': null,
  'client_timestamp': '2026-04-24T12:00:00Z',
  'previous_event_hash': null,
  'event_hash': 'deadbeef',
};

void main() {
  group('BatchEnvelope encode/decode', () {
    test('round-trips a single-event envelope preserving all fields', () {
      final envelope = BatchEnvelope(
        batchFormatVersion: '1',
        batchId: 'batch-xyz',
        senderHop: 'mobile-device',
        senderIdentifier: 'device-abc',
        senderSoftwareVersion: 'daily_diary@1.0.0',
        sentAt: DateTime.parse('2026-04-24T12:00:00Z'),
        events: <Map<String, Object?>>[_fakeEventMap('e1')],
      );
      final bytes = envelope.encode();
      final decoded = BatchEnvelope.decode(bytes);
      expect(decoded.batchId, equals('batch-xyz'));
      expect(decoded.events.length, equals(1));
      expect(decoded.events[0]['event_id'], equals('e1'));
    });

    test('encoding is deterministic (JCS-canonical)', () {
      final envelope = BatchEnvelope(
        batchFormatVersion: '1',
        batchId: 'batch-xyz',
        senderHop: 'mobile-device',
        senderIdentifier: 'device-abc',
        senderSoftwareVersion: 'daily_diary@1.0.0',
        sentAt: DateTime.parse('2026-04-24T12:00:00Z'),
        events: <Map<String, Object?>>[
          _fakeEventMap('e1'),
          _fakeEventMap('e2'),
        ],
      );
      final bytes1 = envelope.encode();
      final bytes2 = envelope.encode();
      expect(bytes1, equals(bytes2));
    });

    test('decode rejects non-JSON bytes with IngestDecodeFailure', () {
      final garbage = Uint8List.fromList(<int>[0xff, 0xfe, 0xfd]);
      expect(
        () => BatchEnvelope.decode(garbage),
        throwsA(isA<IngestDecodeFailure>()),
      );
    });

    test('decode rejects missing batch_format_version', () {
      final bad = utf8.encode(
        jsonEncode(<String, Object?>{
          'batch_id': 'x',
          'sender_hop': 'y',
          'sender_identifier': 'z',
          'sender_software_version': 'a@1',
          'sent_at': '2026-04-24T12:00:00Z',
          'events': <Object?>[],
        }),
      );
      expect(
        () => BatchEnvelope.decode(Uint8List.fromList(bad)),
        throwsA(isA<IngestDecodeFailure>()),
      );
    });

    test('decode rejects unsupported batch_format_version', () {
      final bad = utf8.encode(
        jsonEncode(<String, Object?>{
          'batch_format_version': '2',
          'batch_id': 'x',
          'sender_hop': 'y',
          'sender_identifier': 'z',
          'sender_software_version': 'a@1',
          'sent_at': '2026-04-24T12:00:00Z',
          'events': <Object?>[],
        }),
      );
      expect(
        () => BatchEnvelope.decode(Uint8List.fromList(bad)),
        throwsA(isA<IngestDecodeFailure>()),
      );
    });
  });
}
