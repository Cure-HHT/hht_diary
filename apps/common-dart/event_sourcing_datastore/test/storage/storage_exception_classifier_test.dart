import 'dart:async';
import 'dart:io';

import 'package:event_sourcing_datastore/src/storage/storage_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';

void main() {
  group('classifyStorageException', () {
    // Verifies: REQ-d00143-B — classifier returns a StorageException for any
    // input; never throws.
    test('REQ-d00143-B: returns a StorageException for any input', () {
      final stack = StackTrace.current;
      // A pathological input: a plain object that is not an Exception.
      final weird = Object();
      final result = classifyStorageException(weird, stack);
      expect(result, isA<StorageException>());
    });

    // Verifies: REQ-d00143-C — TimeoutException classifies as
    // StorageTransientException.
    test(
      'REQ-d00143-C: TimeoutException classifies as StorageTransientException',
      () {
        final stack = StackTrace.current;
        final error = TimeoutException(
          'op timed out',
          const Duration(seconds: 5),
        );
        final result = classifyStorageException(error, stack);
        expect(result, isA<StorageTransientException>());
        expect(identical(result.cause, error), isTrue);
        expect(identical(result.stackTrace, stack), isTrue);
      },
    );

    // Verifies: REQ-d00143-D — FormatException (event-data decode failure)
    // classifies as StorageCorruptException.
    test(
      'REQ-d00143-D: FormatException on decode classifies as StorageCorruptException',
      () {
        final stack = StackTrace.current;
        const error = FormatException('bad JSON');
        final result = classifyStorageException(error, stack);
        expect(result, isA<StorageCorruptException>());
      },
    );

    // Verifies: REQ-d00143-D — FormatException whose message contains
    // "hash chain" classifies as StorageCorruptException (same bucket, but
    // the wording exemplar from the REQ).
    test(
      'REQ-d00143-D: hash-chain-mismatch FormatException classifies as corrupt',
      () {
        final stack = StackTrace.current;
        const error = FormatException(
          'hash chain break at sequence 42: previous_event_hash mismatch',
        );
        final result = classifyStorageException(error, stack);
        expect(result, isA<StorageCorruptException>());
        expect(result.message, contains('hash chain'));
      },
    );

    // Verifies: REQ-d00143-E — FileSystemException with permission error
    // classifies as StoragePermanentException.
    test(
      'REQ-d00143-E: FileSystemException classifies as StoragePermanentException',
      () {
        final stack = StackTrace.current;
        const error = FileSystemException(
          'permission denied',
          '/protected/db.db',
        );
        final result = classifyStorageException(error, stack);
        expect(result, isA<StoragePermanentException>());
      },
    );

    // Verifies: REQ-d00143-E — bare StateError classifies as permanent.
    test(
      'REQ-d00143-E: StateError classifies as StoragePermanentException',
      () {
        final stack = StackTrace.current;
        final error = StateError('database is closed');
        final result = classifyStorageException(error, stack);
        expect(result, isA<StoragePermanentException>());
      },
    );

    // Verifies: REQ-d00143-E — bare ArgumentError classifies as permanent.
    test(
      'REQ-d00143-E: ArgumentError classifies as StoragePermanentException',
      () {
        final stack = StackTrace.current;
        final error = ArgumentError('bad store name');
        final result = classifyStorageException(error, stack);
        expect(result, isA<StoragePermanentException>());
      },
    );

    // Verifies: REQ-d00143-F — unrecognized input classifies conservatively
    // as StoragePermanentException (NEVER transient).
    test(
      'REQ-d00143-F: unrecognized Object classifies as StoragePermanentException',
      () {
        final stack = StackTrace.current;
        final result = classifyStorageException(Object(), stack);
        expect(result, isA<StoragePermanentException>());
        // Crucially NOT transient — a retry loop on unknown errors is worse
        // than failing loudly.
        expect(result, isNot(isA<StorageTransientException>()));
      },
    );

    // Verifies: REQ-d00143-F — a bare `Exception('...')` is unrecognized and
    // classifies as StoragePermanentException.
    test(
      'REQ-d00143-F: bare Exception(...) classifies as StoragePermanentException',
      () {
        final stack = StackTrace.current;
        final error = Exception('unexpected backend error');
        final result = classifyStorageException(error, stack);
        expect(result, isA<StoragePermanentException>());
      },
    );

    // Verifies: REQ-d00143-E — sembast DatabaseException.errDatabaseClosed
    // classifies as StoragePermanentException (lifecycle error, not
    // data-integrity).
    test(
      'REQ-d00143-E: sembast DatabaseException.closed classifies as permanent',
      () {
        final stack = StackTrace.current;
        final error = DatabaseException.closed();
        final result = classifyStorageException(error, stack);
        expect(result, isA<StoragePermanentException>());
      },
    );

    // Verifies: REQ-d00143-D — sembast DatabaseException.errInvalidCodec
    // classifies as StorageCorruptException. At this layer we cannot tell
    // "wrong codec configured" from "bytes damaged on disk"; the two are
    // caller-visible indistinguishable, so classify as corrupt.
    test(
      'REQ-d00143-D: sembast DatabaseException.invalidCodec classifies as corrupt',
      () {
        final stack = StackTrace.current;
        final error = DatabaseException.invalidCodec('codec mismatch');
        final result = classifyStorageException(error, stack);
        expect(result, isA<StorageCorruptException>());
      },
    );

    // Verifies: REQ-d00143-F — dart:core Error-hierarchy types (not
    // Exception subtypes) fall to the wildcard arm and classify as
    // StoragePermanentException. Covers the gap between the explicitly-
    // matched StateError / ArgumentError and the generic Object() case.
    test(
      'REQ-d00143-F: AssertionError classifies as StoragePermanentException',
      () {
        final stack = StackTrace.current;
        final error = AssertionError('invariant violated');
        final result = classifyStorageException(error, stack);
        expect(result, isA<StoragePermanentException>());
        expect(result, isNot(isA<StorageTransientException>()));
        expect(identical(result.cause, error), isTrue);
      },
    );

    // Verifies: REQ-d00143-G — every classified result preserves the
    // original cause and stackTrace by identity.
    test('REQ-d00143-G: classified result preserves cause and stackTrace', () {
      final stack = StackTrace.current;
      final inputs = <Object>[
        TimeoutException('t'),
        const FormatException('f'),
        const FileSystemException('fs', '/x'),
        StateError('s'),
        ArgumentError('a'),
        DatabaseException.closed(),
        Exception('bare'),
        Object(),
      ];
      for (final input in inputs) {
        final result = classifyStorageException(input, stack);
        expect(
          identical(result.cause, input),
          isTrue,
          reason: 'cause not preserved for ${input.runtimeType}',
        );
        expect(
          identical(result.stackTrace, stack),
          isTrue,
          reason: 'stackTrace not preserved for ${input.runtimeType}',
        );
      }
    });
  });
}
