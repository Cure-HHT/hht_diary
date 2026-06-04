// End-state NATIVE outbound destination for the diary clinical entries.
//
// Unlike the transitional `LegacySyncDestination` (which hand-translates
// canonical events into the legacy `/api/v1/user/sync` wire shape), this
// destination ships the library's CANONICAL `esd/batch@1` `BatchEnvelope`
// bytes verbatim to a diary-server event-sourcing ingest. Because both nodes
// run on `event_sourcing`, there is no wire translation: `serializesNatively`
// is `true`, the library's drain reconstructs the canonical envelope, and
// [send] only POSTs the bytes.
//
// The server-side native ingest handler (`EventStore.ingestBatch`) is the
// diary-server rebuild's responsibility; this client meets it at the canonical
// `esd/batch@1` contract.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:http/http.dart' as http;

/// Outbound [Destination] that ships finalized + tombstone `DiaryEntry`
/// events to the diary server as canonical `esd/batch@1` batches.
///
/// HTTP response classification (mirrors `LegacySyncDestination` but with NO
/// wire translation — the body is the canonical envelope bytes):
///
///   - 2xx                              -> [SendOk]
///   - 401 (auth not currently valid)   -> [SendTransient] with httpStatus
///   - other 4xx (client defect)        -> [SendPermanent] (wedge)
///   - 5xx                              -> [SendTransient] with httpStatus
///   - [http.ClientException]           -> [SendTransient]
///   - [TimeoutException]               -> [SendTransient]
///   - ingest URL or JWT unresolved     -> [SendTransient]
///     (not yet enrolled — the FIFO retains the row and retries next cycle)
class DiaryServerDestination extends Destination {
  // Implements: DIARY-DEV-native-outbound-sync/A — single native destination
  //   selecting finalized + tombstone DiaryEntry events (checkpoints stay
  //   local) and shipping them as canonical esd/batch@1 batches.
  DiaryServerDestination({
    required http.Client client,
    required Future<Uri?> Function() resolveIngestUrl,
    required Future<String?> Function() authToken,
  }) : _client = client,
       _resolveIngestUrl = resolveIngestUrl,
       _authToken = authToken;

  /// Stable FIFO key for the primary diary server. SHALL NOT change for the
  /// lifetime of the store.
  static const String destinationId = 'primary';

  final http.Client _client;
  final Future<Uri?> Function() _resolveIngestUrl;
  final Future<String?> Function() _authToken;

  // ---------------------------------------------------------------------------
  // Destination identity
  // ---------------------------------------------------------------------------

  @override
  String get id => destinationId;

  /// Selects finalized + tombstone diary-entry events; excludes `checkpoint`
  /// (drafts stay diary-local) and every non-`DiaryEntry` aggregate. Survey
  /// (`<id>_survey`) events are also `DiaryEntry`, so they sync through this
  /// same destination automatically once they migrate to the new store.
  @override
  SubscriptionFilter get filter => const SubscriptionFilter(
    aggregateTypes: {diaryEntryAggregateType},
    eventTypes: {'finalized', 'tombstone'},
  );

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
      'DiaryServerDestination is native (serializesNatively): drain encodes '
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
    developer.log(
      '[$destinationId] $outcome url=$urlStr$statusStr',
      name: 'destination',
    );
    return result;
  }
}
