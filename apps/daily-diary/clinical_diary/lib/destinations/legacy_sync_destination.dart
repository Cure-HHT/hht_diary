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
/// matching the legacy mobile app's wire contract.
///
/// **Event-type translation** — translated to the legacy strings that
/// the server's `_mapEventTypeToOperation` switch recognizes:
///
///   - `finalized`  -> `nosebleedupdated`  (record_audit operation USER_UPDATE)
///   - `tombstone`  -> `nosebleeddeleted`  (record_audit operation USER_DELETE)
///
/// Other event types pass through unchanged; the server falls back to
/// `USER_CREATE` for any unrecognized string.
///
/// **Data-payload translation** — the StoredEvent's `data` field
/// (canonical shape `{answers: {...}, checkpoint_reason: ?}`) is
/// projected to the legacy `EventRecord` shape that the
/// `record_audit` `validate_diary_data` trigger requires:
///
/// ```json
/// {
///   "id": "<aggregate uuid>",
///   "versioned_type": "epistaxis-v1.0",
///   "event_data": {
///     "id": "<aggregate uuid>",
///     "startTime": "<ISO 8601>",
///     "lastModified": "<ISO 8601>",
///     "isNoNosebleedsEvent": true,   // for no_epistaxis_event entry type
///     "isUnknownNosebleedsEvent": true, // for unknown_day_event entry type
///     "endTime": "...",              // optional, epistaxis_event only
///     "intensity": "..."             // optional, epistaxis_event only
///   }
/// }
/// ```
///
/// All three nosebleed entry types map to the same `versioned_type`
/// (`epistaxis-v1.0`); sub-type is encoded via the boolean flags so a
/// single legacy validator covers them.
///
/// HTTP response classification:
///
///   - 2xx                                  -> [SendOk]
///   - 4xx                                  -> [SendPermanent]
///   - 5xx                                  -> [SendTransient] with httpStatus
///   - [http.ClientException]               -> [SendTransient]
///   - [TimeoutException]                   -> [SendTransient]
///   - `resolveBaseUrl` returns `null`      -> [SendTransient]
///     (participant not yet enrolled — FIFO retains the row, retries next cycle)
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

  /// Build the wire representation of [event]:
  ///
  /// 1. Translate `event_type` to the legacy operation string.
  /// 2. Project `data` into the legacy `EventRecord` shape so the
  ///    server's `validate_diary_data` trigger accepts it.
  ///
  /// Returns a fresh map; does not mutate the input.
  static Map<String, dynamic> _translateEvent(StoredEvent event) {
    final map = Map<String, dynamic>.from(event.toJson());
    final eventType = map['event_type'] as String?;
    final translated = _eventTypeTranslation[eventType];
    if (translated != null) {
      map['event_type'] = translated;
    }
    map['data'] = _legacyDataFor(event);
    return map;
  }

  /// Translation table from canonical event-sourcing event types to the
  /// legacy server's nosebleed-specific event type strings.
  static const Map<String, String> _eventTypeTranslation = {
    'finalized': 'nosebleedupdated',
    'tombstone': 'nosebleeddeleted',
  };

  /// Project `event.data.answers` into the legacy `EventRecord` shape.
  /// All three nosebleed entry types share `versioned_type:
  /// 'epistaxis-v1.0'`; sub-type is encoded via boolean flags. The
  /// `startTime` / `lastModified` fields are required by
  /// `validate_epistaxis_data`; we resolve `startTime` from the
  /// answers' `startTime` (epistaxis_event) or `date` (no_epistaxis /
  /// unknown_day) field, and fall back to the event's
  /// `client_timestamp` so a tombstone with empty answers still
  /// satisfies the validator.
  static Map<String, dynamic> _legacyDataFor(StoredEvent event) {
    final rawAnswers = event.data['answers'];
    final answers = rawAnswers is Map<String, dynamic>
        ? rawAnswers
        : const <String, dynamic>{};

    final lastModifiedIso = event.clientTimestamp.toUtc().toIso8601String();
    final startTime = _resolveStartTime(answers) ?? lastModifiedIso;

    final eventData = <String, Object?>{
      'id': event.aggregateId,
      'startTime': startTime,
      'lastModified': lastModifiedIso,
    };

    if (event.entryType == 'no_epistaxis_event') {
      eventData['isNoNosebleedsEvent'] = true;
    } else if (event.entryType == 'unknown_day_event') {
      eventData['isUnknownNosebleedsEvent'] = true;
    } else {
      // epistaxis_event — pass optional fields through. Skip
      // 'severity' translation: mobile records `intensity` (vocabulary
      // 'spotting' / 'pouring' / etc.) which does not match the
      // legacy validator's enum (`minimal` / `mild` / ...). The legacy
      // `severity` field is optional, so leaving it unset keeps the
      // trigger happy; `intensity` rides along as an extra field for
      // downstream display.
      for (final key in const ['endTime', 'intensity']) {
        final value = answers[key];
        if (value != null) eventData[key] = value;
      }
    }

    return <String, dynamic>{
      'id': event.aggregateId,
      'versioned_type': 'epistaxis-v1.0',
      'event_data': eventData,
    };
  }

  /// epistaxis_event uses `startTime`; no_epistaxis_event and
  /// unknown_day_event use `date` (per `_nosebleedTypes` in
  /// clinical_diary_entry_types.dart's `effectiveDatePath`). Returns
  /// the ISO-8601 string when the answer field is present, else null.
  static String? _resolveStartTime(Map<String, dynamic> answers) {
    final raw = answers['startTime'] ?? answers['date'];
    if (raw is String) return raw;
    if (raw is DateTime) return raw.toUtc().toIso8601String();
    return null;
  }

  // ---------------------------------------------------------------------------
  // HTTP send
  // ---------------------------------------------------------------------------

  @override
  Future<SendResult> send(WirePayload payload) async {
    final baseUrl = await _resolveBaseUrl();
    if (baseUrl == null) {
      return _logged(
        const SendTransient(
          error: 'participant not enrolled — base URL unavailable',
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
