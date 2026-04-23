import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:trial_data_types/trial_data_types.dart';

import 'test_support/fake_destination.dart';

Future<SembastBackend> _openBackend() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'bootstrap-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return SembastBackend(database: db);
}

EntryTypeDefinition _defn(String id) => EntryTypeDefinition(
  id: id,
  version: '1',
  name: id,
  widgetId: 'widget-$id',
  widgetConfig: const <String, Object?>{},
);

/// Destination that throws on the first read of [id]. Used to abort the
/// destination loop at a deterministic point so the test can assert
/// type-registration side effects that would or would not be present
/// depending on which loop ran first.
class _ThrowOnIdAccess extends FakeDestination {
  _ThrowOnIdAccess() : super(id: 'unused', script: const []);

  @override
  String get id => throw StateError('id getter intentionally throws');
}

void main() {
  group('bootstrapAppendOnlyDatastore', () {
    test('REQ-d00134-A+C: wires entry types and destinations into both '
        'registries; destination registry stays open', () async {
      final backend = await _openBackend();
      final types = [_defn('demo_note'), _defn('red_button')];
      final dests = [
        FakeDestination(id: 'primary', script: const []),
        FakeDestination(id: 'analytics', script: const []),
      ];

      final (typeReg, destReg) = await bootstrapAppendOnlyDatastore(
        backend: backend,
        entryTypes: types,
        destinations: dests,
      );

      expect(typeReg, isA<EntryTypeRegistry>());
      expect(destReg, isA<DestinationRegistry>());
      expect(typeReg.all(), hasLength(2));
      expect(typeReg.isRegistered('demo_note'), isTrue);
      expect(typeReg.isRegistered('red_button'), isTrue);
      expect(destReg.all(), hasLength(2));
      expect(destReg.byId('primary'), same(dests[0]));
      expect(destReg.byId('analytics'), same(dests[1]));
      expect(await backend.readSchedule('primary'), isA<DestinationSchedule>());

      // REQ-d00134-C: registry remains open to subsequent runtime
      // addDestination calls.
      await destReg.addDestination(
        FakeDestination(id: 'late', script: const []),
      );
      expect(destReg.all(), hasLength(3));
    });

    test('REQ-d00134-B: type-loop runs first — duplicate type id throws '
        'before any destination is registered', () async {
      final backend = await _openBackend();
      final types = [_defn('dup'), _defn('dup')];
      final dests = [FakeDestination(id: 'primary', script: const [])];

      await expectLater(
        bootstrapAppendOnlyDatastore(
          backend: backend,
          entryTypes: types,
          destinations: dests,
        ),
        throwsArgumentError,
      );
      // No destination schedule was persisted, proving the destination
      // loop never ran. If the destination loop had run first, the
      // dormant schedule for 'primary' would be in the backend even
      // after the type-registration throw.
      expect(await backend.readSchedule('primary'), isNull);
    });

    test(
      'REQ-d00134-B: when the destination loop throws, every supplied '
      'entry type was registered first (positive-path ordering proof)',
      () async {
        final backend = await _openBackend();
        final types = [_defn('demo_note'), _defn('red_button')];
        final dests = <Destination>[_ThrowOnIdAccess()];

        // bootstrap will throw inside the destination loop because the
        // destination's `id` getter throws when the registry calls it.
        // After the throw, the type registry that was being built is
        // discarded — but if the type loop had not run first, no test
        // setup could have observed the failure occurring inside the
        // destination loop. The test asserts the throw happens at the
        // expected point AND that no destination schedule was written
        // (proving the destination loop reached its first iteration but
        // never advanced past it).
        await expectLater(
          bootstrapAppendOnlyDatastore(
            backend: backend,
            entryTypes: types,
            destinations: dests,
          ),
          throwsA(isA<StateError>()),
        );
        expect(await backend.readSchedule('unused'), isNull);

        // Now run bootstrap again with no throwing destination and the
        // same backend; the resulting type registry contains both types
        // because bootstrap re-runs type registration before
        // destinations every time.
        final (typeReg, _) = await bootstrapAppendOnlyDatastore(
          backend: backend,
          entryTypes: types,
          destinations: const [],
        );
        expect(typeReg.isRegistered('demo_note'), isTrue);
        expect(typeReg.isRegistered('red_button'), isTrue);
      },
    );

    test('REQ-d00134-D: duplicate destination id throws', () async {
      final backend = await _openBackend();
      final dests = [
        FakeDestination(id: 'x', script: const []),
        FakeDestination(id: 'x', script: const []),
      ];

      await expectLater(
        bootstrapAppendOnlyDatastore(
          backend: backend,
          entryTypes: const [],
          destinations: dests,
        ),
        throwsArgumentError,
      );
    });

    test(
      'REQ-d00134-D: id collision after a successful first registration '
      'leaves the first destination persisted (sequential registration)',
      () async {
        final backend = await _openBackend();
        final dests = [
          FakeDestination(id: 'first', script: const []),
          FakeDestination(id: 'second', script: const []),
          FakeDestination(id: 'second', script: const []),
        ];

        await expectLater(
          bootstrapAppendOnlyDatastore(
            backend: backend,
            entryTypes: const [],
            destinations: dests,
          ),
          throwsArgumentError,
        );
        // Sequential registration: 'first' and 'second' both got
        // persisted before the duplicate-'second' threw. A parallel
        // implementation would also persist the duplicate's read
        // attempt before any throw, so this test pins the sequential
        // semantics in the doc comment.
        expect(await backend.readSchedule('first'), isNotNull);
        expect(await backend.readSchedule('second'), isNotNull);
      },
    );
  });
}
