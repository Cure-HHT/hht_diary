// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation
//   REQ-p00008: User Account Management
//   REQ-p00013: GDPR compliance - EU-only regions
//   REQ-CAL-p00082: Patient Alert Delivery
//   REQ-CAL-p00081: Patient Task System
//   REQ-p00049: Ancillary Platform Services (push notifications)
//
// Diary functions library - Dart conversion of Firebase Cloud Functions

library diary_functions;

export 'src/auth.dart';
export 'src/database.dart';
export 'src/fcm_token.dart';
export 'src/health.dart';
export 'src/jwt.dart';
export 'src/sponsor.dart';
export 'src/tasks.dart';
export 'src/user.dart';
