// IMPLEMENTS REQUIREMENTS:
//   REQ-d00031: Identity Platform Integration
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-p00024: Portal User Roles and Permissions
//
// Portal functions library - backend handlers for Sponsor Portal

library portal_functions;

// Portal authentication (Identity Platform / Firebase Auth)
export 'src/identity_platform.dart';
export 'src/portal_activation.dart';
export 'src/portal_auth.dart';
export 'src/portal_user.dart';

// Database and utilities
export 'src/database.dart';
export 'src/health.dart';
export 'src/sponsor.dart';
