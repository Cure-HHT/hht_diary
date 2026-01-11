// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00008: User Account Management
//   REQ-p00013: GDPR compliance - EU-only regions
//   REQ-d00031: Identity Platform Integration
//   REQ-d00035: Admin Dashboard Implementation
//
// Portal functions library - Dart conversion of Firebase Cloud Functions

library portal_functions;

// Mobile app authentication (legacy)
export 'src/auth.dart';
export 'src/jwt.dart';
export 'src/user.dart';

// Portal authentication (Identity Platform)
export 'src/identity_platform.dart';
export 'src/portal_activation.dart';
export 'src/portal_auth.dart';
export 'src/portal_user.dart';

// Database and utilities
export 'src/database.dart';
export 'src/health.dart';
export 'src/sponsor.dart';
