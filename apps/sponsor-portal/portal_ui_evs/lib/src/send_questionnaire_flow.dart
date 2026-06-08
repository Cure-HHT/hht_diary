// Pure send-POST helper for the Manage Questionnaires modal. Posts to the
// server's `POST /admin/questionnaire/send` orchestration endpoint and maps the
// HTTP response to a small sealed [SendOutcome] the dialog flow switches on.
// No Flutter here — this is unit-tested directly with a mock http.Client.
//
// The server contract (send_questionnaire_handler.dart):
//   * 200 {instanceId, studyEvent}         -> [SendSent]
//   * 422 {error: needs_initial_cycle_...} -> [SendNeedsCycleSelection]
//   * 409 {error: <reason>}                -> [SendBlocked]
//   * 403/400/500 {error}                  -> [SendError]
//
// Implements: DIARY-BASE-questionnaire-coordinator-workflow/C
// Implements: DIARY-BASE-questionnaire-manage-modal/I+J
import 'dart:convert';

import 'package:http/http.dart' as http;

/// The outcome of a send POST, mapped from the HTTP response status + body.
sealed class SendOutcome {
  const SendOutcome();
}

/// 200 — the instance was sent (or the next cycle was started). The card flips
/// to Sent reactively via the view; [studyEvent] is the cycle it landed on.
class SendSent extends SendOutcome {
  const SendSent({required this.instanceId, this.studyEvent});
  final String instanceId;
  final String? studyEvent;
}

/// 422 needs_initial_cycle_selection — the first send of this type requires the
/// coordinator to pick the starting cycle; the flow opens the Select Starting
/// Cycle dialog and re-posts with an explicit `studyEvent`.
class SendNeedsCycleSelection extends SendOutcome {
  const SendNeedsCycleSelection();
}

/// 409 — blocked by the server (e.g. an open instance already exists, or a
/// duplicate cycle). [reason] is the server-supplied `error` string.
class SendBlocked extends SendOutcome {
  const SendBlocked(this.reason);
  final String reason;
}

/// 403/400/500 (or a transport failure) — a generic error to surface. [message]
/// is the server `error` string where available, else a transport description.
class SendError extends SendOutcome {
  const SendError(this.message);
  final String message;
}

/// Posts a questionnaire send to `POST /admin/questionnaire/send` and maps the
/// response to a [SendOutcome].
///
/// [bearer] is the full `<identityCredential>|<activeRole>` credential (mirrors
/// AuditLogScreen). [body] is the request JSON — `{siteId, participantId,
/// questionnaireType}` for an unqualified send, optionally `+ studyEvent` for an
/// explicit starting-cycle re-send.
///
/// Implements: DIARY-BASE-questionnaire-coordinator-workflow/C
Future<SendOutcome> postSend(
  http.Client client,
  String serverUrl,
  String bearer,
  Map<String, Object?> body,
) async {
  try {
    final resp = await client.post(
      Uri.parse('$serverUrl/admin/questionnaire/send'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $bearer',
      },
      body: jsonEncode(body),
    );
    final error = _errorOf(resp.body);
    switch (resp.statusCode) {
      case 200:
        final decoded = _decode(resp.body);
        return SendSent(
          instanceId: (decoded['instanceId'] as String?) ?? '?',
          studyEvent: decoded['studyEvent'] as String?,
        );
      case 422:
        return const SendNeedsCycleSelection();
      case 409:
        return SendBlocked(error ?? 'Send was blocked.');
      default:
        return SendError(error ?? 'HTTP ${resp.statusCode}');
    }
  } catch (e) {
    return SendError('$e');
  }
}

/// Decodes a JSON object body, defending against non-object / unparseable
/// bodies (returns an empty map).
Map<String, Object?> _decode(String body) {
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, Object?> ? decoded : const {};
  } catch (_) {
    return const {};
  }
}

/// Extracts the `error` string from a JSON `{error: ...}` body, or null.
String? _errorOf(String body) => _decode(body)['error'] as String?;
