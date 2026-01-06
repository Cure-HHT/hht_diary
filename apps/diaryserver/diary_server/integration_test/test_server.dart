// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: User Account Management
//
// Test server helper for integration tests
// Starts the diary server on a random port with test database configuration

import 'dart:io';

import 'package:diary_functions/diary_functions.dart';
import 'package:diary_server/diary_server.dart';

/// Test server wrapper for integration tests
class TestServer {
  HttpServer? _server;
  int? _port;

  /// Base URL for the test server
  String get baseUrl => 'http://localhost:$_port';

  /// Start the test server on a random available port
  Future<void> start() async {
    // Initialize database with test configuration
    final dbConfig = _getTestDatabaseConfig();
    await Database.instance.initialize(dbConfig);

    // Find an available port
    _port = await _findAvailablePort();

    // Start server
    _server = await createServer(port: _port!);

    print('Test server started on port $_port');
  }

  /// Stop the test server and close database
  Future<void> stop() async {
    await _server?.close(force: true);
    await Database.instance.close();
    print('Test server stopped');
  }

  /// Get database configuration for tests
  /// Uses environment variables with fallbacks for local development
  DatabaseConfig _getTestDatabaseConfig() {
    return DatabaseConfig(
      host: Platform.environment['DB_HOST'] ?? 'localhost',
      port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
      database: Platform.environment['DB_NAME'] ?? 'sponsor_portal',
      username: Platform.environment['DB_USER'] ?? 'app_user',
      password:
          Platform.environment['DB_PASSWORD'] ??
          Platform.environment['LOCAL_DB_PASSWORD'] ??
          '',
      useSsl: Platform.environment['DB_SSL'] != 'false',
    );
  }

  /// Find an available port for the test server
  Future<int> _findAvailablePort() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }
}
