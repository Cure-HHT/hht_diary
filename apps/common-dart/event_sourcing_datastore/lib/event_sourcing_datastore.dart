/// Append-only datastore for FDA 21 CFR Part 11 compliant event sourcing.
///
/// This library provides offline-first event storage with automatic
/// synchronization, conflict resolution, and audit trail support.
///
/// ## Features
///
/// - ✅ Sembast-based append-only event storage (cross-platform including web)
/// - ✅ Offline queue with automatic sync
/// - ✅ Conflict detection using version vectors
/// - ✅ FDA 21 CFR Part 11 compliance (immutable audit trail)
/// - ✅ Cryptographic hash chain for tamper detection
/// - ✅ OpenTelemetry integration
/// - ✅ Reactive state with Signals
///
/// ## Quick Start
///
/// ```dart
/// import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
///
/// // Initialize the datastore
/// await Datastore.initialize(
///   config: DatastoreConfig.development(
///     deviceId: 'device-123',
///     userId: 'user-456',
///   ),
/// );
///
/// // Append an event
/// final event = await Datastore.instance.repository.append(
///   aggregateId: 'diary-entry-123',
///   eventType: 'NosebleedRecorded',
///   data: {'severity': 'mild', 'duration': 10},
///   userId: 'user-456',
///   deviceId: 'device-789',
/// );
///
/// // Query events
/// final events = await Datastore.instance.repository.getAllEvents();
///
/// // Get unsynced events for sync
/// final unsynced = await Datastore.instance.repository.getUnsyncedEvents();
///
/// // Watch sync status in UI
/// Watch((context) {
///   final depth = Datastore.instance.queueDepth.value;
///   return Text('$depth events pending sync');
/// });
/// ```
///
/// ## Architecture
///
/// The datastore follows a three-layer architecture:
///
/// 1. **Domain Layer** (this package — value types)
///    - Event definitions
///    - Domain entities
///    - Value objects
///
/// 2. **Infrastructure Layer** (this package)
///    - Sembast storage (cross-platform: iOS, Android, Web, Desktop)
///    - Event repository with append-only semantics
///    - Sync engine
///
/// 3. **Application Layer** (clinical_diary app)
///    - Commands and queries
///    - Business logic
///    - UI presentation
///
/// ## Platform Support
///
/// - iOS (sembast_io)
/// - Android (sembast_io)
/// - macOS (sembast_io)
/// - Windows (sembast_io)
/// - Linux (sembast_io)
/// - Web (sembast_web with IndexedDB)
///
/// ## FDA Compliance
///
/// This datastore implements FDA 21 CFR Part 11 requirements:
///
/// - §11.10(e): Immutable audit trail (append-only storage)
/// - §11.10(c): Sequence of operations (monotonic sequence numbers)
/// - §11.50: Signature manifestations (SHA-256 hash chain)
/// - §11.10(a): Validation (comprehensive testing)
///
/// ## Implementation Status
///
/// ✅ Configuration and DI setup
/// ✅ Database layer (Sembast cross-platform)
/// ✅ Event storage (append-only with hash chain)
/// ⏳ Offline queue manager
/// ⏳ Conflict detection (version vectors)
/// ⏳ Query service
/// ⏳ Sync engine
///
library;

// bootstrapAppendOnlyDatastore — single entry point for app main() to wire
// the storage backend, EntryTypeRegistry, destinations, security context
// store, and EventStore. Returns an AppendOnlyDatastore facade.
export 'src/bootstrap.dart'
    show AppendOnlyDatastore, bootstrapAppendOnlyDatastore;

// Core configuration
export 'src/core/config/datastore_config.dart';

// Datastore singleton
export 'src/core/di/datastore.dart';

// Exceptions
export 'src/core/errors/datastore_exception.dart';
export 'src/core/errors/sync_exception.dart';

// Destinations — per-destination routing contract (Phase 4, CUR-1154).
// FakeDestination lives in test/test_support/ and is intentionally NOT
// exported.
export 'src/destinations/destination.dart' show Destination;
export 'src/destinations/destination_registry.dart' show DestinationRegistry;
export 'src/destinations/destination_schedule.dart'
    show DestinationSchedule, SetEndDateResult, TombstoneAndRefillResult;
export 'src/destinations/subscription_filter.dart'
    show SubscriptionFilter, SubscriptionPredicate;
export 'src/destinations/wire_payload.dart' show WirePayload;

// Entry Type Registry + EntryService.record — the legacy Phase 4.3 write
// path. Phase 4.4 added EventStore (see `src/event_store.dart`) as the new
// write API; `EntryService.record` remains for back-compat until Phase 5
// cuts clinical_diary over.
export 'src/entry_service.dart' show DeviceInfo, EntryService, SyncCycleTrigger;
export 'src/entry_type_definition.dart' show EntryTypeDefinition;
export 'src/entry_type_registry.dart' show EntryTypeRegistry;
export 'src/event_store.dart'
    show EventStore, EventStoreSyncCycleTrigger, RetentionResult;

// Infrastructure - Database
export 'src/infrastructure/database/database_provider.dart';

// Infrastructure - Repositories
export 'src/infrastructure/repositories/event_repository.dart';

// Materialization layer — pluggable fold contract, concrete materializer
// for diary_entries, entry-type-definition lookup, and the
// disaster-recovery rebuild helpers (CUR-1154).
// MapEntryTypeDefinitionLookup is intentionally NOT exported — it lives
// under test/test_support/ so production code cannot depend on it.
export 'src/materialization/diary_entries_materializer.dart'
    show DiaryEntriesMaterializer;
export 'src/materialization/entry_type_definition_lookup.dart'
    show EntryTypeDefinitionLookup;
export 'src/materialization/materializer.dart' show Materializer;
export 'src/materialization/rebuild.dart'
    show rebuildMaterializedView, rebuildView;

// Operator-recovery primitives (Phase 4.7, CUR-1154).
// tombstoneAndRefill is the sole recovery path for a wedged FIFO head
// under strict-order drain (REQ-d00144).
export 'src/ops/tombstone_and_refill.dart' show tombstoneAndRefill;

// Security module — Phase 4.4 Tasks 11-15: EventSecurityContext value
// type, SecurityDetails caller input, SecurityRetentionPolicy sweeps,
// SecurityContextStore read-only surface, sembast concrete impl, reserved
// system entry types for redaction/compact/purge audit events.
export 'src/security/event_security_context.dart' show EventSecurityContext;
export 'src/security/security_context_store.dart'
    show AuditRow, PagedAudit, SecurityContextStore;
export 'src/security/security_details.dart' show SecurityDetails;
export 'src/security/security_retention_policy.dart'
    show SecurityRetentionPolicy;
export 'src/security/sembast_security_context_store.dart'
    show SembastSecurityContextStore;
export 'src/security/system_entry_types.dart'
    show
        kReservedSystemEntryTypeIds,
        kSecurityContextCompactedEntryType,
        kSecurityContextPurgedEntryType,
        kSecurityContextRedactedEntryType,
        kSystemEntryTypes;

// Storage layer — StorageBackend contract, SembastBackend concrete
// implementation, and the value types that flow through the contract
// (CUR-1154).
export 'src/storage/append_result.dart' show AppendResult;
export 'src/storage/attempt_result.dart' show AttemptResult;
export 'src/storage/diary_entry.dart' show DiaryEntry;
export 'src/storage/fifo_entry.dart' show EventIdRange, FifoEntry;
export 'src/storage/final_status.dart' show FinalStatus;
export 'src/storage/initiator.dart'
    show Initiator, UserInitiator, AutomationInitiator, AnonymousInitiator;
export 'src/storage/sembast_backend.dart' show SembastBackend;
export 'src/storage/send_result.dart'
    show SendResult, SendOk, SendTransient, SendPermanent;
export 'src/storage/source.dart' show Source;
export 'src/storage/storage_backend.dart' show StorageBackend;
export 'src/storage/storage_exception.dart'
    show
        StorageCorruptException,
        StorageException,
        StoragePermanentException,
        StorageTransientException,
        classifyStorageException;
export 'src/storage/stored_event.dart' show StoredEvent;
export 'src/storage/txn.dart' show Txn;
export 'src/storage/wedged_fifo_summary.dart' show WedgedFifoSummary;

// Sync — backoff curve, drain loop, and top-level orchestrator (Phase 4,
// CUR-1154). Phase 5 wires triggers in clinical_diary that route into
// SyncCycle.call().
export 'src/sync/drain.dart' show ClockFn, drain;
export 'src/sync/fill_batch.dart' show fillBatch;
export 'src/sync/sync_cycle.dart' show SyncCycle;
export 'src/sync/sync_policy.dart' show SyncPolicy;

// TODO: Export additional services as implemented
// export 'src/application/services/query_service.dart';
// export 'src/application/services/conflict_resolver.dart';
// export 'src/application/models/version_vector.dart';
