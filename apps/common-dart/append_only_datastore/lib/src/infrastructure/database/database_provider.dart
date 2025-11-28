// IMPLEMENTS REQUIREMENTS:
//   REQ-p00006: Offline-First Data Entry
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:append_only_datastore/src/core/config/datastore_config.dart';
import 'package:append_only_datastore/src/core/errors/datastore_exception.dart' as errors;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_web/sembast_web.dart';

/// Provides cross-platform database access using Sembast.
///
/// This provider abstracts the platform-specific database initialization,
/// using sembast_io for native platforms (iOS, Android, desktop) and
/// sembast_web for Flutter web (IndexedDB backend).
///
/// ## Features
///
/// - Cross-platform: Works on iOS, Android, macOS, Windows, Linux, and Web
/// - Offline-first: All data stored locally first
/// - JSON-native: Stores data as JSON, aligning with PostgreSQL JSONB on server
///
/// ## Usage
///
/// ```dart
/// final provider = DatabaseProvider(config: myConfig);
/// await provider.initialize();
///
/// // Access the database
/// final db = provider.database;
///
/// // Close when done
/// await provider.close();
/// ```
class DatabaseProvider {
  DatabaseProvider({required this.config});

  /// Configuration for the datastore.
  final DatastoreConfig config;

  /// The Sembast database instance.
  Database? _database;

  /// Whether the database has been initialized.
  bool get isInitialized => _database != null;

  /// Get the initialized database.
  ///
  /// Throws [StateError] if not initialized.
  Database get database {
    if (_database == null) {
      throw StateError(
        'Database not initialized. Call DatabaseProvider.initialize() first.',
      );
    }
    return _database!;
  }

  /// Initialize the database.
  ///
  /// This opens or creates the database file. On web, it uses IndexedDB.
  /// On native platforms, it creates a file in the application documents directory.
  ///
  /// Throws [DatabaseException] if initialization fails.
  Future<void> initialize() async {
    if (_database != null) {
      return; // Already initialized
    }

    try {
      final factory = _getDatabaseFactory();
      final path = await _getDatabasePath();

      _database = await factory.openDatabase(path);
    } catch (e, stackTrace) {
      throw errors.DatabaseException(
        'Failed to initialize database: $e',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Close the database connection.
  ///
  /// This should be called when the app is shutting down or when
  /// switching users.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Get the appropriate database factory for the current platform.
  DatabaseFactory _getDatabaseFactory() {
    if (kIsWeb) {
      return databaseFactoryWeb;
    }
    return databaseFactoryIo;
  }

  /// Get the database path for the current platform.
  Future<String> _getDatabasePath() async {
    if (kIsWeb) {
      // On web, sembast_web uses the database name as the IndexedDB name
      return config.databaseName;
    }

    // On native platforms, use the configured path or default to documents
    if (config.databasePath != null) {
      return p.join(config.databasePath!, config.databaseName);
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    return p.join(appDocDir.path, config.databaseName);
  }

  /// Delete the database.
  ///
  /// This permanently removes all data. Use with caution.
  /// Primarily intended for testing.
  Future<void> deleteDatabase() async {
    await close();

    try {
      final factory = _getDatabaseFactory();
      final path = await _getDatabasePath();
      await factory.deleteDatabase(path);
    } catch (e, stackTrace) {
      throw errors.DatabaseException(
        'Failed to delete database: $e',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }
}
