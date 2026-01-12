// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-p00013: GDPR compliance - EU-only regions
//   REQ-d00032: Role-Based Access Control Implementation
//   REQ-p00005: Role-Based Access Control
//
// Database connection pool for PostgreSQL
// Supports RLS session context for role-based access control

import 'dart:io';

import 'package:postgres/postgres.dart';

/// User context for RLS enforcement
///
/// This context is set as PostgreSQL session variables before queries,
/// enabling row-level security policies to access user identity and role.
///
/// Two levels of roles:
/// 1. PostgreSQL role (pgRole): 'authenticated' or 'service_role' - controls RLS policy selection
/// 2. Application role (role): 'Administrator', 'Investigator', etc. - used by RLS policy conditions
class UserContext {
  /// PostgreSQL role for RLS ('authenticated' or 'service_role')
  final String pgRole;

  /// User's Identity Platform UID (firebase_uid)
  final String userId;

  /// Application role (e.g., 'Administrator', 'Investigator')
  final String role;

  /// All roles the user is allowed to assume
  final List<String> allowedRoles;

  const UserContext({
    required this.pgRole,
    required this.userId,
    required this.role,
    required this.allowedRoles,
  });

  /// Create authenticated user context
  factory UserContext.authenticated({
    required String userId,
    required String role,
    List<String>? allowedRoles,
  }) {
    return UserContext(
      pgRole: 'authenticated',
      userId: userId,
      role: role,
      allowedRoles: allowedRoles ?? [role],
    );
  }

  /// Service context for privileged operations (firebase_uid linking, migrations)
  static const UserContext service = UserContext(
    pgRole: 'service_role',
    userId: 'service',
    role: 'service_role',
    allowedRoles: ['service_role'],
  );
}

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

  /// Execute a query with the pool (no RLS context - use for service operations)
  Future<Result> execute(
    String query, {
    Map<String, dynamic>? parameters,
  }) async {
    if (_pool == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _pool!.execute(Sql.named(query), parameters: parameters);
  }

  /// Execute a query with user context for RLS enforcement
  ///
  /// Sets both PostgreSQL role and session variables:
  /// - SET ROLE: 'authenticated' or 'service_role' for RLS policy selection
  /// - app.user_id: Current user's ID (firebase_uid)
  /// - app.role: Current active application role
  /// - app.allowed_roles: Comma-separated list of user's allowed roles
  ///
  /// This enables RLS policies to use current_user_id(), current_user_role(),
  /// and current_user_allowed_roles() functions.
  Future<Result> executeWithContext(
    String query, {
    Map<String, dynamic>? parameters,
    required UserContext context,
  }) async {
    if (_pool == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    // Use pool.runTx to get a transaction - SET LOCAL only works in transactions
    return _pool!.runTx((connection) async {
      // Set PostgreSQL role for RLS policy selection
      // Note: SET LOCAL ROLE resets at end of transaction
      // Role name is safe to interpolate since it's from our controlled enum
      await connection.execute(Sql("SET LOCAL ROLE ${context.pgRole}"));

      // Set session variables for RLS policy conditions
      // Use set_config with true (local) since we're in a transaction
      await connection.execute(
        Sql("SELECT set_config('app.user_id', \$1, true)"),
        parameters: [context.userId],
      );
      await connection.execute(
        Sql("SELECT set_config('app.role', \$1, true)"),
        parameters: [context.role],
      );
      await connection.execute(
        Sql("SELECT set_config('app.allowed_roles', \$1, true)"),
        parameters: [context.allowedRoles.join(',')],
      );

      // Execute the actual query with RLS context set
      return connection.execute(Sql.named(query), parameters: parameters);
    });
  }

  /// Execute a transaction with user context for RLS enforcement
  ///
  /// All queries within the transaction run with the same user context.
  /// Sets both PostgreSQL role and application context variables.
  Future<T> runTransactionWithContext<T>(
    Future<T> Function(Session session) transaction, {
    required UserContext context,
  }) async {
    if (_pool == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }

    // Use runTx for transaction context - SET LOCAL requires transaction
    return _pool!.runTx((session) async {
      // Set PostgreSQL role for RLS policy selection
      // Role name is safe to interpolate since it's from our controlled enum
      await session.execute(Sql("SET LOCAL ROLE ${context.pgRole}"));

      // Set session variables for RLS policy conditions
      // Use set_config with true (local) since we're in a transaction
      await session.execute(
        Sql("SELECT set_config('app.user_id', \$1, true)"),
        parameters: [context.userId],
      );
      await session.execute(
        Sql("SELECT set_config('app.role', \$1, true)"),
        parameters: [context.role],
      );
      await session.execute(
        Sql("SELECT set_config('app.allowed_roles', \$1, true)"),
        parameters: [context.allowedRoles.join(',')],
      );

      // Execute the transaction
      return transaction(session);
    });
  }

  /// Close the connection pool
  Future<void> close() async {
    await _pool?.close();
    _pool = null;
  }
}
