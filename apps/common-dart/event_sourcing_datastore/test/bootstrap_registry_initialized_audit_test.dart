// Verifies the bootstrap-time `system.entry_type_registry_initialized`
// audit event:
//
// - Fresh bootstrap emits exactly one event whose data.registry maps every
//   registered entry-type id to its registeredVersion.
// - Same-version reboot (same backend, same caller-supplied entry types)
//   no-ops via dedupeByContent — the second bootstrap finds prior content
//   identical and writes nothing.
// - Schema bumps emit a new audit event:
//     - adding a new caller entry type changes the registry map shape, so
//       dedupe is broken and a new event lands.
//     - bumping registeredVersion on an existing caller entry type changes
//       the map's value for that key, so a new event lands.
//
// Verifies: REQ-d00134-E — bootstrap registry-initialized audit content;
//   aggregateId = source.identifier (the install UUID).
// Verifies: REQ-d00134-F — dedupeByContent semantics across reboots.
// Verifies: REQ-d00134-G — entryTypeVersion read from the registry, not
//   hard-coded; the registry is the source of truth.
// Verifies: REQ-d00154-D — system events use the install UUID as their
//   aggregate.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

const _source = Source(
  hopId: 'mobile-device',
  identifier: 'init-audit-test',
  softwareVersion: 'init-audit-test@1.0.0',
);

EntryTypeDefinition _typeA({int version = 1}) => EntryTypeDefinition(
  id: 'demo_note',
  registeredVersion: version,
  name: 'Demo Note',
  widgetId: 'widget-demo_note',
  widgetConfig: const <String, Object?>{},
);

EntryTypeDefinition _typeB() => const EntryTypeDefinition(
  id: 'red_button',
  registeredVersion: 1,
  name: 'Red Button',
  widgetId: 'widget-red_button',
  widgetConfig: <String, Object?>{},
);

/// Open a `SembastBackend` against a path-keyed in-memory database via
/// [factory]. Reusing the same factory and path simulates a process
/// reboot against the same persisted state — sembast's in-memory
/// factory caches by path within a single factory instance, so a second
/// `openDatabase(path)` call on the same factory returns the database
/// already populated by the first call.
Future<SembastBackend> _openMemoryBackend(
  DatabaseFactory factory,
  String path,
) async {
  final db = await factory.openDatabase(path);
  return SembastBackend(database: db);
}

/// Find every event whose entry_type matches [entryType], in the order
/// returned by `findAllEvents` (ascending sequence_number).
Future<List<StoredEvent>> _eventsOfType(
  SembastBackend backend,
  String entryType,
) async {
  final all = await backend.findAllEvents();
  return all.where((e) => e.entryType == entryType).toList();
}

void main() {
  group('REQ-d00134-E,F,G: bootstrap registry-initialized audit', () {
    test(
      'REQ-d00134-E: fresh bootstrap emits '
      'system.entry_type_registry_initialized with full registry map',
      () async {
        final factory = newDatabaseFactoryMemory();
        final backend = await _openMemoryBackend(factory, 'fresh.db');
        final ds = await bootstrapAppendOnlyDatastore(
          backend: backend,
          source: _source,
          entryTypes: <EntryTypeDefinition>[_typeA(), _typeB()],
          destinations: const <Destination>[],
          materializers: const <Materializer>[],
          initialViewTargetVersions: const <String, Map<String, int>>{},
        );

        final audits = await _eventsOfType(
          backend,
          kEntryTypeRegistryInitializedEntryType,
        );
        expect(audits, hasLength(1));
        final audit = audits.single;
        expect(audit.aggregateId, _source.identifier);
        expect(audit.aggregateType, 'system_registry');
        expect(audit.eventType, 'finalized');

        final registryData = audit.data['registry'];
        expect(registryData, isA<Map<String, Object?>>());
        final registryMap = registryData as Map<String, Object?>;
        // Every system + caller entry type appears with its registered
        // version. The audit event's own entry type is included too —
        // the registry was complete before the append fired.
        for (final defn in ds.entryTypes.all()) {
          expect(
            registryMap[defn.id],
            defn.registeredVersion,
            reason: 'registry map missing or wrong version for ${defn.id}',
          );
        }
        expect(registryMap.length, ds.entryTypes.all().length);

        // REQ-d00134-G: stamp matches the registry's registered version
        // for the audit's own entry type (1, defined in kSystemEntryTypes).
        expect(audit.entryTypeVersion, 1);
        expect(
          audit.initiator,
          const AutomationInitiator(service: 'lib-bootstrap'),
        );
      },
    );

    test('REQ-d00134-F: same-version reboot no-ops via dedupeByContent — '
        'still exactly one audit event', () async {
      // First bootstrap.
      final factory = newDatabaseFactoryMemory();
      const path = 'reboot-same.db';
      final backendA = await _openMemoryBackend(factory, path);
      await bootstrapAppendOnlyDatastore(
        backend: backendA,
        source: _source,
        entryTypes: <EntryTypeDefinition>[_typeA(), _typeB()],
        destinations: const <Destination>[],
        materializers: const <Materializer>[],
        initialViewTargetVersions: const <String, Map<String, int>>{},
      );
      final firstAudits = await _eventsOfType(
        backendA,
        kEntryTypeRegistryInitializedEntryType,
      );
      expect(firstAudits, hasLength(1));

      // Reboot — re-open the SAME database (same path on the in-memory
      // factory) and bootstrap with the SAME entry-type list.
      // dedupeByContent on the registry-init append sees identical
      // content and returns null without writing.
      final backendB = await _openMemoryBackend(factory, path);
      await bootstrapAppendOnlyDatastore(
        backend: backendB,
        source: _source,
        entryTypes: <EntryTypeDefinition>[_typeA(), _typeB()],
        destinations: const <Destination>[],
        materializers: const <Materializer>[],
        initialViewTargetVersions: const <String, Map<String, int>>{},
      );
      final secondAudits = await _eventsOfType(
        backendB,
        kEntryTypeRegistryInitializedEntryType,
      );
      expect(secondAudits, hasLength(1));
      // The single audit is unchanged — same eventId.
      expect(secondAudits.single.eventId, firstAudits.single.eventId);
    });

    test('REQ-d00134-F: schema bump (new entry type added) emits a new '
        'audit event with the updated registry map', () async {
      final factory = newDatabaseFactoryMemory();
      const path = 'add-type.db';
      final backendA = await _openMemoryBackend(factory, path);
      await bootstrapAppendOnlyDatastore(
        backend: backendA,
        source: _source,
        entryTypes: <EntryTypeDefinition>[_typeA()],
        destinations: const <Destination>[],
        materializers: const <Materializer>[],
        initialViewTargetVersions: const <String, Map<String, int>>{},
      );

      // Reboot with a NEW entry type added — the registry map shape
      // changes, dedupe breaks, a new audit lands.
      final backendB = await _openMemoryBackend(factory, path);
      await bootstrapAppendOnlyDatastore(
        backend: backendB,
        source: _source,
        entryTypes: <EntryTypeDefinition>[_typeA(), _typeB()],
        destinations: const <Destination>[],
        materializers: const <Materializer>[],
        initialViewTargetVersions: const <String, Map<String, int>>{},
      );

      final audits = await _eventsOfType(
        backendB,
        kEntryTypeRegistryInitializedEntryType,
      );
      expect(audits, hasLength(2));
      final later = audits[1];
      final laterRegistry = later.data['registry'] as Map<String, Object?>;
      expect(laterRegistry['demo_note'], 1);
      expect(laterRegistry['red_button'], 1);
    });

    test('REQ-d00134-F: schema bump (registeredVersion bump on existing '
        'caller type) emits a new audit event', () async {
      final factory = newDatabaseFactoryMemory();
      const path = 'bump-version.db';
      final backendA = await _openMemoryBackend(factory, path);
      await bootstrapAppendOnlyDatastore(
        backend: backendA,
        source: _source,
        entryTypes: <EntryTypeDefinition>[_typeA(version: 1)],
        destinations: const <Destination>[],
        materializers: const <Materializer>[],
        initialViewTargetVersions: const <String, Map<String, int>>{},
      );

      // Reboot with the SAME id but a bumped registeredVersion — the
      // map value for demo_note changes from 1 to 2. dedupe breaks;
      // a new audit lands recording the bump.
      final backendB = await _openMemoryBackend(factory, path);
      await bootstrapAppendOnlyDatastore(
        backend: backendB,
        source: _source,
        entryTypes: <EntryTypeDefinition>[_typeA(version: 2)],
        destinations: const <Destination>[],
        materializers: const <Materializer>[],
        initialViewTargetVersions: const <String, Map<String, int>>{},
      );

      final audits = await _eventsOfType(
        backendB,
        kEntryTypeRegistryInitializedEntryType,
      );
      expect(audits, hasLength(2));
      final earlier = audits[0];
      final later = audits[1];
      final earlierMap = earlier.data['registry'] as Map<String, Object?>;
      final laterMap = later.data['registry'] as Map<String, Object?>;
      expect(earlierMap['demo_note'], 1);
      expect(laterMap['demo_note'], 2);
    });
  });
}
