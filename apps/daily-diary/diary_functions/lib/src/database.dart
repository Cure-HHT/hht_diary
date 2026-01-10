// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-p00013: GDPR compliance - EU-only regions
//
// Database connection pool for PostgreSQL

import 'dart:io';

import 'package:postgres/postgres.dart';

/// Database connection configuration from environment
class DatabaseConfig {
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final bool useSsl;

  DatabaseConfig({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    this.useSsl = true,
  });

  /// Create config from environment variables
  factory DatabaseConfig.fromEnvironment() {
    return DatabaseConfig(
      host: Platform.environment['DB_HOST'] ?? 'localhost',
      port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
      database: Platform.environment['DB_NAME'] ?? 'hht_diary',
      username: Platform.environment['DB_USER'] ?? 'app_user',
      password: Platform.environment['DB_PASSWORD'] ?? '',
      useSsl: Platform.environment['DB_SSL'] != 'false',
    );
  }
}

/// Database connection pool singleton
class Database {
  static Database? _instance;
  static Pool? _pool;

  Database._();

  static Database get instance {
    _instance ??= Database._();
    return _instance!;
  }

  /// Initialize the connection pool
  Future<void> initialize(DatabaseConfig config) async {
    if (_pool != null) return;

    final endpoint = Endpoint(
      host: config.host,
      port: config.port,
      database: config.database,
      username: config.username,
      password: config.password,
    );

    final settings = PoolSettings(
      maxConnectionCount: 10,
      sslMode: config.useSsl ? SslMode.require : SslMode.disable,
    );

    _pool = Pool.withEndpoints([endpoint], settings: settings);
  }

  /// Execute a query with the pool
  Future<Result> execute(
    String query, {
    Map<String, dynamic>? parameters,
  }) async {
    if (_pool == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _pool!.execute(Sql.named(query), parameters: parameters);
  }

  /// Close the connection pool
  Future<void> close() async {
    await _pool?.close();
    _pool = null;
  }
}
