// Implements: DIARY-PRD-action-inventory/A+C  (ACT-PAT-001 Link Participant; scoped)
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class LinkParticipantInput {
  const LinkParticipantInput({
    required this.siteId,
    required this.participantId,
    required this.linkingCode,
    required this.expiresAt,
  });
  final String siteId;
  final String participantId;
  final String linkingCode;
  final String expiresAt;
}

class LinkParticipantResult {
  const LinkParticipantResult({required this.participantId});
  final String participantId;
  Map<String, Object?> toJson() => <String, Object?>{
    'participantId': participantId,
  };
}

/// ACT-PAT-001: issue a linking code so a participant can associate their
/// device with this trial site. Emits `participant_linking_code_issued`.
class LinkParticipantAction
    extends Action<LinkParticipantInput, LinkParticipantResult> {
  LinkParticipantAction();

  @override
  String get name => 'ACT-PAT-001';

  @override
  String get description =>
      'Issue a linking code to associate a participant device with this site. '
      'Emits participant_linking_code_issued.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-PAT-001']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  LinkParticipantInput parseInput(Map<String, Object?> raw) {
    final siteId = raw['siteId'];
    final participantId = raw['participantId'];
    final linkingCode = raw['linkingCode'];
    final expiresAt = raw['expiresAt'];
    if (siteId is! String ||
        participantId is! String ||
        linkingCode is! String ||
        expiresAt is! String) {
      throw const FormatException(
        'LinkParticipantAction expects {siteId, participantId, linkingCode, expiresAt}: String',
      );
    }
    return LinkParticipantInput(
      siteId: siteId.trim(),
      participantId: participantId.trim(),
      linkingCode: linkingCode.trim(),
      expiresAt: expiresAt.trim(),
    );
  }

  @override
  void validate(LinkParticipantInput input) {
    if (input.siteId.isEmpty) {
      throw ArgumentError.value(input.siteId, 'siteId', 'must be non-empty');
    }
    if (input.participantId.isEmpty) {
      throw ArgumentError.value(
        input.participantId,
        'participantId',
        'must be non-empty',
      );
    }
    if (input.linkingCode.isEmpty) {
      throw ArgumentError.value(
        input.linkingCode,
        'linkingCode',
        'must be non-empty',
      );
    }
    if (input.expiresAt.isEmpty) {
      throw ArgumentError.value(
        input.expiresAt,
        'expiresAt',
        'must be non-empty',
      );
    }
  }

  @override
  ScopeValue? scopeFor(Permission perm, LinkParticipantInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

  @override
  Future<ExecutionResult<LinkParticipantResult>> execute(
    LinkParticipantInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<LinkParticipantResult>(
      result: LinkParticipantResult(participantId: input.participantId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'participant',
          aggregateId: input.participantId,
          entryType: 'participant_linking_code_issued',
          eventType: 'participant_linking_code_issued',
          data: <String, Object?>{
            'linking_code': input.linkingCode,
            'generated_by': ctx.principal.id,
            'expires_at': input.expiresAt,
            'purpose': 'link',
          },
        ),
      ],
    );
  }
}
