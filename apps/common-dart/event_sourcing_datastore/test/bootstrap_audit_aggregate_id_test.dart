// Verifies the bootstrap-time `system.entry_type_registry_initialized`
// audit stamps `aggregateId = source.identifier` (the install UUID).
// The bootstrap audit is the first event in every installation's
// per-install hash-chained system aggregate.
//
// Verifies: REQ-d00134-E (revised: aggregateId=source.identifier).
// Verifies: REQ-d00154-D — system events use the install UUID as their
//   aggregate.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

const _installUUID = 'bbbb2222-3333-4444-5555-666677778888';
const _source = Source(
  hopId: 'mobile-device',
  identifier: _installUUID,
  softwareVersion: 'bootstrap-aggid-test@1.0.0',
);

EntryTypeDefinition _typeA() => const EntryTypeDefinition(
  id: 'demo_note',
  registeredVersion: 1,
  name: 'Demo Note',
  widgetId: 'widget-demo_note',
  widgetConfig: <String, Object?>{},
);

void main() {
  group(
    'bootstrap entry_type_registry_initialized aggregateId = source.identifier',
    () {
      // Verifies: REQ-d00134-E (revised) — fresh bootstrap stamps
      // `aggregateId = source.identifier` on the registry-initialized
      // audit event. The installation's own UUID anchors the per-install
      // system aggregate from the very first system event.
      test('REQ-d00134-E: entry_type_registry_initialized audit uses '
          'source.identifier as aggregateId', () async {
        final db = await newDatabaseFactoryMemory().openDatabase(
          'bootstrap-aggid.db',
        );
        final backend = SembastBackend(database: db);
        await bootstrapAppendOnlyDatastore(
          backend: backend,
          source: _source,
          entryTypes: <EntryTypeDefinition>[_typeA()],
          destinations: const <Destination>[],
          materializers: const <Materializer>[],
          initialViewTargetVersions: const <String, Map<String, int>>{},
        );

        final all = await backend.findAllEvents();
        final audits = all
            .where((e) => e.entryType == kEntryTypeRegistryInitializedEntryType)
            .toList();
        expect(audits, hasLength(1));
        final audit = audits.single;
        expect(
          audit.aggregateId,
          _installUUID,
          reason:
              'aggregateId MUST be source.identifier, not a per-registry '
              'constant',
        );
        expect(audit.aggregateType, 'system_registry');
        await backend.close();
      });

      // Verifies: REQ-d00154-D — two distinct installations stamp
      // disjoint aggregateIds on their bootstrap audits, so a downstream
      // observer that bridges audits from both installs can split the
      // streams cleanly.
      test('REQ-d00154-D: two installs produce disjoint bootstrap audit '
          'aggregateIds', () async {
        const sourceA = Source(
          hopId: 'mobile-device',
          identifier: 'install-A-uuid',
          softwareVersion: 'aggid-test@1.0.0',
        );
        const sourceB = Source(
          hopId: 'mobile-device',
          identifier: 'install-B-uuid',
          softwareVersion: 'aggid-test@1.0.0',
        );
        final factory = newDatabaseFactoryMemory();
        final dbA = await factory.openDatabase('install-A.db');
        final backendA = SembastBackend(database: dbA);
        await bootstrapAppendOnlyDatastore(
          backend: backendA,
          source: sourceA,
          entryTypes: <EntryTypeDefinition>[_typeA()],
          destinations: const <Destination>[],
          materializers: const <Materializer>[],
          initialViewTargetVersions: const <String, Map<String, int>>{},
        );
        final dbB = await factory.openDatabase('install-B.db');
        final backendB = SembastBackend(database: dbB);
        await bootstrapAppendOnlyDatastore(
          backend: backendB,
          source: sourceB,
          entryTypes: <EntryTypeDefinition>[_typeA()],
          destinations: const <Destination>[],
          materializers: const <Materializer>[],
          initialViewTargetVersions: const <String, Map<String, int>>{},
        );
        final allA = await backendA.findAllEvents();
        final allB = await backendB.findAllEvents();
        final auditA = allA.firstWhere(
          (e) => e.entryType == kEntryTypeRegistryInitializedEntryType,
        );
        final auditB = allB.firstWhere(
          (e) => e.entryType == kEntryTypeRegistryInitializedEntryType,
        );
        expect(auditA.aggregateId, 'install-A-uuid');
        expect(auditB.aggregateId, 'install-B-uuid');
        expect(auditA.aggregateId, isNot(auditB.aggregateId));
        await backendA.close();
        await backendB.close();
      });
    },
  );
}
