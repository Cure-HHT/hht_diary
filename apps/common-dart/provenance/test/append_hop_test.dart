import 'package:provenance/provenance.dart';
import 'package:test/test.dart';

/// Verifies REQ-d00115-A, REQ-d00115-B.
void main() {
  ProvenanceEntry makeEntry(String hop, {String identifier = 'id'}) =>
      ProvenanceEntry(
        hop: hop,
        receivedAt: DateTime.utc(2026, 4, 21, 10, 0, 0),
        identifier: identifier,
        softwareVersion: 'pkg@1.0.0',
      );

  group('appendHop', () {
    // Verifies: REQ-d00115-A — appending to empty yields a one-entry list.
    test(
      'REQ-d00115-A: appending to an empty chain yields a one-entry list',
      () {
        final entry = makeEntry('mobile-device');
        final result = appendHop(const <ProvenanceEntry>[], entry);

        expect(result, [entry]);
        expect(result.length, 1);
      },
    );

    // Verifies: REQ-d00115-A — length grows by exactly 1.
    test(
      'REQ-d00115-A: appending to a non-empty chain adds exactly one entry',
      () {
        final first = makeEntry('mobile-device');
        final second = makeEntry('diary-server');
        final third = makeEntry('portal-server');

        final start = appendHop(const <ProvenanceEntry>[], first);
        final afterSecond = appendHop(start, second);
        final afterThird = appendHop(afterSecond, third);

        expect(start.length, 1);
        expect(afterSecond.length, 2);
        expect(afterThird.length, 3);
      },
    );

    // Verifies: REQ-d00115-A — the new entry is at the tail.
    test('REQ-d00115-A: the new entry is placed at the tail', () {
      final first = makeEntry('mobile-device');
      final second = makeEntry('diary-server');

      final chain = appendHop(appendHop([], first), second);

      expect(chain.first, first);
      expect(chain.last, second);
    });

    // Verifies: REQ-d00115-B — input chain is not mutated.
    test('REQ-d00115-B: appendHop does not mutate the input chain', () {
      final first = makeEntry('mobile-device');
      final second = makeEntry('diary-server');
      final start = appendHop([], first);
      final before = List<ProvenanceEntry>.of(start);

      appendHop(start, second);

      expect(start, equals(before));
      expect(start.length, 1);
    });

    // Verifies: REQ-d00115-B — returned list is unmodifiable, preventing
    // downstream callers from breaking the invariant.
    test(
      'REQ-d00115-B: returned list rejects mutations (add, remove, replace)',
      () {
        final entry = makeEntry('mobile-device');
        final chain = appendHop([], entry);

        expect(
          () => chain.add(makeEntry('diary-server')),
          throwsUnsupportedError,
        );
        expect(chain.removeLast, throwsUnsupportedError);
        expect(() => chain[0] = makeEntry('replaced'), throwsUnsupportedError);
      },
    );

    // Verifies: REQ-d00115-A — returning a new list, not the same object.
    test('REQ-d00115-A: returns a new List instance, not the input', () {
      final start = <ProvenanceEntry>[];
      final result = appendHop(start, makeEntry('mobile-device'));

      expect(identical(start, result), isFalse);
    });

    // Verifies: REQ-d00115-A — no deduplication; equal entries are still
    // two separate positions in the chain.
    test(
      'REQ-d00115-A: appending an equal entry twice yields two positions',
      () {
        final entry = makeEntry('mobile-device');
        final chain = appendHop(appendHop([], entry), entry);

        expect(chain.length, 2);
        expect(chain[0], entry);
        expect(chain[1], entry);
      },
    );

    // Verifies: REQ-d00115-B — prior entries keep their identity (value
    // equality) across multiple appends.
    test(
      'REQ-d00115-B: prior entries remain equal to their original value across appends',
      () {
        final first = makeEntry('mobile-device', identifier: 'device-abc');
        final originalFirst = first;

        var chain = appendHop([], first);
        chain = appendHop(chain, makeEntry('diary-server'));
        chain = appendHop(chain, makeEntry('portal-server'));

        expect(chain[0], equals(originalFirst));
      },
    );
  });
}
