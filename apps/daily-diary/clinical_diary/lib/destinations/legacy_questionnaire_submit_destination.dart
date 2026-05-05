// Shim destination — ships finalized questionnaire submissions to the
// legacy `POST /api/v1/user/questionnaires/<instanceId>/submit` endpoint
// until the diary server cuts over to a native event_sourcing_datastore
// receiver. Cites no REQs because this is a transitional translation
// layer; the canonical questionnaire-submission contract lives on the
// future native destination.
//
// The mobile event log stores the full QuestionnaireSubmission payload
// inside `event.data`. See `clinical_diary/lib/screens/home_screen.dart`
// — the home screen records:
//
//   {
//     'instance_id': '...',
//     'questionnaire_type': '...',
//     'version': '...',
//     'completed_at': '...',
//     'responses': [{'question_id', 'value', 'display_label',
//                    'normalized_label'}, ...],
//     'study_event': '...'   // optional, cycle label
//   }
//
// The destination forwards `responses`, `questionnaire_type`, `version`,
// `completed_at` (the keys the legacy submitQuestionnaireHandler reads)
// to the URL `<base>/questionnaires/<instance_id>/submit` and ignores
// the rest.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:http/http.dart' as http;

/// Outbound [Destination] that ships finalized survey events to the
/// legacy diary server's questionnaire-submit endpoint.
///
/// HTTP response classification:
///
///   - 2xx                                                -> [SendOk]
///   - 409 with body `{"error": "questionnaire_deleted"}` -> [SendOk]
///     (server soft-deleted the questionnaire mid-flow; the local event
///     remains the audit fact and the FIFO must drain.)
///   - 409 other body                                     -> [SendPermanent]
///   - 4xx other                                          -> [SendPermanent]
///   - 5xx                                                -> [SendTransient]
///   - [http.ClientException]                             -> [SendTransient]
///   - [TimeoutException]                                 -> [SendTransient]
///   - `resolveBaseUrl` returns `null`                    -> [SendTransient]
class LegacyQuestionnaireSubmitDestination extends Destination {
  LegacyQuestionnaireSubmitDestination({
    required http.Client client,
    required Future<Uri?> Function() resolveBaseUrl,
    required Future<String?> Function() authToken,
    required List<String> entryTypeIds,
  }) : _client = client,
       _resolveBaseUrl = resolveBaseUrl,
       _authToken = authToken,
       _filter = SubscriptionFilter(
         entryTypes: List.unmodifiable(entryTypeIds),
         eventTypes: const ['finalized'],
         predicate: _excludePortalWithdrawn,
       );

  static const String destinationId = 'legacy_questionnaire_submit';

  final http.Client _client;
  final Future<Uri?> Function() _resolveBaseUrl;
  final Future<String?> Function() _authToken;
  final SubscriptionFilter _filter;

  /// Defense-in-depth filter predicate: even though the eventTypes
  /// allow-list already restricts to `finalized` (so portal-withdrawn
  /// tombstones never reach this filter), an explicit predicate makes
  /// the policy survive future event_type additions.
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
  String get wireFormat => 'legacy-questionnaire-submit-v1';

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
      throw ArgumentError(
        'LegacyQuestionnaireSubmitDestination.transform: empty batch',
      );
    }
    final event = batch.single;
    // EntryService.record nests the user-supplied map under `data['answers']`
    // (see entry_service.dart:243-246). The questionnaire payload lives
    // there, not at the top of `data`.
    final answers = event.data['answers'];
    if (answers is! Map) {
      throw FormatException(
        'survey event ${event.eventId} has no `answers` map in data',
      );
    }
    final responses = answers['responses'];
    if (responses is! List) {
      throw FormatException(
        'survey event ${event.eventId} has no `responses` list in '
        'data.answers',
      );
    }
    // The wire payload carries `instance_id` only as a transport hop:
    // drain.dart hands `send` a [WirePayload] but not the source event,
    // so the URL-bound id has to ride along with the body. `send`
    // strips it before POSTing; the legacy server reads the id from
    // the URL path and ignores any body field of the same name.
    final body = <String, Object?>{
      'instance_id': event.aggregateId,
      'responses': responses,
      'questionnaire_type': answers['questionnaire_type'],
      'version': answers['version'],
      'completed_at': answers['completed_at'],
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(body)));
    return WirePayload(
      bytes: bytes,
      contentType: 'application/json',
      transformVersion: 'v1',
    );
  }

  // ---------------------------------------------------------------------------
  // HTTP send
  // ---------------------------------------------------------------------------

  @override
  Future<SendResult> send(WirePayload payload) async {
    final body = jsonDecode(utf8.decode(payload.bytes)) as Map<String, dynamic>;
    final instanceId = body['instance_id'];
    if (instanceId is! String) {
      // transform invariant: instance_id is always present. Reaching
      // this branch means a hand-built payload bypassed transform —
      // permanent so the FIFO does not loop.
      return _logged(
        SendPermanent(
          error: 'instance_id missing from transform output (got $instanceId)',
        ),
        url: null,
      );
    }

    final baseUrl = await _resolveBaseUrl();
    if (baseUrl == null) {
      return _logged(
        const SendTransient(
          error: 'patient not enrolled — base URL unavailable',
        ),
        url: null,
      );
    }
    // baseUrl convention: `<backend>/api/v1/user/` (trailing slash).
    // Resolve to `<backend>/api/v1/user/questionnaires/<id>/submit`.
    final url = baseUrl.resolve('questionnaires/$instanceId/submit');

    // Strip instance_id from the body before sending — the server reads
    // it from the URL path; carrying it in the body is harmless but
    // surplus, and keeping the wire small simplifies log inspection.
    body.remove('instance_id');
    final wireBytes = Uint8List.fromList(utf8.encode(jsonEncode(body)));

    try {
      final token = await _authToken();
      final headers = <String, String>{'content-type': 'application/json'};
      if (token != null) {
        headers['authorization'] = 'Bearer $token';
      }

      final response = await _client.post(
        url,
        headers: headers,
        body: wireBytes,
      );

      final status = response.statusCode;

      if (status >= 200 && status < 300) {
        return _logged(const SendOk(), url: url, status: status);
      }

      // 409 — distinguish questionnaire_deleted from other conflicts.
      if (status == 409) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> &&
              decoded['error'] == 'questionnaire_deleted') {
            return _logged(const SendOk(), url: url, status: status);
          }
        } on FormatException {
          // body isn't JSON; fall through to SendPermanent.
        }
        return _logged(
          SendPermanent(error: '409: ${response.body}'),
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

  /// Emit a developer-log line for every send outcome so the FIFO drain
  /// can be watched live in browser/IDE consoles.
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
