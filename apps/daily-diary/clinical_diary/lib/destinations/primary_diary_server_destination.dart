// Implements: REQ-d00155-A+B+C+D+E (destination contract); REQ-d00113-C
//   (409 questionnaire_deleted → SendOk so the FIFO drains; the locally
//   recorded event remains the audit fact).

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:http/http.dart' as http;

/// Outbound [Destination] that ships diary events to the clinical diary server.
///
/// Each event is sent as a standalone POST request to `{baseUrl}/events` with
/// the event serialized as a JSON object (`application/json`). Single-event
/// payloads are flushed immediately ([maxAccumulateTime] is [Duration.zero],
/// [canAddToBatch] always returns `false`).
///
/// The base URL is supplied lazily through `resolveBaseUrl`. Returning `null`
/// (e.g. before the patient has linked) makes [send] return [SendTransient]
/// so the FIFO preserves the events and retries on the next sync cycle.
///
/// HTTP response classification:
/// - 2xx                                        → [SendOk]
/// - 409 with `{"error": "questionnaire_deleted"}` → [SendOk]
///   (REQ-d00113-C: questionnaire was deleted server-side; the locally
///   recorded event remains the audit fact and the FIFO must drain.)
/// - 409 other body                             → [SendPermanent]
/// - 4xx other                                  → [SendPermanent]
/// - 5xx                                        → [SendTransient]
/// - [http.ClientException]                     → [SendTransient]
/// - [TimeoutException]                         → [SendTransient]
/// - `resolveBaseUrl` returns `null`            → [SendTransient]
// Implements: REQ-d00155-A — stable id 'primary_diary_server'.
// Implements: REQ-d00155-B — SubscriptionFilter() matches every user event.
// Implements: REQ-d00155-C — single-event payloads (canAddToBatch = false,
//   maxAccumulateTime = Duration.zero).
// Implements: REQ-d00155-D — transform serializes the event to JSON bytes.
// Implements: REQ-d00155-E — send classifies HTTP responses into SendResult.
// Implements: REQ-d00113-C — 409 questionnaire_deleted translated to SendOk.
class PrimaryDiaryServerDestination extends Destination {
  PrimaryDiaryServerDestination({
    required http.Client client,
    required Future<Uri?> Function() resolveBaseUrl,
    required Future<String?> Function() authToken,
  }) : _client = client,
       _resolveBaseUrl = resolveBaseUrl,
       _authToken = authToken;

  final http.Client _client;
  final Future<Uri?> Function() _resolveBaseUrl;
  final Future<String?> Function() _authToken;

  // -------------------------------------------------------------------------
  // Destination identity
  // -------------------------------------------------------------------------

  @override
  // Implements: REQ-d00155-A — stable FIFO store key.
  String get id => 'primary_diary_server';

  @override
  // Implements: REQ-d00155-B — every user entry-type / event-type is admitted;
  // system events excluded by the default SubscriptionFilter.
  SubscriptionFilter get filter => const SubscriptionFilter();

  @override
  String get wireFormat => 'json-v1';

  // -------------------------------------------------------------------------
  // Batching policy — single-event payloads
  // -------------------------------------------------------------------------

  @override
  // Implements: REQ-d00155-C — flush immediately; never accumulate.
  Duration get maxAccumulateTime => Duration.zero;

  @override
  // Implements: REQ-d00155-C — each event becomes its own independent FIFO
  // entry, keeping events strictly ordered in the drain queue.
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate) =>
      false;

  // -------------------------------------------------------------------------
  // Wire serialization
  // -------------------------------------------------------------------------

  @override
  // Implements: REQ-d00155-D — serialize the single event in the batch as a
  // flat JSON object; the batch always has length 1 because canAddToBatch
  // returns false.
  Future<WirePayload> transform(List<StoredEvent> batch) async {
    final eventMap = batch.single.toJson();
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(eventMap)));
    return WirePayload(
      bytes: bytes,
      contentType: 'application/json',
      transformVersion: 'v1',
    );
  }

  // -------------------------------------------------------------------------
  // HTTP send
  // -------------------------------------------------------------------------

  @override
  // Implements: REQ-d00155-E — POST to {baseUrl}/events; classify response.
  // Implements: REQ-d00113-C — 409 questionnaire_deleted → SendOk.
  Future<SendResult> send(WirePayload payload) async {
    final baseUrl = await _resolveBaseUrl();
    if (baseUrl == null) {
      // Patient has not enrolled yet (no backend URL resolvable). Return
      // SendTransient so the FIFO preserves the event and retries on the
      // next sync cycle once enrollment populates the backend URL.
      return const SendTransient(
        error: 'patient not enrolled — base URL unavailable',
      );
    }
    final url = baseUrl.resolve('events');

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

      // 2xx — success
      if (status >= 200 && status < 300) {
        return const SendOk();
      }

      // 409 — distinguish questionnaire_deleted from other conflicts
      if (status == 409) {
        // REQ-d00113-C: If the server signals that the questionnaire was
        // deleted, treat as SendOk so the FIFO drains. The locally recorded
        // event remains the audit fact.
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> &&
              decoded['error'] == 'questionnaire_deleted') {
            return const SendOk();
          }
        } on FormatException {
          // body isn't JSON; fall through to SendPermanent.
        }
        return SendPermanent(error: '409: ${response.body}');
      }

      // Other 4xx — permanent failure
      if (status >= 400 && status < 500) {
        return SendPermanent(error: '$status: ${response.body}');
      }

      // 5xx — transient failure; server should recover
      return SendTransient(
        error: '$status: ${response.body}',
        httpStatus: status,
      );
    } on http.ClientException catch (e) {
      return SendTransient(error: e.message);
    } on TimeoutException catch (e) {
      return SendTransient(error: 'timeout: $e');
    }
  }
}
