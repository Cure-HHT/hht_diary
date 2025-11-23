import 'package:get_it/get_it.dart';
import 'package:signals/signals.dart';

import 'package:append_only_datastore/src/core/config/datastore_config.dart';

// Export GetIt instance for use in tests
final getIt = GetIt.instance;

/// Initialize the append-only datastore dependency injection container.
///
/// This must be called before using any datastore functionality.
/// Typically called once during app initialization.
///
/// Example:
/// ```dart
/// await setupDatastoreDI(
///   config: DatastoreConfig.development(
///     deviceId: 'device-123',
///     userId: 'user-456',
///   ),
/// );
/// ```
///
/// For testing, use [resetDatastoreDI] to clean up between tests.
Future<void> setupDatastoreDI({
  required DatastoreConfig config,
}) async {
  // Verify not already initialized
  if (getIt.isRegistered<DatastoreConfig>()) {
    throw StateError(
      'Datastore DI already initialized. Call resetDatastoreDI() first.',
    );
  }

  // Register configuration
  getIt.registerSingleton<DatastoreConfig>(config);

  // TODO: Register database provider (Phase 1 - Day 4)
  // getIt.registerLazySingleton<DatabaseProvider>(
  //   () => DatabaseProvider(config: getIt<DatastoreConfig>()),
  // );

  // TODO: Register repositories (Phase 1 - Day 6)
  // getIt.registerLazySingleton<EventRepository>(
  //   () => SQLiteEventRepository(
  //     database: getIt<DatabaseProvider>(),
  //   ),
  // );

  // TODO: Register offline queue (Phase 1 - Day 8)
  // getIt.registerLazySingleton<OfflineQueueManager>(
  //   () => OfflineQueueManager(
  //     repository: getIt<EventRepository>(),
  //   ),
  // );

  // TODO: Register sync service (Phase 1 - Day 14)
  // getIt.registerLazySingleton<SyncService>(
  //   () => SyncService(
  //     queue: getIt<OfflineQueueManager>(),
  //     repository: getIt<EventRepository>(),
  //     config: getIt<DatastoreConfig>(),
  //   ),
  // );

  // Register reactive signals for UI state
  getIt.registerSingleton<Signal<SyncStatus>>(
    signal(SyncStatus.idle),
    instanceName: 'syncStatus',
  );

  getIt.registerSingleton<Signal<int>>(
    signal(0),
    instanceName: 'queueDepth',
  );

  getIt.registerSingleton<Signal<DateTime?>>(
    signal(null),
    instanceName: 'lastSyncTime',
  );

  // TODO: Initialize database (Phase 1 - Day 4)
  // await getIt<DatabaseProvider>().initialize();
}

/// Reset all datastore dependencies.
///
/// This should be called:
/// - Between unit tests to ensure clean state
/// - When switching users/tenants
/// - Before re-initializing with different config
///
/// Example:
/// ```dart
/// await resetDatastoreDI();
/// await setupDatastoreDI(config: newConfig);
/// ```
Future<void> resetDatastoreDI() async {
  // TODO: Close database connection (Phase 1 - Day 4)
  // if (getIt.isRegistered<DatabaseProvider>()) {
  //   await getIt<DatabaseProvider>().close();
  // }

  // Reset all registrations
  await getIt.reset();
}

/// Check if datastore DI is initialized.
bool isDatastoreInitialized() {
  return getIt.isRegistered<DatastoreConfig>();
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
