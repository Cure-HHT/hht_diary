import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/services/enrollment_service.dart';

/// Mock EnrollmentService for testing
class MockEnrollmentService implements EnrollmentService {
  String? jwtToken;
  String? backendUrl;
  UserEnrollment? enrollment;

  // REQ-CAL-p00077: Disconnection state for testing
  bool _isDisconnected = false;
  bool _bannerDismissed = false;

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
  void dispose() {}

  @override
  Future<String?> getUserId() async => 'test-user-id';

  @override
  Future<String?> getBackendUrl() async => backendUrl;

  @override
  Future<String?> getSyncUrl() async =>
      backendUrl != null ? '$backendUrl/api/v1/user/sync' : null;

  @override
  Future<String?> getRecordsUrl() async =>
      backendUrl != null ? '$backendUrl/api/v1/user/records' : null;

  // REQ-CAL-p00077: Disconnection tracking methods
  @override
  Future<bool> isDisconnected() async => _isDisconnected;

  @override
  Future<void> setDisconnected(bool disconnected) async {
    _isDisconnected = disconnected;
    if (!disconnected) {
      _bannerDismissed = false;
    }
  }

  @override
  Future<bool> isDisconnectionBannerDismissed() async => _bannerDismissed;

  @override
  Future<void> setDisconnectionBannerDismissed(bool dismissed) async {
    _bannerDismissed = dismissed;
  }

  @override
  Future<void> resetDisconnectionBannerDismissed() async {
    _bannerDismissed = false;
  }

  @override
  bool processDisconnectionStatus(Map<String, dynamic> response) {
    final isDisconnected = response['isDisconnected'] as bool? ?? false;
    _isDisconnected = isDisconnected;
    return isDisconnected;
  }
}
