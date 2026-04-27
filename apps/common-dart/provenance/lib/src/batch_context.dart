/// Per-event record of batch membership for events received via
/// `EventStore.ingestBatch`.
///
/// Stamped into the receiver-hop `ProvenanceEntry.batchContext` field. Null
/// on originator entries, null on process-local `ingestEvent` entries, null
/// on receiver-originated audit events not emitted in response to a batch.
///
/// All five fields together recover the context an auditor needs to recover
/// a batch from stored events: the batch id groups the events, the position
/// orders them, the size bounds the expected set, the wire-bytes hash pins
/// the bytes the receiver hashed, and the wire format identifies the
/// canonicalization procedure used.
// Implements: REQ-d00115-J — batch-context schema.
class BatchContext {
  const BatchContext({
    required this.batchId,
    required this.batchPosition,
    required this.batchSize,
    required this.batchWireBytesHash,
    required this.batchWireFormat,
  });

  factory BatchContext.fromJson(Map<String, Object?> json) {
    final batchId = _requireString(json, 'batch_id');
    final batchPosition = _requireInt(json, 'batch_position');
    final batchSize = _requireInt(json, 'batch_size');
    final batchWireBytesHash = _requireString(json, 'batch_wire_bytes_hash');
    final batchWireFormat = _requireString(json, 'batch_wire_format');
    if (batchPosition < 0) {
      throw FormatException(
        'BatchContext: batch_position must be non-negative; got $batchPosition',
      );
    }
    if (batchSize <= 0) {
      throw FormatException(
        'BatchContext: batch_size must be positive; got $batchSize',
      );
    }
    if (batchPosition >= batchSize) {
      throw FormatException(
        'BatchContext: batch_position ($batchPosition) must be less than '
        'batch_size ($batchSize)',
      );
    }
    return BatchContext(
      batchId: batchId,
      batchPosition: batchPosition,
      batchSize: batchSize,
      batchWireBytesHash: batchWireBytesHash,
      batchWireFormat: batchWireFormat,
    );
  }

  final String batchId;
  final int batchPosition;
  final int batchSize;
  final String batchWireBytesHash;
  final String batchWireFormat;

  Map<String, Object?> toJson() => <String, Object?>{
    'batch_id': batchId,
    'batch_position': batchPosition,
    'batch_size': batchSize,
    'batch_wire_bytes_hash': batchWireBytesHash,
    'batch_wire_format': batchWireFormat,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchContext &&
          batchId == other.batchId &&
          batchPosition == other.batchPosition &&
          batchSize == other.batchSize &&
          batchWireBytesHash == other.batchWireBytesHash &&
          batchWireFormat == other.batchWireFormat;

  @override
  int get hashCode => Object.hash(
    batchId,
    batchPosition,
    batchSize,
    batchWireBytesHash,
    batchWireFormat,
  );

  @override
  String toString() =>
      'BatchContext('
      'batchId: $batchId, '
      'position: $batchPosition, '
      'size: $batchSize, '
      'wireBytesHash: $batchWireBytesHash, '
      'wireFormat: $batchWireFormat)';
}

String _requireString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('BatchContext: missing or non-string "$key"');
  }
  return value;
}

int _requireInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('BatchContext: missing or non-int "$key"');
  }
  return value;
}
