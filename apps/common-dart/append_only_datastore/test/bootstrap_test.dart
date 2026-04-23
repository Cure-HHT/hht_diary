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

const Source _source = Source(
  hopId: 'mobile-device',
  identifier: 'd',
  softwareVersion: 'v',
);

EntryTypeDefinition _defn(String id) => EntryTypeDefinition(
  id: id,
  version: '1',
  name: id,
  widgetId: 'widget-$id',
  widgetConfig: const <String, Object?>{},
);

/// Destination that throws on the first read of [id]. Used to abort the
/// destination loop at a deterministic point.
class _ThrowOnIdAccess extends FakeDestination {
  _ThrowOnIdAccess() : super(id: 'unused', script: const []);

  @override
  String get id => throw StateError('id getter intentionally throws');
}

void main() {
  group('bootstrapAppendOnlyDatastore', () {
    test(
      'REQ-d00134-A: returns AppendOnlyDatastore facade carrying eventStore, '
      'entryTypes, destinations, securityContexts',
      () async {
        final backend = await _openBackend();
        final ds = await bootstrapAppendOnlyDatastore(
          backend: backend,
          source: _source,
          entryTypes: [_defn('demo_note')],
          destinations: const <Destination>[],
        );
        expect(ds.eventStore, isA<EventStore>());
        expect(ds.entryTypes, isA<EntryTypeRegistry>());
        expect(ds.destinations, isA<DestinationRegistry>());
        expect(ds.securityContexts, isA<SecurityContextStore>());
        expect(ds.entryTypes.isRegistered('demo_note'), isTrue);
      },
    );

    test('REQ-d00134-B: auto-registers 3 reserved system entry types BEFORE '
        'caller-supplied list', () async {
      final backend = await _openBackend();
      final ds = await bootstrapAppendOnlyDatastore(
        backend: backend,
        source: _source,
        entryTypes: [_defn('demo_note')],
        destinations: const <Destination>[],
      );
      expect(ds.entryTypes.isRegistered('security_context_redacted'), isTrue);
      expect(ds.entryTypes.isRegistered('security_context_compacted'), isTrue);
      expect(ds.entryTypes.isRegistered('security_context_purged'), isTrue);
    });

    test('REQ-d00134-D: caller-supplied id colliding with reserved id throws '
        'ArgumentError with "reserved" message', () async {
      final backend = await _openBackend();
      await expectLater(
        bootstrapAppendOnlyDatastore(
          backend: backend,
          source: _source,
          entryTypes: [_defn('security_context_redacted')],
          destinations: const <Destination>[],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('reserved'),
          ),
        ),
      );
    });

    test('REQ-d00134-A+C: wires entry types and destinations; registry stays '
        'open', () async {
      final backend = await _openBackend();
      final types = [_defn('demo_note'), _defn('red_button')];
      final dests = [
        FakeDestination(id: 'primary', script: const []),
        FakeDestination(id: 'analytics', script: const []),
      ];

      final ds = await bootstrapAppendOnlyDatastore(
        backend: backend,
        source: _source,
        entryTypes: types,
        destinations: dests,
      );

      // 2 caller-supplied + 3 system = 5 total
      expect(ds.entryTypes.all(), hasLength(5));
      expect(ds.entryTypes.isRegistered('demo_note'), isTrue);
      expect(ds.entryTypes.isRegistered('red_button'), isTrue);
      expect(ds.destinations.all(), hasLength(2));
      expect(ds.destinations.byId('primary'), same(dests[0]));
      expect(ds.destinations.byId('analytics'), same(dests[1]));
      expect(await backend.readSchedule('primary'), isA<DestinationSchedule>());

      // Registry remains open to subsequent runtime addDestination calls.
      await ds.destinations.addDestination(
        FakeDestination(id: 'late', script: const []),
      );
      expect(ds.destinations.all(), hasLength(3));
    });

    test('REQ-d00134-B: type-loop runs first — duplicate type id throws '
        'before any destination is registered', () async {
      final backend = await _openBackend();
      final types = [_defn('dup'), _defn('dup')];
      final dests = [FakeDestination(id: 'primary', script: const [])];

      await expectLater(
        bootstrapAppendOnlyDatastore(
          backend: backend,
          source: _source,
          entryTypes: types,
          destinations: dests,
        ),
        throwsArgumentError,
      );
      expect(await backend.readSchedule('primary'), isNull);
    });

    test('REQ-d00134-B: when the destination loop throws, supplied types were '
        'registered first (ordering proof)', () async {
      final backend = await _openBackend();
      final types = [_defn('demo_note'), _defn('red_button')];
      final dests = <Destination>[_ThrowOnIdAccess()];

      await expectLater(
        bootstrapAppendOnlyDatastore(
          backend: backend,
          source: _source,
          entryTypes: types,
          destinations: dests,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await backend.readSchedule('unused'), isNull);

      final ds = await bootstrapAppendOnlyDatastore(
        backend: backend,
        source: _source,
        entryTypes: types,
        destinations: const <Destination>[],
      );
      expect(ds.entryTypes.isRegistered('demo_note'), isTrue);
      expect(ds.entryTypes.isRegistered('red_button'), isTrue);
    });

    test('REQ-d00134-D: duplicate destination id throws', () async {
      final backend = await _openBackend();
      final dests = [
        FakeDestination(id: 'x', script: const []),
        FakeDestination(id: 'x', script: const []),
      ];

      await expectLater(
        bootstrapAppendOnlyDatastore(
          backend: backend,
          source: _source,
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
            source: _source,
            entryTypes: const [],
            destinations: dests,
          ),
          throwsArgumentError,
        );
        expect(await backend.readSchedule('first'), isNotNull);
        expect(await backend.readSchedule('second'), isNotNull);
      },
    );
  });
}
