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
/// import 'package:append_only_datastore/append_only_datastore.dart';
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
/// 1. **Domain Layer** (trial_data_types package)
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

// Core configuration
export 'src/core/config/datastore_config.dart';

// Datastore singleton
export 'src/core/di/datastore.dart';

// Exceptions
export 'src/core/errors/datastore_exception.dart';
export 'src/core/errors/sync_exception.dart';

// Infrastructure - Database
export 'src/infrastructure/database/database_provider.dart';

// Infrastructure - Repositories
export 'src/infrastructure/repositories/event_repository.dart';

// TODO: Export additional services as implemented
// export 'src/infrastructure/sync/sync_service.dart';
// export 'src/application/services/query_service.dart';
// export 'src/application/services/conflict_resolver.dart';
// export 'src/application/models/version_vector.dart';
