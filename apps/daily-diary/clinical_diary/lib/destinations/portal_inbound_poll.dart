// Implements: REQ-d00113-D — tombstone instructions arriving from the
//   portal materialize as tombstone events through the same write path
//   user-driven deletions take, so the materialized view converges.
// Implements: REQ-d00156-A+B+C+D — HTTP shape, idempotency via record
//   no-op detection, error handling, message-type filtering.

import 'dart:convert';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

/// Fetches tombstone instructions from the diary server and materialises
/// them as local tombstone events via [EntryService.record].
///
/// This is intentionally NOT a Destination subclass — inbound polling
/// and outbound FIFO destinations are separate library concepts.
///
/// The base URL is supplied lazily through [resolveBaseUrl]. Returning
/// `null` (e.g. before the patient has linked) makes the function return
/// silently without making an HTTP call; the next sync cycle will retry
/// once the backend URL is available.
///
/// Behaviour:
/// 1. Resolve base URL via [resolveBaseUrl]. If `null`, return silently.
/// 2. GET `${baseUrl}/inbound` with `Authorization: Bearer <token>` if
///    [authToken] returns a non-null value.
/// 3. Non-200 responses → return without raising.
/// 4. 200 responses → parse body as `{"messages": [...]}`.
/// 5. For each `type: "tombstone"` message with `entry_id` and
///    `entry_type` → call
///    `entryService.record(entryType: …, aggregateId: …, eventType: 'tombstone',
///    answers: {}, changeReason: 'portal-withdrawn')`.
/// 6. Unknown `type` values → skip.
/// 7. Messages missing `entry_id` or `entry_type` → skip.
/// 8. Per-message exceptions → swallowed; loop continues.
///    Retries are safe because `EntryService.record` is idempotent via
///    its no-op-on-duplicate detection.
/// 9. Top-level network/parse/shape errors → swallowed; return without
///    raising.
// Implements: REQ-d00113-D — inbound tombstones materialise through the
//   same write path as user-driven deletions.
// Implements: REQ-d00156-A — GET /inbound with optional Bearer header;
//   parse messages array; record each tombstone.
// Implements: REQ-d00156-B — skip messages of unknown type or missing
//   required fields.
// Implements: REQ-d00156-C — top-level network/parse errors swallowed.
// Implements: REQ-d00156-D — per-message exceptions swallowed; loop
//   continues; idempotency via EntryService.record no-op detection.
Future<void> portalInboundPoll({
  required EntryService entryService,
  required http.Client client,
  required Future<Uri?> Function() resolveBaseUrl,
  Future<String?> Function()? authToken,
}) async {
  try {
    final baseUrl = await resolveBaseUrl();
    if (baseUrl == null) {
      // Patient has not enrolled yet. Skip the poll silently; the next
      // sync cycle will retry once the backend URL is available.
      return;
    }
    final url = baseUrl.resolve('inbound');

    final headers = <String, String>{};
    if (authToken != null) {
      final token = await authToken();
      if (token != null) {
        headers['authorization'] = 'Bearer $token';
      }
    }

    final response = await client.get(url, headers: headers);

    if (response.statusCode != 200) {
      debugPrint(
        '[InboundPoll] non-200 from $url: ${response.statusCode} '
        '${response.body}',
      );
      return;
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (e) {
      debugPrint('[InboundPoll] body is not valid JSON: $e');
      return;
    }

    if (decoded is! Map<String, dynamic>) {
      debugPrint(
        '[InboundPoll] expected JSON object, got ${decoded.runtimeType}',
      );
      return;
    }

    final dynamic rawMessages = decoded['messages'];
    if (rawMessages is! List) {
      debugPrint(
        '[InboundPoll] "messages" missing or wrong type: '
        '${rawMessages.runtimeType}',
      );
      return;
    }

    for (final dynamic rawMsg in rawMessages) {
      try {
        if (rawMsg is! Map<String, dynamic>) {
          debugPrint(
            '[InboundPoll] message is not a JSON object: '
            '${rawMsg.runtimeType}',
          );
          continue;
        }

        final type = rawMsg['type'];
        if (type != 'tombstone') {
          debugPrint('[InboundPoll] skipping unknown message type: $type');
          continue;
        }

        final entryId = rawMsg['entry_id'];
        final entryType = rawMsg['entry_type'];

        if (entryId is! String || entryType is! String) {
          debugPrint(
            '[InboundPoll] tombstone missing entry_id/entry_type: $rawMsg',
          );
          continue;
        }

        await entryService.record(
          entryType: entryType,
          aggregateId: entryId,
          eventType: 'tombstone',
          answers: const <String, Object?>{},
          changeReason: 'portal-withdrawn',
        );
      } catch (e, st) {
        // Per-message exceptions are swallowed. The next sync cycle will
        // retry; EntryService.record's no-op-on-duplicate behaviour makes
        // retries safe (REQ-d00156-D).
        debugPrint('[InboundPoll] message processing failed: $e\n$st');
        continue;
      }
    }
  } catch (e, st) {
    // Top-level network errors, JSON parse failures, and shape mismatches
    // are swallowed. Return without raising (REQ-d00156-C).
    debugPrint('[InboundPoll] poll failed: $e\n$st');
    return;
  }
}
