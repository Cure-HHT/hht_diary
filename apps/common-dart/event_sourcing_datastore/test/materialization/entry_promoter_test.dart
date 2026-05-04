import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('REQ-d00140-G: identityPromoter', () {
    test('returns input data unchanged', () {
      // Verifies: REQ-d00140-G — identity helper returns input verbatim.
      final input = <String, Object?>{
        'answers': <String, Object?>{'a': 1},
      };
      final out = identityPromoter(
        entryType: 'demo_note',
        fromVersion: 3,
        toVersion: 5,
        data: input,
      );
      expect(out, same(input));
    });

    test('returns input even when from == to', () {
      // Verifies: REQ-d00140-G — identity helper is invoked even when
      //   fromVersion == toVersion (lib invokes promoter unconditionally).
      final input = <String, Object?>{'answers': <String, Object?>{}};
      final out = identityPromoter(
        entryType: 'x',
        fromVersion: 1,
        toVersion: 1,
        data: input,
      );
      expect(out, same(input));
    });
  });

  group('REQ-d00140-G: EntryPromoter typedef', () {
    test('user can write a custom promoter conforming to the typedef', () {
      // Verifies: REQ-d00140-G — typedef is the public contract for
      //   caller-supplied promoter callbacks. Binding _renamingPromoter to
      //   an `EntryPromoter` variable would fail to compile if the typedef
      //   signature ever drifted from the function's signature.
      // ignore: omit_local_variable_types, prefer_const_declarations
      final EntryPromoter promoter = _renamingPromoter;
      final out = promoter(
        entryType: 'epistaxis',
        fromVersion: 1,
        toVersion: 2,
        data: <String, Object?>{
          'answers': <String, Object?>{'severity': 5},
        },
      );
      expect(out['answers'], <String, Object?>{'severity_score': 5});
    });
  });
}

Map<String, Object?> _renamingPromoter({
  required String entryType,
  required int fromVersion,
  required int toVersion,
  required Map<String, Object?> data,
}) {
  if (fromVersion == 1 && toVersion == 2) {
    final answers = (data['answers'] as Map<String, Object?>?) ?? const {};
    final renamed = {...answers, 'severity_score': answers['severity']}
      ..remove('severity');
    return {...data, 'answers': renamed};
  }
  return data;
}
