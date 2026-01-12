// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-d00031: Identity Platform Integration
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00024: Portal User Roles and Permissions
//
// Route definitions for portal server
// All portal routes use /api/v1/portal prefix for versioning

import 'package:shelf_router/shelf_router.dart';

import 'package:portal_functions/portal_functions.dart';

/// Creates the router with all API routes
Router createRouter() {
  final router = Router();

  // Health check endpoint (required for Cloud Run)
  router.get('/health', healthHandler);

  // Sponsor configuration (public, used by UI to detect sponsor)
  router.get('/api/v1/sponsor/config', sponsorConfigHandler);

  // Portal API routes (Identity Platform authenticated)
  // All portal routes require valid Firebase Auth ID token
  router.get('/api/v1/portal/me', portalMeHandler);
  router.get('/api/v1/portal/users', getPortalUsersHandler);
  router.post('/api/v1/portal/users', createPortalUserHandler);
  router.patch('/api/v1/portal/users/<userId>', updatePortalUserHandler);
  router.get('/api/v1/portal/sites', getPortalSitesHandler);

  // Activation endpoints
  // GET is unauthenticated (validates code before user has account)
  // POST requires Firebase token to link identity
  router.get('/api/v1/portal/activate/<code>', validateActivationCodeHandler);
  router.post('/api/v1/portal/activate', activateUserHandler);

  // Developer Admin only - generate activation codes
  router.post(
    '/api/v1/portal/admin/generate-code',
    generateActivationCodeHandler,
  );

  return router;
}
