/// Base exception for RAVE API errors.
sealed class RaveException implements Exception {
  final String message;
  final int? statusCode;

  const RaveException(this.message, {this.statusCode});

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when authentication fails (401 response).
class RaveAuthenticationException extends RaveException {
  const RaveAuthenticationException([super.message = 'Authentication failed'])
    : super(statusCode: 401);
}

/// Thrown when the server returns an error response.
class RaveApiException extends RaveException {
  const RaveApiException(super.message, {super.statusCode});
}

/// Thrown when the ODM response is incomplete (unclosed \</ODM> tag).
///
/// Per RAVE documentation, an unclosed ODM element indicates that not all
/// streamed data was received. Retry logic should handle this case.
class RaveIncompleteResponseException extends RaveException {
  const RaveIncompleteResponseException([
    super.message = 'Incomplete ODM response - missing closing </ODM> tag',
  ]);
}

/// Thrown when ODM XML parsing fails.
class RaveParseException extends RaveException {
  final String? xmlSnippet;

  const RaveParseException(super.message, {this.xmlSnippet});

  @override
  String toString() {
    if (xmlSnippet != null) {
      return 'RaveParseException: $message\nXML snippet: $xmlSnippet';
    }
    return 'RaveParseException: $message';
  }
}

/// Thrown on network connectivity issues.
class RaveNetworkException extends RaveException {
  final Object? cause;

  const RaveNetworkException(super.message, {this.cause});

  @override
  String toString() {
    if (cause != null) {
      return 'RaveNetworkException: $message (cause: $cause)';
    }
    return 'RaveNetworkException: $message';
  }
}
