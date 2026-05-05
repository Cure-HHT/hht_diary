// Shim destination — ships nosebleed (epistaxis) events to the legacy
// `/api/v1/user/sync` endpoint until the diary server cuts over to a
// native event_sourcing_datastore receiver. Cites no REQs because this
// is a transitional translation layer, not the canonical destination
// contract; canonical REQs (d00162, d00113-C) describe the eventual
// native-format destination and stay unverified until that lands.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:http/http.dart' as http;

/// Outbound [Destination] that ships nosebleed-shape events to the
/// legacy diary server `/api/v1/user/sync` endpoint.
///
/// Each event is sent as its own POST, body shape `{"events": [event]}`,
/// matching the legacy mobile app's wire contract. Event-type strings
/// are translated to the legacy names the server's
/// `_mapEventTypeToOperation` switch recognizes:
///
///   - `finalized`  -> `nosebleedupdated`  (record_audit operation USER_UPDATE)
///   - `tombstone`  -> `nosebleeddeleted`  (record_audit operation USER_DELETE)
///
/// Other event types pass through unchanged; the server falls back to
/// `USER_CREATE` for any unrecognized string.
///
/// HTTP response classification:
///
///   - 2xx                                  -> [SendOk]
///   - 4xx                                  -> [SendPermanent]
///   - 5xx                                  -> [SendTransient] with httpStatus
///   - [http.ClientException]               -> [SendTransient]
///   - [TimeoutException]                   -> [SendTransient]
///   - `resolveBaseUrl` returns `null`      -> [SendTransient]
///     (patient not yet enrolled — FIFO retains the row, retries next cycle)
class LegacySyncDestination extends Destination {
  LegacySyncDestination({
    required http.Client client,
    required Future<Uri?> Function() resolveBaseUrl,
    required Future<String?> Function() authToken,
    required List<String> entryTypeIds,
  }) : _client = client,
       _resolveBaseUrl = resolveBaseUrl,
       _authToken = authToken,
       _filter = SubscriptionFilter(
         entryTypes: List.unmodifiable(entryTypeIds),
         predicate: _excludePortalWithdrawn,
       );

  static const String destinationId = 'legacy_sync';

  final http.Client _client;
  final Future<Uri?> Function() _resolveBaseUrl;
  final Future<String?> Function() _authToken;
  final SubscriptionFilter _filter;

  /// Filter predicate: drop events whose `change_reason` is
  /// `portal-withdrawn`. Those events were generated locally in response
  /// to an inbound tombstone the server already knows about; shipping
  /// them back would be a wasted echo.
  static bool _excludePortalWithdrawn(StoredEvent e) =>
      e.metadata['change_reason'] != 'portal-withdrawn';

  // ---------------------------------------------------------------------------
  // Destination identity
  // ---------------------------------------------------------------------------

  @override
  String get id => destinationId;

  @override
  SubscriptionFilter get filter => _filter;

  @override
  String get wireFormat => 'legacy-sync-v1';

  // ---------------------------------------------------------------------------
  // Batching policy — single-event payloads
  // ---------------------------------------------------------------------------

  @override
  Duration get maxAccumulateTime => Duration.zero;

  @override
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate) =>
      false;

  // ---------------------------------------------------------------------------
  // Wire serialization
  // ---------------------------------------------------------------------------

  @override
  Future<WirePayload> transform(List<StoredEvent> batch) async {
    if (batch.isEmpty) {
      throw ArgumentError('LegacySyncDestination.transform: empty batch');
    }
    final translated = _translateEvent(batch.single);
    final body = <String, Object?>{
      'events': [translated],
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(body)));
    return WirePayload(
      bytes: bytes,
      contentType: 'application/json',
      transformVersion: 'v1',
    );
  }

  /// Map the StoredEvent's `event_type` to the legacy server's expected
  /// string, leaving every other field untouched. Returns a fresh map
  /// (does not mutate the input).
  static Map<String, dynamic> _translateEvent(StoredEvent event) {
    final map = Map<String, dynamic>.from(event.toJson());
    final eventType = map['event_type'] as String?;
    final translated = _eventTypeTranslation[eventType];
    if (translated != null) {
      map['event_type'] = translated;
    }
    return map;
  }

  /// Translation table from canonical event-sourcing event types to the
  /// legacy server's nosebleed-specific event type strings.
  static const Map<String, String> _eventTypeTranslation = {
    'finalized': 'nosebleedupdated',
    'tombstone': 'nosebleeddeleted',
  };

  // ---------------------------------------------------------------------------
  // HTTP send
  // ---------------------------------------------------------------------------

  @override
  Future<SendResult> send(WirePayload payload) async {
    final baseUrl = await _resolveBaseUrl();
    if (baseUrl == null) {
      return _logged(
        const SendTransient(
          error: 'patient not enrolled — base URL unavailable',
        ),
        url: null,
      );
    }
    final url = baseUrl.resolve('sync');

    try {
      final token = await _authToken();
      final headers = <String, String>{'content-type': 'application/json'};
      if (token != null) {
        headers['authorization'] = 'Bearer $token';
      }

      final response = await _client.post(
        url,
        headers: headers,
        body: payload.bytes,
      );

      final status = response.statusCode;

      if (status >= 200 && status < 300) {
        return _logged(const SendOk(), url: url, status: status);
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

  /// Emit a developer-log line for every send outcome so the FIFO drain
  /// can be watched live in browser/IDE consoles. Browser console picks
  /// up `dart:developer` log records when running on Flutter web.
  SendResult _logged(SendResult result, {required Uri? url, int? status}) {
    final outcome = switch (result) {
      SendOk() => 'ok',
      SendTransient() => 'transient',
      SendPermanent() => 'permanent',
    };
    final urlStr = url?.toString() ?? '<base-url-unresolved>';
    final statusStr = status == null ? '' : ' status=$status';
    developer.log(
      '[$destinationId] $outcome url=$urlStr$statusStr',
      name: 'destination',
    );
    return result;
  }
}
