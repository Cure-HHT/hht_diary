import 'package:event_sourcing_datastore/src/ingest/chain_verdict.dart';
import 'package:event_sourcing_datastore/src/ingest/ingest_errors.dart';
import 'package:event_sourcing_datastore/src/ingest/ingest_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IngestOutcome', () {
    test('enum has two values', () {
      expect(IngestOutcome.values, hasLength(2));
      expect(IngestOutcome.values, contains(IngestOutcome.ingested));
      expect(IngestOutcome.values, contains(IngestOutcome.duplicate));
    });
  });

  group('ChainVerdict', () {
    test('valid constant has ok=true and empty failures', () {
      expect(ChainVerdict.valid.ok, isTrue);
      expect(ChainVerdict.valid.failures, isEmpty);
    });

    test('construction with failures marks ok=false', () {
      const verdict = ChainVerdict(
        ok: false,
        failures: <ChainFailure>[
          ChainFailure(
            position: 2,
            kind: ChainFailureKind.arrivalHashMismatch,
            expectedHash: 'a',
            actualHash: 'b',
          ),
        ],
      );
      expect(verdict.ok, isFalse);
      expect(verdict.failures, hasLength(1));
    });
  });

  group('IngestChainBroken', () {
    test('carries diagnostic fields in toString', () {
      const err = IngestChainBroken(
        eventId: 'e1',
        hopIndex: 1,
        expectedHash: 'a',
        actualHash: 'b',
      );
      expect(err.toString(), contains('e1'));
      expect(err.toString(), contains('hopIndex: 1'));
    });
  });
}
