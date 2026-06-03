// Verifies: DIARY-PRD-action-inventory/A+C  (ACT-QST-002)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final minter = SerialFlowTokenMinter();
  final action = CallBackQuestionnaireAction(flowTokenMinter: minter);
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
    expect(action.name, 'ACT-QST-002');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-QST-002']),
    );
    expect(action.idempotency, Idempotency.required);
  });

  test('parseInput requires siteId + instanceId + reason, trims them', () {
    expect(
      () => action.parseInput(<String, Object?>{
        'siteId': 's1',
        'instanceId': 'qi-1',
        // missing reason
      }),
      throwsFormatException,
    );
    final input = action.parseInput(<String, Object?>{
      'siteId': ' s1 ',
      'instanceId': ' qi-1 ',
      'reason': ' duplicated entry ',
    });
    expect(input.siteId, 's1');
    expect(input.instanceId, 'qi-1');
    expect(input.reason, 'duplicated entry');
  });

  test('validate rejects blank reason', () {
    expect(
      () => action.validate(
        const CallBackQuestionnaireInput(
          siteId: 's1',
          instanceId: 'qi-1',
          reason: '',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('scopeFor binds the site scope', () {
    final perm = portalPermissionsByActId['ACT-QST-002']!;
    final scope = action.scopeFor(
      perm,
      const CallBackQuestionnaireInput(
        siteId: 's1',
        instanceId: 'qi-1',
        reason: 'error',
      ),
    );
    expect(scope, isA<BoundScope>());
    expect((scope! as BoundScope).class_, 'site');
    expect((scope as BoundScope).value, 's1');
  });

  test(
    'execute emits questionnaire_called_back with reason and flowToken',
    () async {
      final a = CallBackQuestionnaireAction(
        flowTokenMinter: SerialFlowTokenMinter(start: 5),
      );
      final r = await a.execute(
        const CallBackQuestionnaireInput(
          siteId: 's1',
          instanceId: 'qi-1',
          reason: 'data entry error',
        ),
        ctx,
      );
      expect(r.events.map((e) => e.entryType), ['questionnaire_called_back']);
      final e = r.events.single;
      expect(e.aggregateType, 'questionnaire_instance');
      expect(e.aggregateId, 'qi-1');
      expect(e.flowToken, isNotNull);
      expect(e.data['reason'], 'data entry error');
      expect(e.data['by'], 'sc-1');
      expect(r.result.instanceId, 'qi-1');
    },
  );
}
