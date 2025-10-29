// IMPLEMENTS REQUIREMENTS:
//   REQ-d00028: Portal Frontend Framework

import '../services/database_service.dart';
import '../services/local_database_service.dart';

/// Database configuration
/// Set useLocalDatabase = true for testing without Supabase
class DatabaseConfig {
  // Toggle this to switch between local and Supabase
  static const bool useLocalDatabase = true;

  static DatabaseService getDatabaseService() {
    if (useLocalDatabase) {
      return LocalDatabaseService();
    } else {
      // TODO: Implement SupabaseDatabaseService when credentials are available
      throw UnimplementedError('Supabase database service not yet implemented');
    }
  }
}
