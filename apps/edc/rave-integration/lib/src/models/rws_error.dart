/// Parsed Medidata RWS error response.
///
/// RWS error responses are XML documents whose root element carries
/// `ReasonCode` and `ErrorClientResponseMessage` attributes. See
/// `tools/EDC-integration/docs/RAVE_ERROR_CODES.md` in the callisto repo
/// for the canonical schema.
class RwsError {
  /// The RWS error code (e.g., "RWS00008"), if present.
  final String? reasonCode;

  /// Medidata's human-readable error message, if present.
  final String? message;

  const RwsError({this.reasonCode, this.message});
}

/// Parses an RWS error response body. Returns `null` when neither the
/// `ReasonCode` nor `ErrorClientResponseMessage` attribute is found.
///
/// The parser is regex-based and tolerates malformed XML — it will not
/// throw on plain text, empty input, or partially formed responses.
RwsError? parseRwsError(String body) {
  if (body.isEmpty) return null;
  final code = _rxCode.firstMatch(body)?.group(1);
  final msg = _rxMessage.firstMatch(body)?.group(1);
  if (code == null && msg == null) return null;
  return RwsError(reasonCode: code, message: msg);
}

final _rxCode = RegExp(r'ReasonCode="([^"]+)"');
final _rxMessage = RegExp(r'ErrorClientResponseMessage="([^"]+)"');
