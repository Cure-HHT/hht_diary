/// Append-only datastore for FDA 21 CFR Part 11 compliant event sourcing.
///
/// This library provides offline-first event storage with automatic
/// synchronization, conflict resolution, and audit trail support.
///
/// ## Features
///
/// - ✅ SQLite-based append-only event storage
/// - ✅ Offline queue with automatic sync
/// - ✅ Conflict detection using version vectors
/// - ✅ FDA 21 CFR Part 11 compliance (immutable audit trail)
/// - ✅ OpenTelemetry integration
/// - ✅ Reactive state with Signals
///
/// ## Quick Start
///
/// ```dart
/// import 'package:append_only_datastore/append_only_datastore.dart';
///
/// // Initialize the datastore
/// await Datastore.initialize(
///   config: DatastoreConfig.development(
///     deviceId: 'device-123',
///     userId: 'user-456',
///     encryptionKey: await getSecureKey(), // SQLCipher encryption
///   ),
/// );
///
/// // Append an event (TODO: Phase 1 - Day 6)
/// // await Datastore.instance.repository.append(myEvent);
///
/// // Query events (TODO: Phase 1 - Day 12)
/// // final events = await Datastore.instance.queryService.getEvents();
///
/// // Manual sync (TODO: Phase 1 - Day 14)
/// // await Datastore.instance.syncService.syncNow();
///
/// // Watch sync status in UI
/// // Watch((context) {
/// //   final status = Datastore.instance.syncStatus.value;
/// //   return Text(status.message);
/// // });
/// ```
///
/// ## Architecture
///
/// The datastore follows a three-layer architecture:
///
/// 1. **Domain Layer** (trial_data_types package)
///    - Event definitions
///    - Domain entities
///    - Value objects
///
/// 2. **Infrastructure Layer** (this package)
///    - SQLite storage
///    - Event repository
///    - Sync engine
///
/// 3. **Application Layer** (clinical_diary app)
///    - Commands and queries
///    - Business logic
///    - UI presentation
///
/// ## FDA Compliance
///
/// This datastore implements FDA 21 CFR Part 11 requirements:
///
/// - §11.10(e): Immutable audit trail (database triggers)
/// - §11.10(c): Sequence of operations (sequence numbers)
/// - §11.50: Signature manifestations (cryptographic signatures)
/// - §11.10(a): Validation (comprehensive testing)
///
/// ## Phase 1 MVP Status
///
/// ✅ Configuration and DI setup
/// ⏳ Database layer (Day 4-5)
/// ⏳ Event storage (Day 6-7)
/// ⏳ Offline queue (Day 8-9)
/// ⏳ Conflict detection (Day 10-11)
/// ⏳ Query service (Day 12-13)
/// ⏳ Sync engine (Day 14-15)
///
library;

// Core configuration
export 'src/core/config/datastore_config.dart';

// Datastore Singletonz
export 'src/core/di/datastore.dart';

// Exceptions
export 'src/core/errors/datastore_exception.dart';
export 'src/core/errors/sync_exception.dart';

// TODO: Export infrastructure (Phase 1)
// export 'src/infrastructure/database/database_provider.dart';
// export 'src/infrastructure/repositories/event_repository.dart';
// export 'src/infrastructure/sync/sync_service.dart';

// TODO: Export application services (Phase 1)
// export 'src/application/services/query_service.dart';
// export 'src/application/services/conflict_resolver.dart';
// export 'src/application/models/sync_status.dart';
// export 'src/application/models/version_vector.dart';
