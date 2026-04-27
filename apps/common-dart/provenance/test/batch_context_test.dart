import 'package:provenance/provenance.dart';
import 'package:test/test.dart';

void main() {
  group('BatchContext', () {
    test('round-trips through JSON preserving all five fields', () {
      final ctx = BatchContext(
        batchId: '01234567-89ab-cdef-0123-456789abcdef',
        batchPosition: 2,
        batchSize: 5,
        batchWireBytesHash: 'deadbeef' * 8,
        batchWireFormat: 'esd/batch@1',
      );
      final json = ctx.toJson();
      final back = BatchContext.fromJson(json);
      expect(back, equals(ctx));
    });

    test('equality and hashCode compare all fields', () {
      const a = BatchContext(
        batchId: 'same',
        batchPosition: 0,
        batchSize: 1,
        batchWireBytesHash: 'h',
        batchWireFormat: 'esd/batch@1',
      );
      const b = BatchContext(
        batchId: 'same',
        batchPosition: 0,
        batchSize: 1,
        batchWireBytesHash: 'h',
        batchWireFormat: 'esd/batch@1',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('fromJson rejects missing fields', () {
      expect(
        () => BatchContext.fromJson(<String, Object?>{
          'batch_id': 'x',
          // missing batch_position
        }),
        throwsFormatException,
      );
    });
  });
}
