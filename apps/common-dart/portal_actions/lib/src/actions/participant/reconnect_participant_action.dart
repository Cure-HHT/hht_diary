// Implements: DIARY-PRD-action-inventory/A+C  (ACT-PAT-004 Reconnect Participant; scoped)
// Implements: DIARY-DEV-shared-events-catalog/D  (flowToken carries no cleartext secret)
import 'package:event_sourcing/event_sourcing.dart';

import '../../flow_token_minter.dart';
import '../../linking_code_generator.dart';
import '../../portal_permissions.dart';

class ReconnectParticipantInput {
  const ReconnectParticipantInput({
    required this.siteId,
    required this.participantId,
  });
  final String siteId;
  final String participantId;
}

class ReconnectParticipantResult {
  const ReconnectParticipantResult({
    required this.participantId,
    required this.linkingCode,
    required this.expiresAt,
  });
  final String participantId;
  final String linkingCode;
  final String expiresAt;
  Map<String, Object?> toJson() => <String, Object?>{
    'participantId': participantId,
    'linkingCode': linkingCode,
    'expiresAt': expiresAt,
  };
}

/// ACT-PAT-004: reconnect a participant after a disconnect, issuing a new
/// linking code. Emits `participant_linking_code_issued` then
/// `participant_reconnected`, both sharing a single flowToken. Mints a flowToken
/// correlating this fact with the Phase-2 participant-notification subscriber
/// that emits notification_sent.
class ReconnectParticipantAction
    extends Action<ReconnectParticipantInput, ReconnectParticipantResult> {
  ReconnectParticipantAction({
    required this.flowTokenMinter,
    this.linkingPrefix,
  });
  final FlowTokenMinter flowTokenMinter;

  /// Sponsor prefix for generated codes; falls back to
  /// [defaultSponsorLinkingPrefix] when null.
  final String? linkingPrefix;

  @override
  String get name => 'ACT-PAT-004';

  @override
  String get description =>
      'Reconnect a participant after a disconnect; issues a new linking code. '
      'Emits participant_linking_code_issued + participant_reconnected.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-PAT-004']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  ReconnectParticipantInput parseInput(Map<String, Object?> raw) {
    final siteId = raw['siteId'];
    final participantId = raw['participantId'];
    if (siteId is! String || participantId is! String) {
      throw const FormatException(
        'ReconnectParticipantAction expects {siteId, participantId}: String',
      );
    }
    return ReconnectParticipantInput(
      siteId: siteId.trim(),
      participantId: participantId.trim(),
    );
  }

  @override
  void validate(ReconnectParticipantInput input) {
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
  }

  @override
  ScopeValue? scopeFor(Permission perm, ReconnectParticipantInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

  // Implements: DIARY-DEV-linking-code-lifecycle/A — generate the code +
  //   72h expiry server-side (deterministic from ctx.requestStartedAt) and emit
  //   the full participant_linking_code_issued contract.
  @override
  Future<ExecutionResult<ReconnectParticipantResult>> execute(
    ReconnectParticipantInput input,
    ActionContext ctx,
  ) async {
    final flowToken = flowTokenMinter.next(stream: 'PAT');
    final code = generateLinkingCode(prefix: linkingPrefix);
    final expiresAt = ctx.requestStartedAt
        .toUtc()
        .add(const Duration(hours: 72))
        .toIso8601String();
    return ExecutionResult<ReconnectParticipantResult>(
      result: ReconnectParticipantResult(
        participantId: input.participantId,
        linkingCode: code,
        expiresAt: expiresAt,
      ),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'participant',
          aggregateId: input.participantId,
          entryType: 'participant_linking_code_issued',
          eventType: 'participant_linking_code_issued',
          flowToken: flowToken,
          data: <String, Object?>{
            'linking_code': code,
            'participant_id': input.participantId,
            'site_id': input.siteId,
            'generated_by': ctx.principal.id,
            'expires_at': expiresAt,
            'purpose': 'reconnect',
            'status': 'active',
            'mobile_linking_status': 'linking_in_progress',
          },
        ),
        EventDraft(
          aggregateType: 'participant',
          aggregateId: input.participantId,
          entryType: 'participant_reconnected',
          eventType: 'participant_reconnected',
          flowToken: flowToken,
          data: <String, Object?>{'by': ctx.principal.id},
        ),
      ],
    );
  }
}
