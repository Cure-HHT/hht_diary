import 'package:event_sourcing/event_sourcing.dart';
import 'package:shared_events/shared_events.dart';
import 'package:test/test.dart';

void main() {
  test('SharedEventType exposes id and origin from its definition', () {
    const t = SharedEventType(
      definition: EntryTypeDefinition(
        id: 'example_event',
        registeredVersion: 1,
        name: 'Example',
      ),
      origin: EventOrigin.portal,
    );
    expect(t.id, 'example_event');
    expect(t.origin, EventOrigin.portal);
  });

  test('patient aggregate declares the [P]/edge entry types', () {
    final ids = patientEventTypes.map((t) => t.id).toSet();
    expect(ids, {
      'patient_synced_from_edc',
      'patient_linking_code_issued',
      'patient_linking_code_revoked',
      'patient_trial_started',
      'patient_disconnected',
      'patient_reconnected',
      'patient_marked_not_participating',
      'patient_reactivated',
      'patient_enrollment_status_changed',
    });
    expect(ids, isNot(contains('patient_linked'))); // [M], held
  });

  test('questionnaire aggregate declares the [P] entry types', () {
    final ids = questionnaireEventTypes.map((t) => t.id).toSet();
    expect(ids, {
      'questionnaire_assigned',
      'questionnaire_delivery_failed',
      'questionnaire_finalized',
      'questionnaire_scored',
      'questionnaire_unlocked',
      'questionnaire_called_back',
      'questionnaire_end_event_set',
    });
    expect(ids, isNot(contains('questionnaire_submitted'))); // [M], held
  });

  test('notification + fcm_token declare the [P]/edge entry types', () {
    final ids = notificationEventTypes.map((t) => t.id).toSet();
    expect(ids, {
      'notification_sent',
      'notification_dispatch_failed',
      'fcm_token_deactivated',
    });
    expect(ids, isNot(contains('fcm_message_received'))); // [M], held
    expect(ids, isNot(contains('fcm_token_registered'))); // [M], held
  });

  test(
    'sharedEventCatalog aggregates all [P]/edge entry types with no duplicates',
    () {
      final ids = sharedEventCatalog.map((t) => t.id).toList();
      expect(
        ids.length,
        19,
      ); // 9 patient + 7 questionnaire + 3 notification/fcm
      expect(ids.toSet().length, ids.length, reason: 'duplicate entry-type id');
    },
  );

  test(
    'every catalog id is snake_case and has a positive registeredVersion',
    () {
      final snake = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final t in sharedEventCatalog) {
        expect(
          snake.hasMatch(t.id),
          isTrue,
          reason: 'non-snake_case id: ${t.id}',
        );
        expect(t.definition.registeredVersion, greaterThanOrEqualTo(1));
        expect(t.definition.name, isNotEmpty);
      }
    },
  );

  test(
    'EntryTypeDefinition round-trips through JSON for every catalog entry',
    () {
      for (final t in sharedEventCatalog) {
        final round = EntryTypeDefinition.fromJson(t.definition.toJson());
        expect(round, t.definition, reason: 'round-trip mismatch for ${t.id}');
      }
    },
  );

  test('held [M] ids are documented and NOT registered in the catalog', () {
    final registered = sharedEventCatalog.map((t) => t.id).toSet();
    for (final heldId in heldMobileAuthoredIds) {
      expect(
        registered,
        isNot(contains(heldId)),
        reason:
            '$heldId is [M]-held and must not be registered until cross-post',
      );
    }
  });
}
