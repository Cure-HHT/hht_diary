import 'package:append_only_datastore/src/storage/storage_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StorageException', () {
    // Verifies: REQ-d00143-A — sealed pattern matching is exhaustive over
    // the three variants at compile time; the analyzer would flag a missing
    // arm.
    test(
      'REQ-d00143-A: sealed pattern-match is exhaustive over three variants',
      () {
        String describe(StorageException e) => switch (e) {
          StorageTransientException() => 'transient',
          StoragePermanentException() => 'permanent',
          StorageCorruptException() => 'corrupt',
        };

        final cause = StateError('x');
        final stack = StackTrace.current;

        expect(
          describe(StorageTransientException('t', cause, stack)),
          'transient',
        );
        expect(
          describe(StoragePermanentException('p', cause, stack)),
          'permanent',
        );
        expect(describe(StorageCorruptException('c', cause, stack)), 'corrupt');
      },
    );

    // Verifies: REQ-d00143-A — each variant is a subclass of
    // StorageException AND implements dart:core Exception.
    test(
      'REQ-d00143-A: variants extend StorageException and implement Exception',
      () {
        final cause = StateError('x');
        final stack = StackTrace.current;

        expect(
          StorageTransientException('t', cause, stack),
          isA<StorageException>(),
        );
        expect(
          StoragePermanentException('p', cause, stack),
          isA<StorageException>(),
        );
        expect(
          StorageCorruptException('c', cause, stack),
          isA<StorageException>(),
        );

        expect(StorageTransientException('t', cause, stack), isA<Exception>());
        expect(StoragePermanentException('p', cause, stack), isA<Exception>());
        expect(StorageCorruptException('c', cause, stack), isA<Exception>());
      },
    );

    // Verifies: REQ-d00143-G — StorageTransientException preserves the
    // original cause and stackTrace passed to its constructor.
    test(
      'REQ-d00143-G: StorageTransientException preserves cause and stackTrace',
      () {
        final cause = StateError('locked');
        final stack = StackTrace.current;
        final e = StorageTransientException('db is locked', cause, stack);

        expect(e.message, 'db is locked');
        expect(identical(e.cause, cause), isTrue);
        expect(identical(e.stackTrace, stack), isTrue);
      },
    );

    // Verifies: REQ-d00143-G — StoragePermanentException preserves the
    // original cause and stackTrace passed to its constructor.
    test(
      'REQ-d00143-G: StoragePermanentException preserves cause and stackTrace',
      () {
        final cause = ArgumentError('bad path');
        final stack = StackTrace.current;
        final e = StoragePermanentException('bad arg', cause, stack);

        expect(e.message, 'bad arg');
        expect(identical(e.cause, cause), isTrue);
        expect(identical(e.stackTrace, stack), isTrue);
      },
    );

    // Verifies: REQ-d00143-G — StorageCorruptException preserves the
    // original cause and stackTrace passed to its constructor.
    test(
      'REQ-d00143-G: StorageCorruptException preserves cause and stackTrace',
      () {
        const cause = FormatException('bad JSON');
        final stack = StackTrace.current;
        final e = StorageCorruptException('decode failed', cause, stack);

        expect(e.message, 'decode failed');
        expect(identical(e.cause, cause), isTrue);
        expect(identical(e.stackTrace, stack), isTrue);
      },
    );

    test(
      'toString() includes runtimeType, message, and cause for diagnostics',
      () {
        final e = StorageCorruptException(
          'bad event row',
          const FormatException('bad JSON'),
          StackTrace.current,
        );
        final s = e.toString();
        expect(s, contains('StorageCorruptException'));
        expect(s, contains('bad event row'));
        expect(s, contains('FormatException'));
      },
    );
  });
}
