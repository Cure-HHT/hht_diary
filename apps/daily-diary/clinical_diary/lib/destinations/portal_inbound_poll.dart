// Implements: REQ-d00113-D — tombstone instructions arriving from the
//   portal materialize as tombstone events through the same write path
//   user-driven deletions take, so the materialized view converges.
// Implements: REQ-d00156-A+B+C+D — HTTP shape, idempotency via record
//   no-op detection, error handling, message-type filtering.
// Implements: REQ-d00158-A+B — when EntryService.record refuses to apply
//   a received tombstone, the failure is appended to the local event log
//   as an inbound_tombstone_record_failed audit event so the data team
//   has an immutable per-device record of the gap.

import 'dart:convert';

import 'package:clinical_diary/entry_types/clinical_diary_entry_types.dart'
    show kInboundTombstoneRecordFailedEntryType;
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:http/http.dart' as http;

/// Initiator stamped on the inbound-poll audit event. Constant so the
/// audit row is identifiable without having to inspect the data payload.
const _inboundPollInitiator = AutomationInitiator(service: 'inbound-poll');

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
/// 8. Per-message exceptions → swallowed; loop continues. The failure is
///    audited via an [kInboundTombstoneRecordFailedEntryType] event
///    appended directly to the event log; the next sync cycle retries
///    the original tombstone (idempotent via [EntryService.record]'s
///    no-op-on-duplicate detection).
/// 9. Top-level network/parse/shape errors → swallowed; return without
///    raising.
///
/// Silent-skip rationale (do NOT add observability without reading this):
/// REQ-d00156-C/D require swallowing rather than raising. Each branch
/// carries an inline note explaining why a silent skip is the correct
/// response — almost all of them are either transient (retried next
/// tick) or a server-side contract regression that the server already
/// observes via its own OTel pipeline. Only branch (8) — a tombstone
/// instruction the device cannot apply — represents per-device data
/// drift, and it is recorded as an audit event rather than a log line.
// Implements: REQ-d00113-D — inbound tombstones materialise through the
//   same write path as user-driven deletions.
// Implements: REQ-d00156-A — GET /inbound with optional Bearer header;
//   parse messages array; record each tombstone.
// Implements: REQ-d00156-B — skip messages of unknown type or missing
//   required fields.
// Implements: REQ-d00156-C — top-level network/parse errors swallowed.
// Implements: REQ-d00156-D — per-message exceptions swallowed; loop
//   continues; idempotency via EntryService.record no-op detection.
// Implements: REQ-d00158-B — per-message record failures appended as
//   audit events instead of debug-printed.
Future<void> portalInboundPoll({
  required EntryService entryService,
  required EventStore eventStore,
  required http.Client client,
  required Future<Uri?> Function() resolveBaseUrl,
  Future<String?> Function()? authToken,
}) async {
  try {
    final baseUrl = await resolveBaseUrl();
    if (baseUrl == null) {
      // Silent-skip: the patient has not linked yet. The destination
      // FIFO retains anything queued for the server, and the next sync
      // cycle will retry the poll once enrollment populates the URL.
      // Recording this as an audit event would create one row per
      // sync trigger pre-enrollment (every 15 minutes for an idle
      // unlinked install) — pure noise.
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
      // Silent-skip: 4xx/5xx is observed by the diary server itself
      // (it has otel_common middleware on every request handler). The
      // mobile side does not need to mirror server-side telemetry; a
      // patient device that sees 401/403/5xx will retry on the next
      // tick once the server-side issue is resolved.
      return;
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      // Silent-skip: a 200 with non-JSON body is a server-side contract
      // regression that affects every patient identically. The diary
      // server's OTel pipeline already covers detection upstream; there
      // is nothing per-device to record.
      return;
    }

    if (decoded is! Map<String, dynamic>) {
      // Silent-skip: same rationale as the FormatException branch above
      // — server contract regression, server-side observable.
      return;
    }

    final dynamic rawMessages = decoded['messages'];
    if (rawMessages is! List) {
      // Silent-skip: server contract regression (see above).
      return;
    }

    for (final dynamic rawMsg in rawMessages) {
      try {
        if (rawMsg is! Map<String, dynamic>) {
          // Silent-skip: malformed individual message; rest of the
          // batch may still be valid. Server-side telemetry is the
          // right detection layer.
          continue;
        }

        final type = rawMsg['type'];
        if (type != 'tombstone') {
          // Silent-skip: forward-compatible — a future message kind
          // (e.g. priority change) shipped to a stale build. Once
          // mobile is upgraded the message will be honored. No
          // per-device action is possible.
          continue;
        }

        final entryId = rawMsg['entry_id'];
        final entryType = rawMsg['entry_type'];

        if (entryId is! String || entryType is! String) {
          // Silent-skip: malformed tombstone — without an entry_id or
          // entry_type there is nothing to apply or audit.
          continue;
        }

        await entryService.record(
          entryType: entryType,
          aggregateId: entryId,
          eventType: 'tombstone',
          answers: const <String, Object?>{},
          changeReason: 'portal-withdrawn',
        );
      } catch (e) {
        // REQ-d00156-D + REQ-d00158-B — the EntryService.record call
        // refused this tombstone (e.g. the entry_type is not registered
        // in this build, schema validation rejected it, or storage
        // raised). Record the failure as an audit event so the gap is
        // visible to the data team across the patient population, then
        // continue with the rest of the batch. The next sync cycle
        // retries the original instruction; if the underlying cause is
        // resolved (e.g. mobile is upgraded), the retry succeeds and
        // the audit row is the only history of the prior outage.
        await _recordRecordFailure(
          eventStore: eventStore,
          rawMsg: rawMsg as Map<String, dynamic>,
          error: e,
        );
        continue;
      }
    }
  } catch (_) {
    // Silent-skip: network errors, JSON parse failures, and shape
    // mismatches at the request envelope level (REQ-d00156-C). Same
    // server-side observability rationale as the body-shape branches
    // above; we do not want an audit row for every offline tick.
    return;
  }
}

/// Append an `inbound_tombstone_record_failed` audit event recording the
/// failed tombstone's identity, the original message envelope, and the
/// stringified error. The audit row is appended on the install's
/// per-device system aggregate (mirroring how the bootstrap registry-init
/// audit aggregates) so all inbound-poll failures for one install form a
/// single hash-chained timeline.
///
/// Failures of THIS append are themselves swallowed — if the event store
/// is so degraded that it cannot record the audit, the original failure
/// is unrecoverable and re-raising would only crash the sync cycle.
// Implements: REQ-d00158-A — the audit entry type is registered with
//   materialize=false so the row never reaches the diary view.
// Implements: REQ-d00158-B — payload carries entry_id, entry_type, and
//   stringified error.
Future<void> _recordRecordFailure({
  required EventStore eventStore,
  required Map<String, dynamic> rawMsg,
  required Object error,
}) async {
  try {
    final def = eventStore.entryTypes.byId(
      kInboundTombstoneRecordFailedEntryType,
    );
    if (def == null) {
      // The entry type is not registered. This indicates a bootstrap
      // wiring bug rather than a runtime fault; failing silently here
      // is consistent with REQ-d00156-D (the loop must not raise),
      // and the test suite covers the registration path.
      return;
    }
    await eventStore.append(
      entryType: kInboundTombstoneRecordFailedEntryType,
      entryTypeVersion: def.registeredVersion,
      aggregateId: eventStore.source.identifier,
      aggregateType: 'inbound_poll_audit',
      eventType: 'finalized',
      data: <String, Object?>{
        'failed_entry_id': rawMsg['entry_id'],
        'failed_entry_type': rawMsg['entry_type'],
        'instruction_type': rawMsg['type'],
        'error': error.toString(),
      },
      initiator: _inboundPollInitiator,
    );
  } catch (_) {
    // Audit-emission failure: the event store is itself unhealthy.
    // Swallow so the surrounding poll loop survives; the next tick
    // will re-attempt both the original tombstone and (on its own
    // failure) this audit emission.
    return;
  }
}
