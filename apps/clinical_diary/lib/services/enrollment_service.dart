// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import 'dart:convert';

import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Service for handling user enrollment with 8-character codes
/// Uses HTTP calls to Firebase Functions for enrollment
class EnrollmentService {
  EnrollmentService({
    FlutterSecureStorage? secureStorage,
    http.Client? httpClient,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _httpClient = httpClient ?? http.Client();

  static const _storageKey = 'user_enrollment';
  final FlutterSecureStorage _secureStorage;
  final http.Client _httpClient;

  /// Check if user is enrolled
  Future<bool> isEnrolled() async {
    final data = await _secureStorage.read(key: _storageKey);
    return data != null;
  }

  /// Get current enrollment if exists
  Future<UserEnrollment?> getEnrollment() async {
    final data = await _secureStorage.read(key: _storageKey);
    if (data == null) return null;
    try {
      return UserEnrollment.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// Enroll with an 8-character code (CUREHHT#)
  /// Returns the enrollment on success, throws on failure
  Future<UserEnrollment> enroll(String code) async {
    try {
      final normalizedCode = code.toUpperCase().trim();

      debugPrint('Enrolling with code: $normalizedCode');

      // Call the enroll function via HTTP
      final response = await _httpClient.post(
        Uri.parse(AppConfig.enrollUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': normalizedCode}),
      );

      debugPrint('Enroll response status: ${response.statusCode}');
      debugPrint('Enroll response body: ${response.body}');

      if (response.statusCode == 409) {
        throw EnrollmentException(
          'This code has already been used.',
          EnrollmentErrorType.codeAlreadyUsed,
        );
      }

      if (response.statusCode == 400) {
        throw EnrollmentException(
          'Invalid enrollment code.',
          EnrollmentErrorType.invalidCode,
        );
      }

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
        throw EnrollmentException(
          errorBody['error']?.toString() ?? 'Server error',
          EnrollmentErrorType.serverError,
        );
      }

      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
      final jwtToken = responseBody['jwt'] as String;
      final userId = responseBody['userId'] as String;

      debugPrint('Enrollment successful, userId: $userId');

      final enrollment = UserEnrollment(
        userId: userId,
        jwtToken: jwtToken,
        enrolledAt: DateTime.now(),
      );

      await _saveEnrollment(enrollment);
      return enrollment;
    } on http.ClientException catch (e) {
      debugPrint('HTTP error: $e');
      throw EnrollmentException(
        'Network error. Please check your connection.',
        EnrollmentErrorType.networkError,
      );
    } catch (e, stack) {
      if (e is EnrollmentException) rethrow;

      debugPrint('Enrollment error: $e');
      debugPrint('Stack trace:\n$stack');
      throw EnrollmentException('Error: $e', EnrollmentErrorType.networkError);
    }
  }

  /// Save enrollment to secure storage
  Future<void> _saveEnrollment(UserEnrollment enrollment) async {
    await _secureStorage.write(
      key: _storageKey,
      value: jsonEncode(enrollment.toJson()),
    );
  }

  /// Clear enrollment (for testing or logout)
  Future<void> clearEnrollment() async {
    await _secureStorage.delete(key: _storageKey);
  }

  /// Get JWT token for API calls
  /// Checks enrollment first, then falls back to auth_jwt (for username/password login)
  Future<String?> getJwtToken() async {
    // First check enrollment (CUREHHT code flow)
    final enrollment = await getEnrollment();
    if (enrollment?.jwtToken != null) {
      return enrollment!.jwtToken;
    }
    // Fall back to auth service JWT (username/password login flow)
    return _secureStorage.read(key: 'auth_jwt');
  }

  /// Get user ID from enrollment or auth service
  /// Checks enrollment first, then falls back to auth_username (for username/password login)
  Future<String?> getUserId() async {
    // First check enrollment (CUREHHT code flow)
    final enrollment = await getEnrollment();
    if (enrollment?.userId != null) {
      return enrollment!.userId;
    }
    // Fall back to auth service username (username/password login flow)
    return _secureStorage.read(key: 'auth_username');
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}

/// Types of enrollment errors
enum EnrollmentErrorType {
  invalidCode,
  codeAlreadyUsed,
  serverError,
  networkError,
}

/// Exception thrown during enrollment
class EnrollmentException implements Exception {
  EnrollmentException(this.message, this.type);
  final String message;
  final EnrollmentErrorType type;

  @override
  String toString() => message;
}
