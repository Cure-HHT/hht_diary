import 'dart:convert';
import 'dart:typed_data';

import 'package:canonical_json_jcs/canonical_json_jcs.dart';

/// Thrown by [BatchEnvelope.decode] when the input bytes cannot be parsed as
/// a well-formed `esd/batch@1` envelope. Moved to `ingest_errors.dart` in
/// Task 5.
// Implements: REQ-d00145-B.
class IngestDecodeFailure implements Exception {
  const IngestDecodeFailure(this.message);
  final String message;
  @override
  String toString() => 'IngestDecodeFailure: $message';
}

/// The library's canonical batch envelope. Phase 4.9 supports exactly one
/// format version: `"1"` (identifier `"esd/batch@1"`).
// Implements: REQ-d00145-B.
class BatchEnvelope {
  const BatchEnvelope({
    required this.batchFormatVersion,
    required this.batchId,
    required this.senderHop,
    required this.senderIdentifier,
    required this.senderSoftwareVersion,
    required this.sentAt,
    required this.events,
  });

  /// Parse wire bytes as a canonical envelope. Throws [IngestDecodeFailure]
  /// on any malformedness.
  factory BatchEnvelope.decode(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (e) {
      throw IngestDecodeFailure('not valid UTF-8 JSON: $e');
    }
    if (decoded is! Map<String, Object?>) {
      throw const IngestDecodeFailure('envelope must be a JSON object');
    }
    final versionRaw = decoded['batch_format_version'];
    if (versionRaw != '1') {
      throw IngestDecodeFailure(
        'unsupported batch_format_version: got ${versionRaw ?? "(missing)"}; '
        'expected "1"',
      );
    }
    final version = versionRaw as String;
    final batchId = _requireString(decoded, 'batch_id');
    final senderHop = _requireString(decoded, 'sender_hop');
    final senderIdentifier = _requireString(decoded, 'sender_identifier');
    final senderSoftwareVersion = _requireString(
      decoded,
      'sender_software_version',
    );
    final sentAtStr = _requireString(decoded, 'sent_at');
    final DateTime sentAt;
    try {
      sentAt = DateTime.parse(sentAtStr);
    } catch (e) {
      throw IngestDecodeFailure('sent_at not parseable: $e');
    }
    final eventsRaw = decoded['events'];
    if (eventsRaw is! List) {
      throw const IngestDecodeFailure('events must be a JSON array');
    }
    final events = <Map<String, Object?>>[];
    for (var i = 0; i < eventsRaw.length; i++) {
      final e = eventsRaw[i];
      if (e is! Map<String, Object?>) {
        throw IngestDecodeFailure('events[$i] must be a JSON object');
      }
      events.add(Map<String, Object?>.from(e));
    }
    return BatchEnvelope(
      batchFormatVersion: version,
      batchId: batchId,
      senderHop: senderHop,
      senderIdentifier: senderIdentifier,
      senderSoftwareVersion: senderSoftwareVersion,
      sentAt: sentAt,
      events: events,
    );
  }

  /// Canonical identifier for this format.
  static const String wireFormat = 'esd/batch@1';

  final String batchFormatVersion;
  final String batchId;
  final String senderHop;
  final String senderIdentifier;
  final String senderSoftwareVersion;
  final DateTime sentAt;

  /// Raw StoredEvent JSON. Callers decode each map into `StoredEvent` using
  /// `StoredEvent.fromMap` inside the ingest flow.
  final List<Map<String, Object?>> events;

  /// JCS-canonicalize this envelope into wire bytes.
  Uint8List encode() {
    final map = <String, Object?>{
      'batch_format_version': batchFormatVersion,
      'batch_id': batchId,
      'sender_hop': senderHop,
      'sender_identifier': senderIdentifier,
      'sender_software_version': senderSoftwareVersion,
      'sent_at': sentAt.toIso8601String(),
      'events': events,
    };
    return Uint8List.fromList(canonicalizeBytes(map));
  }
}

String _requireString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw IngestDecodeFailure('missing or non-string "$key"');
  }
  return value;
}
