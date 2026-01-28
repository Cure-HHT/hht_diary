// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-d00031: Identity Platform Integration
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-CAL-p00030: Edit User Account
//   REQ-CAL-p00034: Site Visibility and Assignment
//   REQ-CAL-p00063: EDC Patient Ingestion
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-CAL-p00049: Mobile Linking Codes
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
  router.get('/api/v1/sponsor/roles', sponsorRoleMappingsHandler);

  // Portal API routes (Identity Platform authenticated)
  // All portal routes require valid Firebase Auth ID token
  router.get('/api/v1/portal/me', portalMeHandler);
  router.get('/api/v1/portal/users', getPortalUsersHandler);
  router.get('/api/v1/portal/users/<userId>', getPortalUserHandler);
  router.post('/api/v1/portal/users', createPortalUserHandler);
  router.patch('/api/v1/portal/users/<userId>', updatePortalUserHandler);
  router.get('/api/v1/portal/sites', getPortalSitesHandler);
  router.get('/api/v1/portal/patients', getPortalPatientsHandler);

  // Patient linking code endpoints (Investigator role)
  router.post(
    '/api/v1/portal/patients/<patientId>/link-code',
    generatePatientLinkingCodeHandler,
  );
  router.get(
    '/api/v1/portal/patients/<patientId>/link-code',
    getPatientLinkingCodeHandler,
  );

  // Email change verification
  router.post(
    '/api/v1/portal/email-verification/<token>',
    verifyEmailChangeHandler,
  );

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

  // Email OTP endpoints (for non-Developer-Admin users)
  // These require a valid Identity Platform token (password already verified)
  router.post('/api/v1/portal/auth/send-otp', sendEmailOtpHandler);
  router.post('/api/v1/portal/auth/verify-otp', verifyEmailOtpHandler);

  // Password reset request endpoint (unauthenticated - email-based flow)
  // Generates Identity Platform oobCode and sends custom email
  // Actual password reset uses Firebase client SDK (verifyPasswordResetCode/confirmPasswordReset)
  router.post(
    '/api/v1/portal/auth/password-reset/request',
    requestPasswordResetHandler,
  );

  // Feature flags (public endpoint for frontend configuration)
  router.get('/api/v1/portal/config/features', featureFlagsHandler);

  // Identity Platform configuration (public, needed before auth)
  // Returns Firebase config for client initialization
  router.get('/api/v1/portal/config/identity', identityConfigHandler);

  return router;
}
