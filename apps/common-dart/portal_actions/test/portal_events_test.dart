import 'package:event_sourcing/event_sourcing.dart'; // ignore: unused_import — EntryTypeDefinition return type from portalPrivateEventTypes
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  // Verifies: DIARY-DEV-shared-events-catalog/A+B
  test(
    'DIARY-DEV-shared-events-catalog/A: portal-private ids snake_case, v1, unique',
    () {
      final ids = portalPrivateEventTypes.map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'no duplicate ids');
      final snake = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final d in portalPrivateEventTypes) {
        expect(snake.hasMatch(d.id), isTrue, reason: d.id);
        expect(d.registeredVersion, 1);
        expect(d.name, isNotEmpty);
      }
      expect(
        ids,
        containsAll(<String>[
          'user_created',
          'user_deactivated',
          'user_sessions_revoked',
          'role_permission_granted',
          'site_synced_from_edc',
          'rave_auth_failed',
          'annotation_created',
          'break_glass_granted',
          'auditor_export_recorded',
          'email_sent',
          'system_config_changed',
        ]),
      );
    },
  );

  // Verifies: DIARY-DEV-sponsor-branding-source/A
  test(
    'sponsor_branding_configured is a registered portal-private event type',
    () {
      expect(
        portalPrivateEventTypes.any(
          (e) => e.id == 'sponsor_branding_configured',
        ),
        isTrue,
      );
    },
  );

  // Verifies: DIARY-DEV-shared-events-catalog/E
  test(
    'DIARY-DEV-shared-events-catalog/E: portal-private ids do not collide with shared',
    () {
      final shared = sharedEventCatalog.map((t) => t.id).toSet();
      for (final d in portalPrivateEventTypes) {
        expect(shared, isNot(contains(d.id)), reason: d.id);
      }
    },
  );
}
