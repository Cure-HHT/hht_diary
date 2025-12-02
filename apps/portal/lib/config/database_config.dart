// IMPLEMENTS REQUIREMENTS:
//   REQ-d00028: Portal Frontend Framework

// import '../services/database_service.dart';
// import '../services/local_database_service.dart';

/// Database environment types
enum DatabaseEnvironment {
  dev,
  qa,
  prod,
}

/// Database configuration using build-time environment variables
///
/// Build commands for each environment:
///
/// Dev (local mock database):
///   flutter build web --dart-define=DB_ENV=dev
///
/// QA/UAT (Supabase):
///   flutter build web \
///     --dart-define=DB_ENV=qa \
///     --dart-define=SUPABASE_URL=<qa_url> \
///     --dart-define=SUPABASE_ANON_KEY=<qa_key>
///
/// Production (Supabase):
///   flutter build web \
///     --dart-define=DB_ENV=prod \
///     --dart-define=SUPABASE_URL=<prod_url> \
///     --dart-define=SUPABASE_ANON_KEY=<prod_key>
class DatabaseConfig {
  /// Get the current database environment
  /// Throws an exception if DB_ENV is not set
  static DatabaseEnvironment get environment {
    const envString = String.fromEnvironment('DB_ENV');

    if (envString.isEmpty) {
      throw Exception(
        'DB_ENV environment variable is required. '
        'Must be one of: dev, qa, prod\n'
        'Example: flutter run --dart-define=DB_ENV=dev',
      );
    }

    switch (envString.toLowerCase()) {
      case 'dev':
        return DatabaseEnvironment.dev;
      case 'qa':
        return DatabaseEnvironment.qa;
      case 'prod':
      case 'mgmt':
        return DatabaseEnvironment.prod;
      default:
        throw Exception(
          'Invalid DB_ENV: $envString. Must be one of: dev, qa, prod',
        );
    }
  }

  /// Get Supabase URL from environment variable
  /// Required for qa and prod environments
  static String get supabaseUrl {
    const url = String.fromEnvironment('SUPABASE_URL');

    if (environment != DatabaseEnvironment.dev && url.isEmpty) {
      throw Exception(
        'SUPABASE_URL environment variable is required for ${environment.name} environment',
      );
    }

    return url;
  }

  /// Get Supabase anonymous key from environment variable
  /// Required for qa and prod environments
  static String get supabaseAnonKey {
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');

    if (environment != DatabaseEnvironment.dev && key.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY environment variable is required for ${environment.name} environment',
      );
    }

    return key;
  }

  /// Get the appropriate database service for the current environment
//BAD IDEA - no DB access from client
//   //   static DatabaseService getDatabaseService() {
//     if (environment == DatabaseEnvironment.dev) {
//       return LocalDatabaseService();
//     }
//
//     return SupabaseDatabaseService(
//       url: supabaseUrl,
//       anonKey: supabaseAnonKey,
//     );
//   }
}
