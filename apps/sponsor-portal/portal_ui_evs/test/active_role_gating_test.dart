// Verifies: DIARY-GUI-role-switching/E+F — the active-role visibility principle
//   (show only controls the active role may use) extended to in-screen action
//   controls: participant lifecycle buttons and user-account role chips.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/participant_status.dart';
import 'package:portal_ui_evs/src/participants_screen.dart';
import 'package:portal_ui_evs/src/user_accounts_screen.dart';

EffectiveAuthorization _authFor(String role) => EffectiveAuthorization(
  activeRole: role,
  rolePermissions: const <Permission>{},
  scopeAssignments: const <ScopeAssignment>[],
);

void main() {
  group('participant control gating (permissionForTest)', () {
    test(
      'each lifecycle action maps to its portal.participant.* permission',
      () {
        expect(
          permissionForTest(ParticipantAction.issueLinkingCode),
          'portal.participant.link',
        );
        // showCode reveals the code -> gated on the same code-management perm.
        expect(
          permissionForTest(ParticipantAction.showCode),
          'portal.participant.link',
        );
        expect(
          permissionForTest(ParticipantAction.startTrial),
          'portal.participant.start_trial',
        );
        expect(
          permissionForTest(ParticipantAction.disconnect),
          'portal.participant.disconnect',
        );
        expect(
          permissionForTest(ParticipantAction.reconnect),
          'portal.participant.reconnect',
        );
        expect(
          permissionForTest(ParticipantAction.markNotParticipating),
          'portal.participant.mark_not_participating',
        );
        expect(
          permissionForTest(ParticipantAction.reactivate),
          'portal.participant.reactivate',
        );
      },
    );

    test('every ParticipantAction has a gating permission', () {
      for (final a in ParticipantAction.values) {
        expect(permissionForTest(a), isNotEmpty);
      }
    });
  });

  group('role chip gating (grantableRolesForTest)', () {
    test('Administrator may grant staff-tier roles but NOT SystemOperator', () {
      final roles = grantableRolesForTest(_authFor('Administrator'));
      expect(
        roles,
        containsAll(<String>['StudyCoordinator', 'CRA', 'Administrator']),
      );
      expect(roles, isNot(contains('SystemOperator')));
    });

    test('SystemOperator may grant the operator-tier SystemOperator role', () {
      final roles = grantableRolesForTest(_authFor('SystemOperator'));
      expect(roles, contains('SystemOperator'));
    });

    test('null/empty authorization hides operator-tier roles (fail-safe)', () {
      expect(grantableRolesForTest(null), isNot(contains('SystemOperator')));
      expect(
        grantableRolesForTest(_authFor('')),
        isNot(contains('SystemOperator')),
      );
    });
  });
}
