// Test helper: build a `(EventStore, DestinationRegistry)` pair wired to
// a shared `SembastBackend` so registry-mutation tests can satisfy the
// audit-emission contract introduced by REQ-d00129-J+K+L+M+N and
// REQ-d00144-G without going through `bootstrapAppendOnlyDatastore`.
//
// The system entry types (kSystemEntryTypes) are pre-registered on the
// returned `EntryTypeRegistry` so every audit append validates cleanly
// without requiring callers to list them.
import 'package:event_sourcing_datastore/src/entry_type_definition.dart';
import 'package:event_sourcing_datastore/src/entry_type_registry.dart';
import 'package:event_sourcing_datastore/src/event_store.dart';
import 'package:event_sourcing_datastore/src/security/sembast_security_context_store.dart';
import 'package:event_sourcing_datastore/src/security/system_entry_types.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/source.dart';

/// Bundle returned by [buildAuditedRegistryDeps] so each test can grab
/// just the pieces it needs (e.g., `eventStore` for direct asserts on
/// audit events; `entryTypes` for asserting registration; etc.).
class AuditedRegistryDeps {
  AuditedRegistryDeps({
    required this.entryTypes,
    required this.eventStore,
    required this.securityContexts,
  });

  final EntryTypeRegistry entryTypes;
  final EventStore eventStore;
  final SembastSecurityContextStore securityContexts;
}

/// Construct the dependencies a `DestinationRegistry` needs to satisfy
/// its audit-emission contract: an `EntryTypeRegistry` with the system
/// entry types pre-registered, a `SembastSecurityContextStore`, and an
/// `EventStore` wired to all of the above plus [backend].
///
/// [callerEntryTypes] are appended after the system ones — handy for
/// tests that want to append non-system events alongside the audits.
///
/// [auditEntryTypeOverride], when non-null, replaces the default
/// `kSystemEntryTypes` list. Used by atomicity tests that need a
/// truncated set so a specific audit append throws and rolls back the
/// surrounding transaction. Default behavior (override null) is
/// unchanged.
AuditedRegistryDeps buildAuditedRegistryDeps(
  SembastBackend backend, {
  List<EntryTypeDefinition> callerEntryTypes = const <EntryTypeDefinition>[],
  Iterable<EntryTypeDefinition>? auditEntryTypeOverride,
}) {
  final entryTypes = EntryTypeRegistry();
  final auditEntryTypes = auditEntryTypeOverride ?? kSystemEntryTypes;
  for (final defn in auditEntryTypes) {
    entryTypes.register(defn);
  }
  for (final defn in callerEntryTypes) {
    entryTypes.register(defn);
  }
  final securityContexts = SembastSecurityContextStore(backend: backend);
  final eventStore = EventStore(
    backend: backend,
    entryTypes: entryTypes,
    source: const Source(
      hopId: 'mobile-device',
      identifier: 'test-device',
      softwareVersion: 'test@1.0.0',
    ),
    securityContexts: securityContexts,
  );
  return AuditedRegistryDeps(
    entryTypes: entryTypes,
    eventStore: eventStore,
    securityContexts: securityContexts,
  );
}
