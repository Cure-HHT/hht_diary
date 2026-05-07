// In-memory EventStore bootstrap helper shared across actions test files.
//
// Uses flutter_test (not package:test) because EventStore depends on
// Sembast, which requires the Flutter test binding to run in this package.
// All tests that call bootstrapTestEventStore() must also use flutter_test.

import 'package:event_sourcing/event_sourcing.dart';
import 'package:sembast/sembast_memory.dart';

/// Builds a fully-wired in-memory [EventStore] suitable for actions tests.
///
/// Registers all reserved system entry types plus the two test-specific
/// entry types (`action_denial` and `greeting`) that `HelloAction` and
/// `MultiEventAction` emit. Returns a fresh instance on every call so
/// tests are isolated.
Future<EventStore> bootstrapTestEventStore() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'dispatcher-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final backend = SembastBackend(database: db);
  final registry = EntryTypeRegistry();

  // Register every reserved system entry type (security-context lifecycle,
  // destination-mutation audits, retention sweep, registry-initialized audit).
  for (final defn in kSystemEntryTypes) {
    registry.register(defn);
  }

  // Register test-specific entry types. materialize: false — these are
  // audit records and test fixtures, not diary entries.
  registry
    ..register(
      const EntryTypeDefinition(
        id: 'action_denial',
        registeredVersion: 1,
        name: 'Action denial',
        widgetId: 'action_denial_v1',
        widgetConfig: <String, Object?>{},
        materialize: false,
      ),
    )
    // greeting is emitted by HelloAction and MultiEventAction.
    ..register(
      const EntryTypeDefinition(
        id: 'greeting',
        registeredVersion: 1,
        name: 'Greeting',
        widgetId: 'greeting_v1',
        widgetConfig: <String, Object?>{},
        materialize: false,
      ),
    );

  final securityContexts = SembastSecurityContextStore(backend: backend);

  return EventStore(
    backend: backend,
    entryTypes: registry,
    source: const Source(
      hopId: 'test-server',
      identifier: 'test-instance-1',
      softwareVersion: 'event_sourcing_test@0.0.0',
    ),
    securityContexts: securityContexts,
    materializers: const [],
  );
}
