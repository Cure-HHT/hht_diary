// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-p00013: GDPR compliance - EU-only regions
//
// Main entry point for the portal server
// Runs a shelf HTTP server on Cloud Run

import 'dart:io';

import 'package:portal_functions/portal_functions.dart';
import 'package:portal_server/portal_server.dart';
import 'package:logging/logging.dart';

void main(List<String> args) async {
  // Configure logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    // Cloud Run structured logging format
    print(
      '{"severity":"${record.level.name}",'
      '"message":"${record.message}",'
      '"time":"${record.time.toIso8601String()}"}',
    );
  });

  final log = Logger('portal_server');

  // Initialize database connection pool
  log.info('Initializing database connection...');
  final dbConfig = DatabaseConfig.fromEnvironment();
  await Database.instance.initialize(dbConfig);
  log.info('Database connected to ${dbConfig.host}:${dbConfig.port}');

  // Get port from environment (Cloud Run sets PORT)
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  // Start server
  final server = await createServer(port: port);

  log.info('Portal server listening on port $port');

  // Handle shutdown signals
  ProcessSignal.sigint.watch().listen((_) async {
    log.info('Received SIGINT, shutting down...');
    await Database.instance.close();
    await server.close();
    exit(0);
  });

  ProcessSignal.sigterm.watch().listen((_) async {
    log.info('Received SIGTERM, shutting down...');
    await Database.instance.close();
    await server.close();
    exit(0);
  });
}
