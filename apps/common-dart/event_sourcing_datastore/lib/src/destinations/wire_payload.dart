import 'dart:typed_data';

import 'package:collection/collection.dart';

/// The byte-level payload a Destination produces for one event batch.
///
/// `WirePayload` is a transport type between
/// `Destination.transform(List<StoredEvent> batch)` and the FIFO enqueue
/// call that persists the bytes into the destination's queue. The bytes
/// are opaque to the datastore — the shape is determined by the
/// destination's wire format — but the accompanying `contentType` and
/// `transformVersion` stamps are preserved on the resulting `FifoEntry`
/// so the receiver can identify how the bytes were produced.
///
/// This type is not a JSON value: it carries raw bytes. The `FifoEntry`
/// stores the bytes under `wire_payload`, the `contentType` under
/// `wire_format`, and the `transformVersion` under `transform_version`.
// Implements: REQ-d00122-D — transform(List<StoredEvent>) returns bytes +
// content_type + transform_version covering the whole batch;
// transform_version flows through FifoEntry into downstream
// ProvenanceEntry stamping.
class WirePayload {
  WirePayload({
    required Uint8List bytes,
    required this.contentType,
    required this.transformVersion,
  }) : bytes = Uint8List.fromList(bytes);

  /// Opaque byte payload produced by a destination's transform. Stored
  /// verbatim on the `FifoEntry` and handed to `destination.send()`.
  final Uint8List bytes;

  /// MIME-like identifier of the bytes (e.g., `"application/json"`,
  /// `"application/fhir+json"`). Written to `FifoEntry.wire_format`.
  final String contentType;

  /// Semver-ish identifier of the transform that produced `bytes`
  /// (e.g., `"json-v1"`). Written to `FifoEntry.transform_version` and
  /// appended to `ProvenanceEntry.transform_version` by downstream hops.
  /// `null` when the destination is pass-through (identity transform).
  final String? transformVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WirePayload &&
          _byteEquals.equals(bytes, other.bytes) &&
          contentType == other.contentType &&
          transformVersion == other.transformVersion;

  @override
  int get hashCode =>
      Object.hash(_byteEquals.hash(bytes), contentType, transformVersion);

  @override
  String toString() =>
      'WirePayload(${bytes.length} bytes, contentType: $contentType, '
      'transformVersion: $transformVersion)';
}

const ListEquality<int> _byteEquals = ListEquality<int>();
