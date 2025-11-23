import 'package:signals/signals.dart';

import 'package:append_only_datastore/src/core/config/datastore_config.dart';

/// Service locator for the append-only datastore.
///
/// This provides a simple singleton pattern for accessing datastore services.
/// No external dependencies required - just pure Dart.
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
/// await Datastore.instance.repository.append(event);
/// final events = await Datastore.instance.queryService.getEvents();
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

  // TODO: Add services as they're implemented
  // final DatabaseProvider database;
  // final EventRepository repository;
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
  static Future<Datastore> initialize({
    required DatastoreConfig config,
  }) async {
    // Reset existing instance if present
    if (_instance != null) {
      await _instance!.reset();
    }

    _instance = Datastore._(config);

    // TODO: Initialize database (Phase 1 - Day 4)
    // await _instance!.database.initialize();

    return _instance!;
  }

  /// Private constructor.
  Datastore._(this.config)
      : syncStatus = signal(SyncStatus.idle),
        queueDepth = signal(0),
        lastSyncTime = signal(null) {
    // TODO: Initialize services (Phase 1)
    // database = DatabaseProvider(config: config);
    // repository = SQLiteEventRepository(database: database);
    // queue = OfflineQueueManager(repository: repository);
    // syncService = SyncService(
    //   queue: queue,
    //   repository: repository,
    //   config: config,
    //   statusSignal: syncStatus,
    // );
    // queryService = QueryService(repository: repository);
    // conflictResolver = ConflictResolver();
  }

  /// Reset the datastore, closing all connections and clearing state.
  ///
  /// This should be called:
  /// - Between unit tests
  /// - When switching users
  /// - Before re-initializing with different config
  Future<void> reset() async {
    // TODO: Close database connection (Phase 1 - Day 4)
    // await database.close();

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
