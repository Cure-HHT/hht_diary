// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00008: User Account Management
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-d00078: Linking Code Validation
//   REQ-CAL-p00082: Patient Alert Delivery
//   REQ-CAL-p00081: Patient Task System
//   REQ-p00049: Ancillary Platform Services (push notifications)
//
// Route definitions for diary server

import 'package:shelf_router/shelf_router.dart';

import 'package:diary_functions/diary_functions.dart';

/// Creates the router with all API routes
Router createRouter() {
  final router = Router();

  // Health check endpoint (required for Cloud Run)
  router.get('/health', healthHandler);

  // Auth routes
  router.post('/api/v1/auth/register', registerHandler);
  router.post('/api/v1/auth/login', loginHandler);
  router.post('/api/v1/auth/change-password', changePasswordHandler);

  // User routes
  router.post('/api/v1/user/enroll', enrollHandler); // DEPRECATED - returns 410
  router.post('/api/v1/user/link', linkHandler); // Patient linking via codes
  router.post('/api/v1/user/sync', syncHandler);
  router.post('/api/v1/user/records', getRecordsHandler);
  router.get('/api/v1/user/tasks', getTasksHandler); // Task discovery (polling)

  // Sponsor routes
  router.get('/api/v1/sponsor/config', sponsorConfigHandler);

  // FCM token registration (mobile app registers its push notification token)
  router.post('/api/v1/user/fcm-token', registerFcmTokenHandler);

  return router;
}
