// Testing utilities - exposes internal functions for testing
// This file should NOT be used in production code

@Deprecated('For testing only')
library portal_functions.testing_utils;

import 'dart:convert';
import 'dart:math';

/// Decode base64url encoded string (matches _base64UrlDecode in identity_platform.dart)
String base64UrlDecodeForTesting(String input) {
  var padded = input;
  switch (input.length % 4) {
    case 2:
      padded = '$input==';
    case 3:
      padded = '$input=';
  }
  final bytes = base64Url.decode(padded);
  return utf8.decode(bytes);
}

/// Generate linking code (matches _generateLinkingCode in portal_user.dart)
String generateLinkingCodeForTesting() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  String part() =>
      List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();
  return '${part()}-${part()}';
}

/// Linking code format regex for validation
/// Allowed chars: ABCDEFGHJKLMNPQRSTUVWXYZ23456789 (excludes I, O, 0, 1)
final linkingCodePattern = RegExp(r'^[A-HJ-NP-Z2-9]{5}-[A-HJ-NP-Z2-9]{5}$');

/// Validate linking code format
bool isValidLinkingCode(String code) => linkingCodePattern.hasMatch(code);

// ============================================================================
// Auth validation functions (matches validation in auth.dart)
// ============================================================================

const minUsernameLength = 6;
final usernamePattern = RegExp(r'^[a-zA-Z0-9_]+$');

/// Validate username format (matches _validateUsername in auth.dart)
String? validateUsernameForTesting(String? username) {
  if (username == null || username.length < minUsernameLength) {
    return 'Username must be at least $minUsernameLength characters';
  }
  if (username.contains('@')) {
    return 'Username cannot contain @ symbol';
  }
  if (!usernamePattern.hasMatch(username)) {
    return 'Username can only contain letters, numbers, and underscores';
  }
  return null;
}

/// Validate password hash format (matches _validatePasswordHash in auth.dart)
String? validatePasswordHashForTesting(String? passwordHash) {
  if (passwordHash == null || passwordHash.length != 64) {
    return 'Password must be at least 8 characters';
  }
  if (!RegExp(r'^[a-f0-9]{64}$', caseSensitive: false).hasMatch(passwordHash)) {
    return 'Invalid password format';
  }
  return null;
}

// ============================================================================
// User event mapping (matches _mapEventTypeToOperation in user.dart)
// ============================================================================

/// Map client event type to record_audit operation
String mapEventTypeToOperationForTesting(String eventType) {
  switch (eventType.toLowerCase()) {
    case 'create':
    case 'nosebleedrecorded':
    case 'surveysubmitted':
      return 'USER_CREATE';
    case 'update':
    case 'nosebleedupdated':
      return 'USER_UPDATE';
    case 'delete':
    case 'nosebleeddeleted':
      return 'USER_DELETE';
    default:
      return 'USER_CREATE';
  }
}

/// Enrollment code pattern (matches _enrollmentCodePattern in user.dart)
final enrollmentCodePattern = RegExp(r'^CUREHHT[0-9]$', caseSensitive: false);

/// Validate enrollment code format
bool isValidEnrollmentCode(String code) =>
    enrollmentCodePattern.hasMatch(code.toUpperCase());
