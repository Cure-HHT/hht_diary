// Verifies: DIARY-GUI-questionnaire-portal-sent-workflow/S — the
//   QuestionnaireStatusSync coordinator mints record_questionnaire_finalized
//   EXACTLY ONCE for a finalized task, and does NOT mint it again on a second
//   reconcile when the questionnaire_status view already shows isFinalized.
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:clinical_diary/services/questionnaire_status_sync.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:trial_data_types/trial_data_types.dart';

Future<DiaryScopeRuntime> _boot() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'sync-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return bootstrapDiaryScope(
    backend: SembastBackend(database: db),
    deviceId: 'DEV-test',
    softwareVersion: 'clinical_diary@0.0.0-test',
    localUserId: 'P-test',
  );
}

Task _task(String id, {required String status}) => Task(
  id: id,
  taskType: TaskType.questionnaire,
  title: 'Test Questionnaire',
  createdAt: DateTime(2025, 10, 16),
  status: status,
);

/// Count `questionnaire_finalized` events for a given aggregate id by reading
/// the event store directly.
Future<int> _finalizedEventCount(
  DiaryScopeRuntime rt,
  String instanceId,
) async {
  final events = await rt.bundle.eventStore.backend.findEventsForAggregate(
    instanceId,
  );
  return events.where((e) => e.entryType == 'questionnaire_finalized').length;
}

void main() {
  // Verifies: DIARY-GUI-questionnaire-portal-sent-workflow/S
  test(
    'mints record_questionnaire_finalized once, not twice (idempotent)',
    () async {
      final rt = await _boot();

      final sync = QuestionnaireStatusSync(scope: rt.scope);

      // First reconcile: view is empty → should dispatch once.
      await sync.reconcile([_task('i1', status: 'finalized')]);

      // Second reconcile: view now shows i1 finalized → should dispatch zero.
      await sync.reconcile([_task('i1', status: 'finalized')]);

      // Exactly one questionnaire_finalized event for i1 in the store.
      final count = await _finalizedEventCount(rt, 'i1');
      expect(count, 1);

      await rt.dispose();
    },
  );

  test('ignores tasks whose status is not finalized', () async {
    final rt = await _boot();

    final sync = QuestionnaireStatusSync(scope: rt.scope);
    await sync.reconcile([_task('i2', status: 'sent')]);
    await sync.reconcile([_task('i2', status: 'ready_to_review')]);

    final count = await _finalizedEventCount(rt, 'i2');
    expect(count, 0);

    await rt.dispose();
  });

  test('mints for multiple distinct instances independently', () async {
    final rt = await _boot();

    final sync = QuestionnaireStatusSync(scope: rt.scope);
    await sync.reconcile([
      _task('inst-a', status: 'finalized'),
      _task('inst-b', status: 'finalized'),
    ]);

    expect(await _finalizedEventCount(rt, 'inst-a'), 1);
    expect(await _finalizedEventCount(rt, 'inst-b'), 1);

    await rt.dispose();
  });

  test(
    'within-call idempotency: same instance id twice mints exactly once',
    () async {
      final rt = await _boot();

      final sync = QuestionnaireStatusSync(scope: rt.scope);
      // Single reconcile call with two Task objects, same id 'dup-i1', both finalized.
      await sync.reconcile([
        _task('dup-i1', status: 'finalized'),
        _task('dup-i1', status: 'finalized'),
      ]);

      // Exactly one questionnaire_finalized event for dup-i1 in the store.
      final count = await _finalizedEventCount(rt, 'dup-i1');
      expect(count, 1);

      await rt.dispose();
    },
  );

  group('enableUnlock', () {
    test('with enableUnlock=false, ignores unlocked status', () async {
      final rt = await _boot();

      final sync = QuestionnaireStatusSync(scope: rt.scope);
      await sync.reconcile([_task('i3', status: 'unlocked')]);

      final events = await rt.bundle.eventStore.backend.findEventsForAggregate(
        'i3',
      );
      final unlocked = events.where(
        (e) => e.entryType == 'questionnaire_unlocked',
      );
      expect(unlocked.length, 0);

      await rt.dispose();
    });

    test(
      'with enableUnlock=true, mints record_questionnaire_unlocked once',
      () async {
        final rt = await _boot();

        final sync = QuestionnaireStatusSync(
          scope: rt.scope,
          enableUnlock: true,
        );

        // First reconcile: empty view → mint once.
        await sync.reconcile([_task('i4', status: 'unlocked')]);
        // Second reconcile: row present → mint zero.
        await sync.reconcile([_task('i4', status: 'unlocked')]);

        final events = await rt.bundle.eventStore.backend
            .findEventsForAggregate('i4');
        final unlocked = events.where(
          (e) => e.entryType == 'questionnaire_unlocked',
        );
        expect(unlocked.length, 1);

        await rt.dispose();
      },
    );
  });
}
