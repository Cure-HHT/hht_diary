import 'package:clinical_diary/models/user_enrollment.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:comms/comms.dart';
import 'package:flutter/foundation.dart';

/// Mock EnrollmentService for testing
class MockEnrollmentService implements EnrollmentService {
  String? jwtToken;
  String? backendUrl;
  UserEnrollment? enrollment;

  // REQ-CAL-p00077: Disconnection state for testing
  bool _isDisconnected = false;

  @override
  final ValueNotifier<bool> disconnectedNotifier = ValueNotifier(false);

  // CUR-1165: Not participating state for testing
  bool _isNotParticipating = false;
  DateTime? _notParticipatingAt;

  // CUR-1311: Mirror the real service's not-participating notifier so
  // listeners under test fire when status flips.
  @override
  final ValueNotifier<bool> notParticipatingNotifier = ValueNotifier(false);

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
    disconnectedNotifier.value = disconnected;
  }

  @override
  bool processDisconnectionStatus(Map<String, dynamic> response) {
    final isDisconnected = response['isDisconnected'] as bool? ?? false;
    final isNotParticipating = response['isNotParticipating'] as bool? ?? false;
    _isDisconnected = isDisconnected;
    _isNotParticipating = isNotParticipating;
    // CUR-1311: fire notifiers so listeners under test observe the
    // status flip — matches the real EnrollmentService which routes
    // through setDisconnected / setNotParticipating.
    disconnectedNotifier.value = isDisconnected;
    notParticipatingNotifier.value = isNotParticipating;
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

  // CUR-1311 P1B.5: Envelope-based status update handler.
  @override
  void handleEnvelopeStatusUpdate(Envelope envelope) {
    final action = envelope.payload['action'] as String?;
    switch (action) {
      case 'disconnect':
        setDisconnected(true);
      case 'reconnect':
        setDisconnected(false);
      case 'mark_not_participating':
        setNotParticipating(true, at: DateTime.now());
      case 'reactivate':
        setNotParticipating(false);
      case 'start_trial':
        break;
      default:
        debugPrint('[MockEnrollmentService] Unknown status action: $action');
    }
  }
}
