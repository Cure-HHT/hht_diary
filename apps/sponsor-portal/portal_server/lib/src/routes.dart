// IMPLEMENTS REQUIREMENTS:
//   REQ-o00056: Container infrastructure for Cloud Run
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-d00031: Identity Platform Integration
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-CAL-p00030: Edit User Account
//   REQ-CAL-p00034: Site Visibility and Assignment
//   REQ-CAL-p00063: EDC Participant Ingestion
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-CAL-p00049: Mobile Linking Codes
//   REQ-CAL-p00020: Participant Disconnection Workflow
//   REQ-CAL-p00077: Disconnection Notification
//   REQ-CAL-p00064: Mark Participant as Not Participating
//   REQ-CAL-p00079: Start Trial Workflow
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//   REQ-CAL-p00081: Participant Task System
//   REQ-d00169: Pending row cleanup endpoint
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

  // Sponsor branding (public, needed before auth for login page)
  router.get('/api/v1/sponsor/branding', sponsorBrandingHandler);

  // Portal API routes (Identity Platform authenticated)
  // All portal routes require valid Firebase Auth ID token
  router.get('/api/v1/portal/me', portalMeHandler);
  router.get('/api/v1/portal/users', getPortalUsersHandler);
  router.get('/api/v1/portal/users/<userId>', getPortalUserHandler);
  router.post('/api/v1/portal/users', createPortalUserHandler);
  router.patch('/api/v1/portal/users/<userId>', updatePortalUserHandler);
  // Implements: REQ-d00169 — delete pending (never-activated) portal user
  router.delete(
    '/api/v1/portal/users/<userId>',
    deletePendingPortalUserHandler,
  );
  router.get('/api/v1/portal/sites', getPortalSitesHandler);
  router.get('/api/v1/portal/participants', getPortalParticipantsHandler);

  // Participant operations (CUR-1220 renamed path segment from "participants").
  // participantId in request body/header, not URL (CUR-1064):
  //   POST routes: participantId in JSON body
  //   GET routes: participantId in X-Participant-Id header (not logged by CDN/proxy)
  router.post(
    '/api/v1/portal/participants/link-code',
    generateParticipantLinkingCodeHandler,
  );
  router.get(
    '/api/v1/portal/participants/link-code/active',
    getParticipantLinkingCodeHandler,
  );
  router.post(
    '/api/v1/portal/participants/disconnect',
    disconnectParticipantHandler,
  );
  router.post(
    '/api/v1/portal/participants/not-participating',
    markParticipantNotParticipatingHandler,
  );
  router.post(
    '/api/v1/portal/participants/reactivate',
    reactivateParticipantHandler,
  );
  router.post('/api/v1/portal/participants/start-trial', startTrialHandler);

  // Questionnaire management endpoints (Investigator role)
  // REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
  // GET: participantId in X-Participant-Id header; POST send: participantId + questionnaireType in body
  router.get(
    '/api/v1/portal/participants/questionnaires',
    getQuestionnaireStatusHandler,
  );
  router.post(
    '/api/v1/portal/participants/questionnaires/send',
    sendQuestionnaireHandler,
  );

  // Questionnaire instance operations — instanceId (opaque UUID) in URL, participantId looked up server-side
  router.delete(
    '/api/v1/portal/questionnaire-instances/<instanceId>',
    deleteQuestionnaireHandler,
  );
  router.post(
    '/api/v1/portal/questionnaire-instances/<instanceId>/unlock',
    unlockQuestionnaireHandler,
  );
  router.post(
    '/api/v1/portal/questionnaire-instances/<instanceId>/finalize',
    finalizeQuestionnaireHandler,
  );

  // Email change verification
  router.post(
    '/api/v1/portal/email-verification/<token>',
    verifyEmailChangeHandler,
  );

  // Activation endpoints
  // GET is unauthenticated (validates code before user has account)
  // POST is unauthenticated: accepts {code, password} in body, provisions
  //   the IdP user (lookupOrProvisionByEmail), stamps firebase_uid, flips
  //   status='active', returns {ok, roles}. The client signs in client-side
  //   after success — no token is issued by this handler.
  router.get('/api/v1/portal/activate/<code>', validateActivationCodeHandler);
  router.post('/api/v1/portal/activate', activateUserHandler);

  // Developer Admin only - generate activation codes
  router.post(
    '/api/v1/portal/admin/generate-code',
    generateActivationCodeHandler,
  );

  // Developer Admin only - Rave sync lockout state + unwedge
  // Implements: DIARY-OPS-rave-unwedge-authz, DIARY-GUI-dev-admin-rave-sync-card
  router.get(
    '/api/v1/portal/dev-admin/rave/lockout',
    getRaveLockoutStateHandler,
  );
  router.post('/api/v1/portal/dev-admin/rave/unwedge', unwedgeRaveHandler);

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
