import 'dart:async';

import 'package:append_only_datastore/src/core/config/datastore_config.dart';
import 'package:append_only_datastore/src/infrastructure/database/database_provider.dart';
import 'package:append_only_datastore/src/infrastructure/repositories/event_repository.dart';
import 'package:signals/signals.dart';

/// Service locator for the append-only datastore.
///
/// This provides a simple singleton pattern for accessing datastore services.
/// Uses Sembast for cross-platform local storage (including Flutter web).
///
/// ## Usage
///
/// ```dart
/// // Initialize once at app startup
/// await Datastore.initialize(
///   config: DatastoreConfig.development(
///     deviceId: 'device-123',
///     userId: 'user-456',
///   ),
/// );
///
/// // Access anywhere in your app
/// await Datastore.instance.repository.append(
///   aggregateId: 'entry-123',
///   eventType: 'NosebleedRecorded',
///   data: {'severity': 'mild'},
///   userId: 'user-456',
///   deviceId: 'device-123',
/// );
///
/// // Query events
/// final events = await Datastore.instance.repository.getAllEvents();
/// ```
///
/// ## Testing
///
/// ```dart
/// setUp(() async {
///   await Datastore.initialize(config: testConfig);
/// });
///
/// tearDown(() async {
///   await Datastore.instance.reset();
/// });
/// ```
class Datastore {
  /// Private constructor.
  Datastore._({
    required this.config,
    required this.databaseProvider,
    required this.repository,
  })  : syncStatus = signal(SyncStatus.idle),
        queueDepth = signal(0),
        lastSyncTime = signal(null);

  static Datastore? _instance;

  /// Get the initialized datastore instance.
  ///
  /// Throws [StateError] if not initialized. Call [initialize] first.
  static Datastore get instance {
    if (_instance == null) {
      throw StateError(
        'Datastore not initialized. Call Datastore.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Check if datastore is initialized.
  static bool get isInitialized => _instance != null;

  /// Configuration used to initialize the datastore.
  final DatastoreConfig config;

  /// The database provider for low-level database access.
  final DatabaseProvider databaseProvider;

  /// The event repository for append-only event storage.
  final EventRepository repository;

  // TODO: Add additional services as they're implemented
  // final OfflineQueueManager queue;
  // final SyncService syncService;
  // final QueryService queryService;
  // final ConflictResolver conflictResolver;

  /// Reactive signals for UI state.
  final Signal<SyncStatus> syncStatus;
  final Signal<int> queueDepth;
  final Signal<DateTime?> lastSyncTime;

  /// Initialize the datastore with the given configuration.
  ///
  /// This must be called once at app startup before using any datastore
  /// functionality. Calling this multiple times will reinitialize the
  /// datastore with the new configuration.
  ///
  /// Example:
  /// ```dart
  /// await Datastore.initialize(
  ///   config: DatastoreConfig.production(
  ///     deviceId: await getDeviceId(),
  ///     userId: currentUser.id,
  ///     syncServerUrl: 'https://api.example.com',
  ///     encryptionKey: await getSecureKey(),
  ///   ),
  /// );
  /// ```
  static Future<Datastore> initialize({required DatastoreConfig config}) async {
    // Reset existing instance if present
    if (_instance != null) {
      await _instance!.reset();
    }

    // Create and initialize database provider
    final databaseProvider = DatabaseProvider(config: config);
    await databaseProvider.initialize();

    // Create event repository
    final repository = EventRepository(databaseProvider: databaseProvider);

    _instance = Datastore._(
      config: config,
      databaseProvider: databaseProvider,
      repository: repository,
    );

    // Update queue depth signal (fire and forget)
    unawaited(_instance!._updateQueueDepth());

    return _instance!;
  }

  /// Update the queue depth signal from the repository.
  Future<void> _updateQueueDepth() async {
    try {
      queueDepth.value = await repository.getUnsyncedCount();
    } catch (_) {
      // Ignore errors during signal update
    }
  }

  /// Reset the datastore, closing all connections and clearing state.
  ///
  /// This should be called:
  /// - Between unit tests
  /// - When switching users
  /// - Before re-initializing with different config
  Future<void> reset() async {
    // Close database connection
    await databaseProvider.close();

    // Reset signals
    syncStatus.value = SyncStatus.idle;
    queueDepth.value = 0;
    lastSyncTime.value = null;

    _instance = null;
  }

  /// Delete the database and reset. Use with caution.
  ///
  /// This permanently removes all local data.
  /// Primarily intended for testing.
  Future<void> deleteAndReset() async {
    await databaseProvider.deleteDatabase();

    // Reset signals
    syncStatus.value = SyncStatus.idle;
    queueDepth.value = 0;
    lastSyncTime.value = null;

    _instance = null;
  }
}

/// Sync status enum for reactive state.
enum SyncStatus {
  /// No sync operation in progress.
  idle,

  /// Sync operation in progress.
  syncing,

  /// Last sync completed successfully.
  synced,

  /// Last sync failed with error.
  error,
}

extension SyncStatusExtensions on SyncStatus {
  /// Human-readable status message.
  String get message {
    return switch (this) {
      SyncStatus.idle => 'Ready to sync',
      SyncStatus.syncing => 'Syncing...',
      SyncStatus.synced => 'All changes synced',
      SyncStatus.error => 'Sync failed',
    };
  }

  /// Whether sync is currently active.
  bool get isActive => this == SyncStatus.syncing;

  /// Whether last sync had an error.
  bool get hasError => this == SyncStatus.error;
}
