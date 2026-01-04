// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-d00005: Sponsor Configuration Detection Implementation
//
// Route definitions for diary server

import 'package:shelf_router/shelf_router.dart';

import 'package:diary_functions/diary_functions.dart';

/// Creates the router with all API routes
Router createRouter() {
  final router = Router();

  // Health check endpoint (required for Cloud Run)
  router.get('/health', healthHandler);

  // API v1 routes - will be populated as functions are converted
  // router.post('/api/v1/auth/register', authHandlers.register);
  // router.post('/api/v1/auth/login', authHandlers.login);
  // router.post('/api/v1/user/enroll', userHandlers.enroll);
  // router.get('/api/v1/sponsor/config', sponsorHandlers.config);

  return router;
}
