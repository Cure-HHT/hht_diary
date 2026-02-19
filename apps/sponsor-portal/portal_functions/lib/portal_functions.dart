// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p00002: Multi-Factor Authentication for Staff
//   REQ-CAL-p00010: Schema-Driven Data Validation (EDC sync)
//
// Portal functions library - backend handlers for Sponsor Portal

library portal_functions;

// Portal authentication (Identity Platform / Firebase Auth)
export 'src/identity_platform.dart';
export 'src/portal_activation.dart';
export 'src/portal_auth.dart';
export 'src/portal_password_reset.dart';
export 'src/portal_user.dart';

// Email OTP and MFA
export 'src/email_service.dart';
export 'src/email_otp.dart';
export 'src/feature_flags.dart';

// Database and utilities
export 'src/database.dart';
export 'src/health.dart';
export 'src/identity_config.dart';
export 'src/sponsor.dart';
export 'src/sponsor_branding.dart';

// EDC Integration
export 'src/patients_sync.dart';
export 'src/sites_sync.dart';

// Patient Linking
export 'src/patient_linking.dart';

// Questionnaire Management & Notifications
export 'src/notification_service.dart';
export 'src/questionnaire.dart';
