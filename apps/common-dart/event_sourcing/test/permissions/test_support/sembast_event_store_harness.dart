// test/permissions/test_support/sembast_event_store_harness.dart
// Builds an in-memory Sembast-backed EventStore with the
// RolePermissionGrantsMaterializer registered, the role_permission_grant
// entry type registered (materialize: true), and the initial view
// target version wired. Shared by every permissions-module test that
// needs a real EventStore + StorageBackend.

import 'package:event_sourcing/event_sourcing.dart';
import 'package:sembast/sembast_memory.dart';

const String kRolePermissionGrantEntryType = 'role_permission_grant';
const String kRolePermissionGrantsView = 'role_permission_grants';

/// Build a fresh, isolated in-memory `EventStore` wired with the
/// permissions module's entry type and materializer. Returns the
/// `EventStore` (not the `AppendOnlyDatastore` facade) for ergonomic
/// use in tests.
Future<EventStore> buildInMemoryEventStore() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'permissions-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final backend = SembastBackend(database: db);
  final datastore = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: const Source(
      hopId: 'test-server',
      identifier: 'test-instance-1',
      softwareVersion: 'event_sourcing_test@0.0.0',
    ),
    entryTypes: const <EntryTypeDefinition>[
      EntryTypeDefinition(
        id: kRolePermissionGrantEntryType,
        registeredVersion: 1,
        name: 'Role-permission grant',
        widgetId: 'role_permission_grant_v1',
        widgetConfig: <String, Object?>{},
        materialize: true,
      ),
    ],
    destinations: const <Destination>[],
    materializers: const <Materializer>[RolePermissionGrantsMaterializer()],
    initialViewTargetVersions: const <String, Map<String, int>>{
      kRolePermissionGrantsView: <String, int>{
        kRolePermissionGrantEntryType: 1,
      },
    },
  );
  return datastore.eventStore;
}
