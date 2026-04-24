// IMPLEMENTS REQUIREMENTS:
//   REQ-p00006: Offline-First Data Entry
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DatastoreException hierarchy', () {
    group('DatabaseException', () {
      test('contains message', () {
        const exception = DatabaseException('Test database error');

        expect(exception.message, equals('Test database error'));
        expect(exception.cause, isNull);
        expect(exception.stackTrace, isNull);
      });

      test('contains cause when provided', () {
        final cause = Exception('Underlying error');
        final exception = DatabaseException('Test error', cause: cause);

        expect(exception.cause, equals(cause));
      });

      test('contains stackTrace when provided', () {
        final stackTrace = StackTrace.current;
        final exception = DatabaseException(
          'Test error',
          stackTrace: stackTrace,
        );

        expect(exception.stackTrace, equals(stackTrace));
      });

      test('toString includes message', () {
        const exception = DatabaseException('Test database error');

        expect(exception.toString(), contains('DatabaseException'));
        expect(exception.toString(), contains('Test database error'));
      });

      test('toString includes cause when present', () {
        final cause = Exception('Root cause');
        final exception = DatabaseException('Test error', cause: cause);

        expect(exception.toString(), contains('Caused by:'));
        expect(exception.toString(), contains('Root cause'));
      });
    });

    group('EventValidationException', () {
      test('contains message', () {
        const exception = EventValidationException('Invalid event data');

        expect(exception.message, equals('Invalid event data'));
        expect(exception.eventData, isNull);
      });

      test('contains eventData when provided', () {
        const exception = EventValidationException(
          'Invalid event',
          eventData: {'field': 'value'},
        );

        expect(exception.eventData, equals({'field': 'value'}));
      });

      test('toString includes event data when present', () {
        const exception = EventValidationException(
          'Invalid event',
          eventData: {'field': 'value'},
        );

        expect(exception.toString(), contains('Event data:'));
        expect(exception.toString(), contains('field'));
      });
    });

    group('SerializationException', () {
      test('contains message', () {
        const exception = SerializationException('Failed to serialize');

        expect(exception.message, equals('Failed to serialize'));
      });

      test('toString includes message', () {
        const exception = SerializationException('Serialization failed');

        expect(exception.toString(), contains('SerializationException'));
        expect(exception.toString(), contains('Serialization failed'));
      });
    });

    group('ConflictException', () {
      test('contains message', () {
        const exception = ConflictException('Conflict detected');

        expect(exception.message, equals('Conflict detected'));
        expect(exception.conflictingEventIds, isNull);
      });

      test('contains conflicting event IDs when provided', () {
        const exception = ConflictException(
          'Conflict detected',
          conflictingEventIds: ['event-1', 'event-2'],
        );

        expect(exception.conflictingEventIds, equals(['event-1', 'event-2']));
      });

      test('toString includes conflicting events when present', () {
        const exception = ConflictException(
          'Conflict',
          conflictingEventIds: ['event-1', 'event-2'],
        );

        expect(exception.toString(), contains('Conflicting events:'));
        expect(exception.toString(), contains('event-1'));
        expect(exception.toString(), contains('event-2'));
      });
    });

    group('SignatureException', () {
      test('contains message', () {
        const exception = SignatureException('Invalid signature');

        expect(exception.message, equals('Invalid signature'));
        expect(exception.eventId, isNull);
      });

      test('contains eventId when provided', () {
        const exception = SignatureException(
          'Signature verification failed',
          eventId: 'event-123',
        );

        expect(exception.eventId, equals('event-123'));
      });

      test('toString includes security alert', () {
        const exception = SignatureException('Tampering detected');

        expect(exception.toString(), contains('SECURITY ALERT'));
      });

      test('toString includes event ID when present', () {
        const exception = SignatureException('Tampering', eventId: 'event-123');

        expect(exception.toString(), contains('Event ID: event-123'));
      });

      test('toString includes cause when present', () {
        final cause = Exception('Crypto error');
        final exception = SignatureException(
          'Verification failed',
          cause: cause,
        );

        expect(exception.toString(), contains('Caused by:'));
        expect(exception.toString(), contains('Crypto error'));
      });
    });

    group('ConfigurationException', () {
      test('contains message', () {
        const exception = ConfigurationException('Invalid config');

        expect(exception.message, equals('Invalid config'));
      });

      test('toString includes message', () {
        const exception = ConfigurationException('Missing required field');

        expect(exception.toString(), contains('ConfigurationException'));
        expect(exception.toString(), contains('Missing required field'));
      });
    });
  });

  group('SyncException', () {
    group('constructor', () {
      test('creates exception with message', () {
        const exception = SyncException('Sync failed');

        expect(exception.message, equals('Sync failed'));
        expect(exception.statusCode, isNull);
        expect(exception.failedEventCount, isNull);
        expect(exception.isRetryable, isTrue);
      });

      test('creates exception with all parameters', () {
        const exception = SyncException(
          'Sync failed',
          statusCode: 500,
          failedEventCount: 5,
          isRetryable: false,
        );

        expect(exception.statusCode, equals(500));
        expect(exception.failedEventCount, equals(5));
        expect(exception.isRetryable, isFalse);
      });
    });

    group('factory constructors', () {
      test('networkError creates retryable exception', () {
        final exception = SyncException.networkError();

        expect(exception.message, contains('Network connectivity'));
        expect(exception.isRetryable, isTrue);
        expect(exception.statusCode, isNull);
      });

      test('networkError includes cause when provided', () {
        final cause = Exception('Socket error');
        final exception = SyncException.networkError(cause: cause);

        expect(exception.cause, equals(cause));
      });

      test('serverError creates exception with status code', () {
        final exception = SyncException.serverError(statusCode: 503);

        expect(exception.message, contains('Server error'));
        expect(exception.message, contains('503'));
        expect(exception.statusCode, equals(503));
        expect(exception.isRetryable, isTrue);
      });

      test('clientError creates non-retryable exception', () {
        final exception = SyncException.clientError(
          statusCode: 400,
          message: 'Bad request',
          failedEventCount: 3,
        );

        expect(exception.message, contains('Client error'));
        expect(exception.message, contains('400'));
        expect(exception.message, contains('Bad request'));
        expect(exception.statusCode, equals(400));
        expect(exception.failedEventCount, equals(3));
        expect(exception.isRetryable, isFalse);
      });

      test('authenticationError creates 401 exception', () {
        final exception = SyncException.authenticationError();

        expect(exception.message, contains('Authentication failed'));
        expect(exception.statusCode, equals(401));
        expect(exception.isRetryable, isFalse);
      });

      test('timeout creates retryable exception', () {
        final exception = SyncException.timeout();

        expect(exception.message, contains('timed out'));
        expect(exception.isRetryable, isTrue);
        expect(exception.statusCode, isNull);
      });
    });

    group('toString', () {
      test('includes base message', () {
        const exception = SyncException('Test sync error');

        expect(exception.toString(), contains('SyncException'));
        expect(exception.toString(), contains('Test sync error'));
      });

      test('includes status code when present', () {
        const exception = SyncException('Server error', statusCode: 500);

        expect(exception.toString(), contains('HTTP Status: 500'));
      });

      test('includes failed event count when present', () {
        const exception = SyncException('Sync error', failedEventCount: 7);

        expect(exception.toString(), contains('Failed events: 7'));
      });

      test('includes retryable status', () {
        const retryable = SyncException('Error', isRetryable: true);
        const notRetryable = SyncException('Error', isRetryable: false);

        expect(retryable.toString(), contains('Retryable: true'));
        expect(notRetryable.toString(), contains('Retryable: false'));
      });
    });
  });
}
