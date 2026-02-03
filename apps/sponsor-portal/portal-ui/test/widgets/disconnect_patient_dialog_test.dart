// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00020: Patient Disconnection Workflow
//   REQ-CAL-p00073: Patient Status Definitions
//   REQ-CAL-p00077: Disconnection Notification
//
// Tests for DisconnectPatientDialog and DisconnectReason enum

import 'package:flutter_test/flutter_test.dart';
import 'package:sponsor_portal_ui/widgets/disconnect_patient_dialog.dart';

void main() {
  group('DisconnectReason enum', () {
    test('has correct labels', () {
      expect(DisconnectReason.deviceIssues.label, 'Device Issues');
      expect(DisconnectReason.technicalIssues.label, 'Technical Issues');
      expect(DisconnectReason.other.label, 'Other');
    });

    test('has correct descriptions', () {
      expect(
        DisconnectReason.deviceIssues.description,
        'Lost, stolen, or damaged device',
      );
      expect(
        DisconnectReason.technicalIssues.description,
        'App not working, sync problems',
      );
      expect(DisconnectReason.other.description, 'Specify reason in notes');
    });

    test('has exactly 3 values matching spec', () {
      expect(DisconnectReason.values.length, 3);
      expect(
        DisconnectReason.values.map((r) => r.label).toList(),
        containsAll(['Device Issues', 'Technical Issues', 'Other']),
      );
    });

    test('reason labels match backend validDisconnectReasons', () {
      // Backend uses: 'Device Issues', 'Technical Issues', 'Other'
      // These must match for API calls to succeed
      expect(DisconnectReason.deviceIssues.label, 'Device Issues');
      expect(DisconnectReason.technicalIssues.label, 'Technical Issues');
      expect(DisconnectReason.other.label, 'Other');
    });
  });
}
