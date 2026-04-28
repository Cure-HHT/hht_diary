// Implements: REQ-d00113-D — tombstone instructions arriving from the
//   portal materialize as tombstone events through the same write path
//   user-driven deletions take, so the materialized view converges.
// Implements: REQ-d00156-A+B+C+D — HTTP shape, idempotency via record
//   no-op detection, error handling, message-type filtering.

import 'dart:convert';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:http/http.dart' as http;

/// Fetches tombstone instructions from the diary server and materialises
/// them as local tombstone events via [EntryService.record].
///
/// This is intentionally NOT a Destination subclass — inbound polling
/// and outbound FIFO destinations are separate library concepts.
///
/// Behaviour:
/// 1. GET `${baseUrl}/inbound` with `Authorization: Bearer <token>` if
///    [authToken] returns a non-null value.
/// 2. Non-200 responses → return without raising.
/// 3. 200 responses → parse body as `{"messages": [...]}`.
/// 4. For each `type: "tombstone"` message with `entry_id` and
///    `entry_type` → call
///    `entryService.record(entryType: …, aggregateId: …, eventType: 'tombstone',
///    answers: {}, changeReason: 'portal-withdrawn')`.
/// 5. Unknown `type` values → skip.
/// 6. Messages missing `entry_id` or `entry_type` → skip.
/// 7. Per-message exceptions → swallowed; loop continues.
///    Retries are safe because `EntryService.record` is idempotent via
///    its no-op-on-duplicate detection.
/// 8. Top-level network/parse/shape errors → swallowed; return without
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
  required Uri baseUrl,
  Future<String?> Function()? authToken,
}) async {
  try {
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
      return;
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      return;
    }

    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final dynamic rawMessages = decoded['messages'];
    if (rawMessages is! List) {
      return;
    }

    for (final dynamic rawMsg in rawMessages) {
      try {
        if (rawMsg is! Map<String, dynamic>) {
          continue;
        }

        final type = rawMsg['type'];
        if (type != 'tombstone') {
          continue;
        }

        final entryId = rawMsg['entry_id'];
        final entryType = rawMsg['entry_type'];

        if (entryId is! String || entryType is! String) {
          continue;
        }

        await entryService.record(
          entryType: entryType,
          aggregateId: entryId,
          eventType: 'tombstone',
          answers: const <String, Object?>{},
          changeReason: 'portal-withdrawn',
        );
      } catch (_) {
        // Per-message exceptions are swallowed. The next sync cycle will
        // retry; EntryService.record's no-op-on-duplicate behaviour makes
        // retries safe (REQ-d00156-D).
        continue;
      }
    }
  } catch (_) {
    // Top-level network errors, JSON parse failures, and shape mismatches
    // are swallowed. Return without raising (REQ-d00156-C).
    return;
  }
}
