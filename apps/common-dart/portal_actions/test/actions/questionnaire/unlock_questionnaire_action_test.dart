// Verifies: DIARY-PRD-action-inventory/A+C  (ACT-QST-004)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final minter = SerialFlowTokenMinter();
  final action = UnlockQuestionnaireAction(flowTokenMinter: minter);
  final ctx = ActionContext(
    principal: Principal.user(
      userId: 'sc-1',
      roles: {'SiteCoordinator'},
      activeRole: 'SiteCoordinator',
    ),
    security: const SecurityDetails(),
    requestStartedAt: DateTime.utc(2026, 5, 30),
  );

  test('declares permission', () {
    expect(action.name, 'ACT-QST-004');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-QST-004']),
    );
    expect(action.idempotency, Idempotency.required);
  });

  test('parseInput requires siteId + instanceId, trims them', () {
    expect(
      () => action.parseInput(<String, Object?>{
        'siteId': 's1',
        // missing instanceId
      }),
      throwsFormatException,
    );
    final input = action.parseInput(<String, Object?>{
      'siteId': ' s1 ',
      'instanceId': ' qi-1 ',
    });
    expect(input.siteId, 's1');
    expect(input.instanceId, 'qi-1');
  });

  test('validate rejects blank siteId', () {
    expect(
      () => action.validate(
        const UnlockQuestionnaireInput(siteId: '', instanceId: 'qi-1'),
      ),
      throwsArgumentError,
    );
  });

  test('validate rejects blank instanceId', () {
    expect(
      () => action.validate(
        const UnlockQuestionnaireInput(siteId: 's1', instanceId: ''),
      ),
      throwsArgumentError,
    );
  });

  test('scopeFor binds the site scope', () {
    final perm = portalPermissionsByActId['ACT-QST-004']!;
    final scope = action.scopeFor(
      perm,
      const UnlockQuestionnaireInput(siteId: 's1', instanceId: 'qi-1'),
    );
    expect(scope, isA<BoundScope>());
    expect((scope! as BoundScope).class_, 'site');
    expect((scope as BoundScope).value, 's1');
  });

  test(
    'execute emits questionnaire_unlocked with flowToken and unlocked_by',
    () async {
      final a = UnlockQuestionnaireAction(
        flowTokenMinter: SerialFlowTokenMinter(start: 2),
      );
      final r = await a.execute(
        const UnlockQuestionnaireInput(siteId: 's1', instanceId: 'qi-1'),
        ctx,
      );
      expect(r.events.map((e) => e.entryType), ['questionnaire_unlocked']);
      final e = r.events.single;
      expect(e.aggregateType, 'questionnaire_instance');
      expect(e.aggregateId, 'qi-1');
      expect(e.flowToken, isNotNull);
      expect(e.data['unlocked_by'], 'sc-1');
      expect(r.result.instanceId, 'qi-1');
    },
  );
}
