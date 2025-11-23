/// Base exception for all datastore errors.
///
/// All exceptions thrown by the append-only datastore extend this class.
/// This allows callers to catch all datastore-related errors with a single
/// catch clause if needed.
abstract class DatastoreException implements Exception {
  /// Human-readable error message.
  final String message;

  /// Optional underlying cause of the error.
  final Object? cause;

  /// Optional stack trace.
  final StackTrace? stackTrace;

  const DatastoreException(
    this.message, {
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Exception thrown when database operations fail.
class DatabaseException extends DatastoreException {
  const DatabaseException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Exception thrown when event validation fails.
class EventValidationException extends DatastoreException {
  /// The invalid event data (sanitized).
  final Map<String, dynamic>? eventData;

  const EventValidationException(
    super.message, {
    this.eventData,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    if (eventData != null) {
      buffer.write('\nEvent data: $eventData');
    }
    return buffer.toString();
  }
}

/// Exception thrown when event serialization/deserialization fails.
class SerializationException extends DatastoreException {
  const SerializationException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Exception thrown when conflict detection or resolution fails.
class ConflictException extends DatastoreException {
  /// The conflicting event IDs.
  final List<String>? conflictingEventIds;

  const ConflictException(
    super.message, {
    this.conflictingEventIds,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    if (conflictingEventIds != null && conflictingEventIds!.isNotEmpty) {
      buffer.write('\nConflicting events: ${conflictingEventIds!.join(", ")}');
    }
    return buffer.toString();
  }
}

/// Exception thrown when signature verification fails.
///
/// This is a CRITICAL security exception indicating possible tampering.
class SignatureException extends DatastoreException {
  /// The event ID that failed signature verification.
  final String? eventId;

  const SignatureException(
    super.message, {
    this.eventId,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('🚨 SECURITY ALERT: $message');
    if (eventId != null) {
      buffer.write('\nEvent ID: $eventId');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Exception thrown when configuration is invalid.
class ConfigurationException extends DatastoreException {
  const ConfigurationException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}
