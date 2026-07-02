import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Mock EnrollmentService for testing
class MockEnrollmentService implements EnrollmentService {
  String? jwtToken;
  String? backendUrl;
  UserEnrollment? enrollment;

  // CUR-86: the real service exposes its storage so tests can assert the
  // device-only Keychain configuration; the mock has no real storage.
  @override
  FlutterSecureStorage get secureStorageForTest =>
      throw UnimplementedError('MockEnrollmentService has no secure storage');

  // Verifies: DIARY-PRD-notification-disconnection
  // Disconnection state for testing
  bool _isDisconnected = false;

  @override
  final ValueNotifier<bool> disconnectedNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<bool> notParticipatingNotifier = ValueNotifier(false);

  // CUR-1165: Not participating state for testing
  bool _isNotParticipating = false;
  DateTime? _notParticipatingAt;

  @override
  Future<String?> getJwtToken() async => jwtToken;

  @override
  Future<bool> isEnrolled() async => jwtToken != null;

  @override
  Future<UserEnrollment?> getEnrollment() async => enrollment;

  @override
  Future<UserEnrollment> enroll(String code) async {
    throw UnimplementedError();
  }

  @override
  Future<void> clearEnrollment() async {}

  @override
  Future<void> clearSecureStorageForFactoryReset() async {}

  @override
  void dispose() {}

  @override
  Future<String?> getUserId() async => 'test-user-id';

  @override
  Future<String?> getBackendUrl() async => backendUrl;

  // Verifies: DIARY-PRD-notification-disconnection
  // Disconnection tracking methods
  @override
  Future<bool> isDisconnected() async => _isDisconnected;

  @override
  Future<void> setDisconnected(bool disconnected) async {
    _isDisconnected = disconnected;
    disconnectedNotifier.value = disconnected;
  }

  @override
  bool processDisconnectionStatus(Map<String, dynamic> response) {
    final isDisconnected = response['isDisconnected'] as bool? ?? false;
    final isNotParticipating = response['isNotParticipating'] as bool? ?? false;
    _isDisconnected = isDisconnected;
    _isNotParticipating = isNotParticipating;
    if (isNotParticipating && _notParticipatingAt == null) {
      _notParticipatingAt = DateTime.now();
    } else if (!isNotParticipating) {
      _notParticipatingAt = null;
    }
    return isDisconnected;
  }

  // CUR-1165: Not participating mock methods
  @override
  Future<bool> isNotParticipating() async => _isNotParticipating;

  @override
  Future<void> setNotParticipating(
    bool notParticipating, {
    DateTime? at,
  }) async {
    _isNotParticipating = notParticipating;
    notParticipatingNotifier.value = notParticipating;
    if (notParticipating) {
      _notParticipatingAt ??= at ?? DateTime.now();
    } else {
      _notParticipatingAt = null;
    }
  }

  @override
  Future<DateTime?> getNotParticipatingAt() async => _notParticipatingAt;

  @override
  Future<void> seedLifecycleNotifiers() async {
    disconnectedNotifier.value = _isDisconnected;
    notParticipatingNotifier.value = _isNotParticipating;
  }
}
