// Verifies: DIARY-PRD-action-inventory/A+C  (ACT-QST-003)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final action = LockQuestionnaireAction();
  final ctx = ActionContext(
    principal: Principal.user(
      userId: 'sc-1',
      roles: {'SiteCoordinator'},
      activeRole: 'SiteCoordinator',
    ),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2026, 5, 30),
  );

  test('declares permission + required idempotency', () {
    expect(action.name, 'ACT-QST-003');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-QST-003']),
    );
    expect(action.idempotency, Idempotency.required);
  });

  test('parseInput without edcExportRef succeeds; optional is null', () {
    final input = action.parseInput(<String, Object?>{
      'siteId': ' s1 ',
      'instanceId': ' qi-1 ',
    });
    expect(input.siteId, 's1');
    expect(input.instanceId, 'qi-1');
    expect(input.edcExportRef, isNull);
  });

  test('parseInput with edcExportRef succeeds', () {
    final input = action.parseInput(<String, Object?>{
      'siteId': 's1',
      'instanceId': 'qi-1',
      'edcExportRef': 'EDC-REF-001',
    });
    expect(input.edcExportRef, 'EDC-REF-001');
  });

  test('parseInput throws FormatException on missing required fields', () {
    expect(
      () => action.parseInput(<String, Object?>{
        'siteId': 's1',
        // missing instanceId
      }),
      throwsFormatException,
    );
  });

  test('validate rejects blank siteId', () {
    expect(
      () => action.validate(
        const LockQuestionnaireInput(siteId: '', instanceId: 'qi-1'),
      ),
      throwsArgumentError,
    );
  });

  test('validate rejects blank instanceId', () {
    expect(
      () => action.validate(
        const LockQuestionnaireInput(siteId: 's1', instanceId: ''),
      ),
      throwsArgumentError,
    );
  });

  test('scopeFor binds the site scope', () {
    final perm = portalPermissionsByActId['ACT-QST-003']!;
    final scope = action.scopeFor(
      perm,
      const LockQuestionnaireInput(siteId: 's1', instanceId: 'qi-1'),
    );
    expect(scope, isA<BoundScope>());
    expect((scope! as BoundScope).class_, 'site');
    expect((scope as BoundScope).value, 's1');
  });

  test(
    'execute emits questionnaire_locked with finalized_by; no flowToken',
    () async {
      final r = await action.execute(
        const LockQuestionnaireInput(
          siteId: 's1',
          instanceId: 'qi-1',
          edcExportRef: 'EDC-REF-001',
        ),
        ctx,
      );
      expect(r.events.map((e) => e.entryType), ['questionnaire_locked']);
      final e = r.events.single;
      expect(e.aggregateType, 'questionnaire_instance');
      expect(e.aggregateId, 'qi-1');
      expect(e.flowToken, isNull);
      expect(e.data['finalized_by'], 'sc-1');
      expect(e.data['edc_export_ref'], 'EDC-REF-001');
      // No cycle / terminal close supplied -> both null.
      expect(e.data['cycle'], isNull);
      expect(e.data['end_event'], isNull);
      expect(r.result.instanceId, 'qi-1');
    },
  );

  test('execute without edcExportRef sets edc_export_ref to null', () async {
    final r = await action.execute(
      const LockQuestionnaireInput(siteId: 's1', instanceId: 'qi-2'),
      ctx,
    );
    final e = r.events.single;
    expect(e.data['edc_export_ref'], isNull);
  });

  test('parseInput captures cycle + endEvent (trimmed)', () {
    final input = action.parseInput(<String, Object?>{
      'siteId': 's1',
      'instanceId': 'qi-1',
      'cycle': ' Cycle 2 Day 1 ',
      'endEvent': ' end_of_treatment ',
    });
    expect(input.cycle, 'Cycle 2 Day 1');
    expect(input.endEvent, 'end_of_treatment');
  });

  test('parseInput leaves cycle + endEvent null when absent/non-String', () {
    final input = action.parseInput(<String, Object?>{
      'siteId': 's1',
      'instanceId': 'qi-1',
      'cycle': 42,
    });
    expect(input.cycle, isNull);
    expect(input.endEvent, isNull);
  });

  test('execute with a cycle records cycle + null end_event', () async {
    final r = await action.execute(
      const LockQuestionnaireInput(
        siteId: 's1',
        instanceId: 'qi-3',
        cycle: 'Cycle 2 Day 1',
      ),
      ctx,
    );
    final e = r.events.single;
    expect(e.data['cycle'], 'Cycle 2 Day 1');
    expect(e.data['end_event'], isNull);
  });

  test(
    'execute with end_of_treatment records the terminal end_event',
    () async {
      final r = await action.execute(
        const LockQuestionnaireInput(
          siteId: 's1',
          instanceId: 'qi-4',
          cycle: 'Cycle 3 Day 1',
          endEvent: 'end_of_treatment',
        ),
        ctx,
      );
      final e = r.events.single;
      expect(e.data['end_event'], 'end_of_treatment');
      expect(e.data['cycle'], 'Cycle 3 Day 1');
    },
  );

  test('validate rejects an invalid endEvent', () {
    expect(
      () => action.validate(
        const LockQuestionnaireInput(
          siteId: 's1',
          instanceId: 'qi-1',
          endEvent: 'end_of_universe',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('validate accepts a valid terminal endEvent', () {
    expect(
      () => action.validate(
        const LockQuestionnaireInput(
          siteId: 's1',
          instanceId: 'qi-1',
          endEvent: 'end_of_study',
        ),
      ),
      returnsNormally,
    );
  });

  test('validate rejects an empty cycle string', () {
    expect(
      () => action.validate(
        const LockQuestionnaireInput(
          siteId: 's1',
          instanceId: 'qi-1',
          cycle: '',
        ),
      ),
      throwsArgumentError,
    );
  });
}
