// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-p00013: GDPR compliance - EU-only regions
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
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

  // Log environment configuration at startup (secrets masked)
  log.info('=== Environment Configuration ===');
  final envVars = [
    'PORT',
    'DB_HOST',
    'DB_PORT',
    'DB_NAME',
    'DB_USER',
    'EMAIL_SVC_ACCT',
    'EMAIL_SENDER',
    'EMAIL_SENDER_NAME',
    'EMAIL_CONSOLE_MODE',
    'FCM_PROJECT_ID',
    'FCM_ENABLED',
    'FCM_CONSOLE_MODE',
    'IDENTITY_PLATFORM_PROJECT_ID',
    'GOOGLE_CLOUD_PROJECT',
    'K_SERVICE',
    'K_REVISION',
  ];
  for (final key in envVars) {
    final value = Platform.environment[key];
    log.info('  $key: ${value ?? "(not set)"}');
  }
  // Log presence of secrets without revealing values
  final secretVars = ['DB_PASSWORD', 'IDENTITY_PLATFORM_API_KEY'];
  for (final key in secretVars) {
    final value = Platform.environment[key];
    log.info(
      '  $key: ${value != null ? "(set, ${value.length} chars)" : "(not set)"}',
    );
  }
  log.info('=================================');

  // Initialize database connection pool
  log.info('Initializing database connection...');
  final dbConfig = DatabaseConfig.fromEnvironment();
  await Database.instance.initialize(dbConfig);
  log.info('Database connected to ${dbConfig.host}:${dbConfig.port}');

  // Initialize email service (for activation emails and OTP)
  log.info('Initializing email service...');
  final emailConfig = EmailConfig.fromEnvironment();
  await EmailService.instance.initialize(emailConfig);
  if (EmailService.instance.isReady) {
    log.info('Email service ready (sender: ${emailConfig.senderEmail})');
  } else {
    log.warning('Email service not configured - emails will not be sent');
  }

  // Initialize notification service (for FCM push notifications)
  log.info('Initializing notification service...');
  final notificationConfig = NotificationConfig.fromEnvironment();
  await NotificationService.instance.initialize(notificationConfig);
  if (NotificationService.instance.isReady) {
    log.info(
      'Notification service ready (project: ${notificationConfig.projectId})',
    );
  } else {
    log.warning(
      'Notification service not configured - push notifications will not be sent',
    );
  }

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
