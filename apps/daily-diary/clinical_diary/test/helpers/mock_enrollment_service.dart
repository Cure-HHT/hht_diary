import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/services/enrollment_service.dart';

/// Mock EnrollmentService for testing
class MockEnrollmentService implements EnrollmentService {
  String? jwtToken;
  String? backendUrl;
  UserEnrollment? enrollment;

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
}
