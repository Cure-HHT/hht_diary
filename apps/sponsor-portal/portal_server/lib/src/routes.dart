// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00008: User Account Management
//
// Route definitions for portal server

import 'package:shelf_router/shelf_router.dart';

import 'package:portal_functions/portal_functions.dart';

/// Creates the router with all API routes
Router createRouter() {
  final router = Router();

  // Health check endpoint (required for Cloud Run)
  router.get('/health', healthHandler);

  // Auth routes
  router.post('/api/v1/auth/login', loginHandler);
  router.post('/api/v1/auth/change-password', changePasswordHandler);

  // User routes
  router.post('/api/v1/user/enroll', enrollHandler);
  router.post('/api/v1/user/sync', syncHandler);
  router.post('/api/v1/user/records', getRecordsHandler);

  // Sponsor routes
  router.get('/api/v1/sponsor/config', sponsorConfigHandler);

  return router;
}
