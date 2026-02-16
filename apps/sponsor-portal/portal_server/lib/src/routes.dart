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
//   REQ-CAL-p00020: Patient Disconnection Workflow
//   REQ-CAL-p00077: Disconnection Notification
//   REQ-CAL-p00064: Mark Patient as Not Participating
//   REQ-CAL-p00079: Start Trial Workflow
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00081: Patient Task System
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

  // Patient disconnection endpoint (Investigator role)
  router.post(
    '/api/v1/portal/patients/<patientId>/disconnect',
    disconnectPatientHandler,
  );

  // Mark patient as not participating endpoint (Investigator role)
  router.post(
    '/api/v1/portal/patients/<patientId>/not-participating',
    markPatientNotParticipatingHandler,
  );

  // Reactivate patient endpoint (Investigator role)
  router.post(
    '/api/v1/portal/patients/<patientId>/reactivate',
    reactivatePatientHandler,
  );

  // Start trial endpoint (Investigator role)
  router.post(
    '/api/v1/portal/patients/<patientId>/start-trial',
    startTrialHandler,
  );

  // Questionnaire management endpoints (Investigator role)
  // REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
  router.get(
    '/api/v1/portal/patients/<patientId>/questionnaires',
    getQuestionnaireStatusHandler,
  );
  router.post(
    '/api/v1/portal/patients/<patientId>/questionnaires/<questionnaireType>/send',
    sendQuestionnaireHandler,
  );
  router.delete(
    '/api/v1/portal/patients/<patientId>/questionnaires/<instanceId>',
    deleteQuestionnaireHandler,
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
