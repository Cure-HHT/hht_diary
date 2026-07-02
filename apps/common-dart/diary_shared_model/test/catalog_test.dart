import 'package:event_sourcing/event_sourcing.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
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

  test('participant aggregate declares the [P]/edge entry types', () {
    // Verifies: DIARY-DEV-shared-events-catalog/A+B+C
    final ids = participantEventTypes.map((t) => t.id).toSet();
    expect(ids, {
      'participant_synced_from_edc',
      'participant_linking_code_issued',
      'participant_linking_code_revoked',
      'participant_linking_code_used',
      'participant_trial_started',
      'participant_disconnected',
      'participant_reconnected',
      'participant_marked_not_participating',
      'participant_reactivated',
      'participant_enrollment_status_changed',
    });
  });

  test('questionnaire aggregate declares the [P] entry types', () {
    final ids = questionnaireEventTypes.map((t) => t.id).toSet();
    expect(ids, {
      'questionnaire_assigned',
      'questionnaire_delivery_failed',
      'questionnaire_submission_received',
      'questionnaire_locked',
      // CUR-1539: frozen legacy alias of questionnaire_locked — kept registered
      // for pre-rename portal logs and the diary's device-observed status mint.
      'questionnaire_finalized',
      'questionnaire_scored',
      'questionnaire_unlocked',
      'questionnaire_called_back',
      'questionnaire_end_event_set',
      'questionnaire_recall_notice',
    });
    expect(
      ids,
      isNot(contains('questionnaire_submitted')),
    ); // intentionally absent (finalized-kind on <id>_survey)
  });

  test('notification + fcm_token declare the [P]/edge entry types', () {
    final ids = notificationEventTypes.map((t) => t.id).toSet();
    expect(ids, {
      'notification_sent',
      'notification_dispatch_failed',
      'fcm_token_deactivated',
    });
  });

  test(
    'sharedEventCatalog aggregates all [P]/edge entry types with no duplicates',
    () {
      final ids = sharedEventCatalog.map((t) => t.id).toList();
      expect(
        ids.length,
        31,
      ); // 10 participant + 10 questionnaire (incl. the CUR-1539 legacy alias
      // questionnaire_finalized) + 3 notification/fcm + 8 diary-originated
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

  test('diary-originated entry types are registered with mobile origin', () {
    final ids = diaryOriginatedEventTypes.map((t) => t.id).toSet();
    expect(ids, {
      'epistaxis_event',
      'no_epistaxis_event',
      'unknown_day_event',
      'participant_linked',
      'fcm_token_registered',
      'fcm_message_received',
      'setting_applied',
      'questionnaire_recall_acked',
    });
    for (final t in diaryOriginatedEventTypes) {
      expect(t.origin, EventOrigin.mobile);
    }
  });

  test('intentionally-absent ids are NOT registered as entry types', () {
    final registered = sharedEventCatalog.map((t) => t.id).toSet();
    for (final id in intentionallyAbsentIds) {
      expect(
        registered,
        isNot(contains(id)),
        reason: '$id must not be a distinct entry type (frozen surface)',
      );
    }
  });

  test(
    'catalog includes questionnaire_recall_notice (portal) and _acked (mobile)',
    () {
      // Verifies: DIARY-DEV-shared-events-catalog (catalog admits the recall round-trip events)
      final byId = {for (final e in sharedEventCatalog) e.id: e};
      expect(byId['questionnaire_recall_notice']?.origin, EventOrigin.portal);
      expect(byId['questionnaire_recall_acked']?.origin, EventOrigin.mobile);
    },
  );
}
