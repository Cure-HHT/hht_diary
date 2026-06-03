// Verifies: DIARY-PRD-action-inventory/A+C  (ACT-QST-001)
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  final minter = SerialFlowTokenMinter();
  final action = SendQuestionnaireAction(flowTokenMinter: minter);
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
    expect(action.name, 'ACT-QST-001');
    expect(
      action.permissions,
      contains(portalPermissionsByActId['ACT-QST-001']),
    );
    expect(action.idempotency, Idempotency.required);
  });

  test('parseInput with only required fields succeeds; optionals are null', () {
    final input = action.parseInput(<String, Object?>{
      'siteId': ' s1 ',
      'instanceId': ' qi-1 ',
      'participantId': ' p1 ',
      'questionnaireType': ' PHQ9 ',
    });
    expect(input.siteId, 's1');
    expect(input.instanceId, 'qi-1');
    expect(input.participantId, 'p1');
    expect(input.questionnaireType, 'PHQ9');
    expect(input.schemaVersion, isNull);
    expect(input.contentVersion, isNull);
    expect(input.guiVersion, isNull);
    expect(input.translationVersion, isNull);
    expect(input.studyEvent, isNull);
    expect(input.cycleOrdinal, isNull);
  });

  test('parseInput with all optional fields succeeds', () {
    final input = action.parseInput(<String, Object?>{
      'siteId': 's1',
      'instanceId': 'qi-1',
      'participantId': 'p1',
      'questionnaireType': 'PHQ9',
      'schemaVersion': '1.0',
      'contentVersion': '2.0',
      'guiVersion': '3.0',
      'translationVersion': '4.0',
      'studyEvent': 'baseline',
      'cycleOrdinal': 2,
    });
    expect(input.schemaVersion, '1.0');
    expect(input.contentVersion, '2.0');
    expect(input.guiVersion, '3.0');
    expect(input.translationVersion, '4.0');
    expect(input.studyEvent, 'baseline');
    expect(input.cycleOrdinal, 2);
  });

  test('parseInput throws FormatException on missing required fields', () {
    expect(
      () => action.parseInput(<String, Object?>{
        'siteId': 's1',
        'instanceId': 'qi-1',
        'participantId': 'p1',
        // missing questionnaireType
      }),
      throwsFormatException,
    );
    expect(
      () => action.parseInput(<String, Object?>{
        'siteId': 's1',
        'instanceId': 'qi-1',
        // missing participantId
        'questionnaireType': 'PHQ9',
      }),
      throwsFormatException,
    );
  });

  test('parseInput throws FormatException on non-int cycleOrdinal', () {
    expect(
      () => action.parseInput(<String, Object?>{
        'siteId': 's1',
        'instanceId': 'qi-1',
        'participantId': 'p1',
        'questionnaireType': 'PHQ9',
        'cycleOrdinal': 'not-an-int',
      }),
      throwsFormatException,
    );
  });

  test('validate rejects blank participantId', () {
    expect(
      () => action.validate(
        SendQuestionnaireInput(
          siteId: 's1',
          instanceId: 'qi-1',
          participantId: '',
          questionnaireType: 'PHQ9',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('validate rejects blank questionnaireType', () {
    expect(
      () => action.validate(
        SendQuestionnaireInput(
          siteId: 's1',
          instanceId: 'qi-1',
          participantId: 'p1',
          questionnaireType: '',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('scopeFor binds the site scope', () {
    final perm = portalPermissionsByActId['ACT-QST-001']!;
    final scope = action.scopeFor(
      perm,
      SendQuestionnaireInput(
        siteId: 's1',
        instanceId: 'qi-1',
        participantId: 'p1',
        questionnaireType: 'PHQ9',
      ),
    );
    expect(scope, isA<BoundScope>());
    expect((scope! as BoundScope).class_, 'site');
    expect((scope as BoundScope).value, 's1');
  });

  test(
    'execute emits questionnaire_assigned with QST flowToken; result exposes flowToken',
    () async {
      final a = SendQuestionnaireAction(
        flowTokenMinter: SerialFlowTokenMinter(start: 3),
      );
      final r = await a.execute(
        SendQuestionnaireInput(
          siteId: 's1',
          instanceId: 'qi-1',
          participantId: 'p1',
          questionnaireType: 'PHQ9',
          studyEvent: 'baseline',
        ),
        ctx,
      );
      expect(r.events.map((e) => e.entryType), ['questionnaire_assigned']);
      final e = r.events.single;
      expect(e.aggregateType, 'questionnaire_instance');
      expect(e.aggregateId, 'qi-1');
      expect(e.flowToken, matches(RegExp(r'^QST\d{6}$')));
      expect(e.data['participant_id'], 'p1');
      expect(e.data['assigned_by'], 'sc-1');
      expect(e.data['study_event'], 'baseline');
      expect(e.data['schema_version'], isNull);
      expect(e.data['cycle_ordinal'], isNull);
      expect(r.result.instanceId, 'qi-1');
      expect(r.result.flowToken, e.flowToken);
    },
  );
}
