import 'package:append_only_datastore/src/core/errors/datastore_exception.dart';

/// Exception thrown when synchronization operations fail.
class SyncException extends DatastoreException {

  const SyncException(
    super.message, {
    this.statusCode,
    this.failedEventCount,
    this.isRetryable = true,
    super.cause,
    super.stackTrace,
  });

  /// Create a network connectivity error.
  factory SyncException.networkError({Object? cause, StackTrace? stackTrace}) {
    return SyncException(
      'Network connectivity error. Will retry automatically.',
      isRetryable: true,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Create a server error (5xx).
  factory SyncException.serverError({
    required int statusCode,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return SyncException(
      'Server error (HTTP $statusCode). Will retry automatically.',
      statusCode: statusCode,
      isRetryable: true,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Create a client error (4xx).
  factory SyncException.clientError({
    required int statusCode,
    required String message,
    int? failedEventCount,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return SyncException(
      'Client error (HTTP $statusCode): $message',
      statusCode: statusCode,
      failedEventCount: failedEventCount,
      isRetryable: false, // 4xx errors typically aren't retryable
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Create an authentication error.
  factory SyncException.authenticationError({
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return SyncException(
      'Authentication failed. Please log in again.',
      statusCode: 401,
      isRetryable: false,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Create a timeout error.
  factory SyncException.timeout({Object? cause, StackTrace? stackTrace}) {
    return SyncException(
      'Sync operation timed out. Will retry automatically.',
      isRetryable: true,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
  /// HTTP status code, if applicable.
  final int? statusCode;

  /// Number of events that failed to sync.
  final int? failedEventCount;

  /// Whether this is a retryable error.
  final bool isRetryable;

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    if (statusCode != null) {
      buffer.write('\nHTTP Status: $statusCode');
    }
    if (failedEventCount != null) {
      buffer.write('\nFailed events: $failedEventCount');
    }
    buffer.write('\nRetryable: $isRetryable');
    return buffer.toString();
  }
}
