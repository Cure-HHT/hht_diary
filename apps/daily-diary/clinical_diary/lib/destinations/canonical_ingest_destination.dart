// Shared base for NATIVE outbound destinations that ship the library's
// CANONICAL `esd/batch@1` `BatchEnvelope` bytes verbatim to a diary-server /
// portal event-sourcing `/ingest`.
//
// Both `DiaryServerDestination` (clinical diary entries) and
// `SystemEventsDestination` (link / sync / lifecycle / FCM token + receipt)
// POST to the SAME ingest endpoint with identical HTTP semantics; the ONLY
// thing that differs between them is their FIFO [id] and their
// [SubscriptionFilter]. This base holds the common send()/wireFormat/
// serializesNatively/HTTP-classification so the two subclasses supply only
// `id` + `filter`.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:event_sourcing/event_sourcing.dart';
import 'package:http/http.dart' as http;

/// Base [Destination] for native canonical-ingest outbound queues.
///
/// Because both nodes run on `event_sourcing`, there is no wire translation:
/// [serializesNatively] is `true`, the library's drain reconstructs the
/// canonical envelope, and [send] only POSTs the bytes.
///
/// HTTP response classification (no wire translation — the body is the
/// canonical envelope bytes):
///
///   - 2xx                              -> [SendOk]
///   - 401 (auth not currently valid)   -> [SendTransient] with httpStatus
///   - other 4xx (client defect)        -> [SendPermanent] (wedge)
///   - 5xx                              -> [SendTransient] with httpStatus
///   - [http.ClientException]           -> [SendTransient]
///   - [TimeoutException]               -> [SendTransient]
///   - ingest URL or JWT unresolved     -> [SendTransient]
///     (not yet enrolled — the FIFO retains the row and retries next cycle)
abstract class CanonicalIngestDestination extends Destination {
  CanonicalIngestDestination({
    required http.Client client,
    required Future<Uri?> Function() resolveIngestUrl,
    required Future<String?> Function() authToken,
  }) : _client = client,
       _resolveIngestUrl = resolveIngestUrl,
       _authToken = authToken;

  final http.Client _client;
  final Future<Uri?> Function() _resolveIngestUrl;
  final Future<String?> Function() _authToken;

  // ---------------------------------------------------------------------------
  // Native canonical-batch wire flags (identical across canonical ingest
  // destinations).
  // ---------------------------------------------------------------------------

  /// The library's canonical batch wire format. Marks every FIFO row so the
  /// drain path reconstructs the envelope deterministically.
  @override
  String get wireFormat => BatchEnvelope.wireFormat;

  /// Consumes the library's canonical batch format: `fillBatch` skips
  /// [transform] and stamps a `BatchEnvelopeMetadata`; `drain` reconstructs
  /// the wire bytes via `BatchEnvelope.encode` and hands them to [send].
  @override
  bool get serializesNatively => true;

  // ---------------------------------------------------------------------------
  // Batching policy — ship promptly, coalesce same-tick events.
  // ---------------------------------------------------------------------------

  @override
  Duration get maxAccumulateTime => Duration.zero;

  @override
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate) =>
      true;

  // ---------------------------------------------------------------------------
  // Wire serialization — unreachable under serializesNatively.
  // ---------------------------------------------------------------------------

  @override
  Future<WirePayload> transform(List<StoredEvent> batch) async {
    // Native destinations never call transform: drain encodes esd/batch@1
    // from the FIFO row's events + envelope metadata. Throw defensively so a
    // future regression that routes a native destination through transform
    // fails loudly instead of corrupting the wire bytes.
    throw UnimplementedError(
      '$runtimeType is native (serializesNatively): drain encodes '
      'esd/batch@1; transform() must not be called.',
    );
  }

  // ---------------------------------------------------------------------------
  // HTTP send — POST the canonical bytes verbatim.
  // ---------------------------------------------------------------------------

  // Implements: DIARY-DEV-native-outbound-sync/B — classify delivery outcomes
  //   into accepted / retry-with-backoff / wedge; transient conditions
  //   (offline, not-yet-enrolled, 5xx) retry without data loss.
  @override
  Future<SendResult> send(WirePayload payload) async {
    final url = await _resolveIngestUrl();
    if (url == null) {
      return _logged(
        const SendTransient(
          error: 'participant not enrolled — ingest URL unavailable',
        ),
        url: null,
      );
    }

    final String? token;
    try {
      token = await _authToken();
    } catch (e) {
      return _logged(
        SendTransient(error: 'auth token resolution failed: $e'),
        url: url,
      );
    }
    if (token == null) {
      return _logged(
        const SendTransient(
          error: 'participant not enrolled — auth token unavailable',
        ),
        url: url,
      );
    }

    try {
      final response = await _client.post(
        url,
        headers: <String, String>{
          'content-type': 'application/json',
          'authorization': 'Bearer $token',
        },
        // POST the canonical esd/batch@1 envelope bytes as-is. No translation.
        body: payload.bytes,
      );

      final status = response.statusCode;
      if (status >= 200 && status < 300) {
        return _logged(const SendOk(), url: url, status: status);
      }
      // 401 is authorization-not-currently-valid (token not yet minted/refreshed,
      // endpoint not ready) — a transient condition that resolves without a code
      // change. Retry without data loss; never wedge. Other 4xx mean the current
      // binary formed something this server will not accept (a client defect) and
      // wedge until a corrected binary rebuilds the queue from the event log.
      if (status == 401) {
        return _logged(
          SendTransient(error: '401: ${response.body}', httpStatus: status),
          url: url,
          status: status,
        );
      }
      if (status >= 400 && status < 500) {
        return _logged(
          SendPermanent(error: '$status: ${response.body}'),
          url: url,
          status: status,
        );
      }
      return _logged(
        SendTransient(error: '$status: ${response.body}', httpStatus: status),
        url: url,
        status: status,
      );
    } on http.ClientException catch (e) {
      return _logged(SendTransient(error: e.message), url: url);
    } on TimeoutException catch (e) {
      return _logged(SendTransient(error: 'timeout: $e'), url: url);
    }
  }

  /// Emit a developer-log line for every send outcome so the FIFO drain can be
  /// watched live in browser/IDE consoles.
  SendResult _logged(SendResult result, {required Uri? url, int? status}) {
    final outcome = switch (result) {
      SendOk() => 'ok',
      SendTransient() => 'transient',
      SendPermanent() => 'permanent',
    };
    final urlStr = url?.toString() ?? '<ingest-url-unresolved>';
    final statusStr = status == null ? '' : ' status=$status';
    developer.log('[$id] $outcome url=$urlStr$statusStr', name: 'destination');
    return result;
  }
}
