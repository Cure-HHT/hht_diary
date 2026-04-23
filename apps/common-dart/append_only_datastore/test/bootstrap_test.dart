import 'package:append_only_datastore/src/bootstrap.dart';
import 'package:append_only_datastore/src/destinations/destination_registry.dart';
import 'package:append_only_datastore/src/destinations/destination_schedule.dart';
import 'package:append_only_datastore/src/entry_type_registry.dart';
import 'package:append_only_datastore/src/storage/sembast_backend.dart';
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

void main() {
  group('bootstrapAppendOnlyDatastore', () {
    test(
      'REQ-d00134-A+B+C: wires entry types and destinations into both registries',
      () async {
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
        // Destination dormant schedules are persisted.
        expect(
          await backend.readSchedule('primary'),
          isA<DestinationSchedule>(),
        );
      },
    );

    test(
      'REQ-d00134-C: registry remains open to subsequent addDestination calls',
      () async {
        final backend = await _openBackend();
        final (_, destReg) = await bootstrapAppendOnlyDatastore(
          backend: backend,
          entryTypes: const [],
          destinations: [FakeDestination(id: 'primary', script: const [])],
        );

        await destReg.addDestination(
          FakeDestination(id: 'late', script: const []),
        );
        expect(destReg.all(), hasLength(2));
        expect(destReg.byId('late'), isNotNull);
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
      'REQ-d00134-B: types are registered before destinations '
      '(duplicate type id surfaces before any destination is added)',
      () async {
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
        // Destination was never registered because type registration
        // failed first; no schedule was persisted.
        expect(await backend.readSchedule('primary'), isNull);
      },
    );
  });
}
