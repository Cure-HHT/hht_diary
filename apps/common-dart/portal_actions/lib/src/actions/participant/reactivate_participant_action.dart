// Implements: DIARY-PRD-action-inventory/A+C  (ACT-PAT-006 Reactivate Participant; scoped)
// Implements: DIARY-DEV-shared-events-catalog/D  (flowToken carries no cleartext secret)
import 'package:event_sourcing/event_sourcing.dart';

import '../../flow_token_minter.dart';
import '../../linking_code_generator.dart';
import '../../portal_permissions.dart';

class ReactivateParticipantInput {
  const ReactivateParticipantInput({
    required this.siteId,
    required this.participantId,
    required this.reason,
  });
  final String siteId;
  final String participantId;
  final String reason;
}

class ReactivateParticipantResult {
  const ReactivateParticipantResult({
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

/// ACT-PAT-006: reactivate a not-participating participant and issue a new
/// linking code. Emits `participant_reactivated` then
/// `participant_linking_code_issued`, both sharing a single flowToken. Mints a
/// flowToken correlating this fact with the Phase-2 participant-notification
/// subscriber that emits notification_sent.
class ReactivateParticipantAction
    extends Action<ReactivateParticipantInput, ReactivateParticipantResult> {
  ReactivateParticipantAction({
    required this.flowTokenMinter,
    this.linkingPrefix = 'XX',
    this.sponsorResolverKey = '',
  });
  final FlowTokenMinter flowTokenMinter;

  /// Sponsor prefix for generated codes; injected at server boot from
  /// SPONSOR_LINKING_PREFIX (default 'XX').
  final String linkingPrefix;

  /// Per-sponsor HMAC key for check chars; injected from SPONSOR_RESOLVER_KEY.
  final String sponsorResolverKey;

  @override
  String get name => 'ACT-PAT-006';

  @override
  String get description =>
      'Reactivate a not-participating participant and issue a new linking code. '
      'Emits participant_reactivated + participant_linking_code_issued.';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-PAT-006']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  ReactivateParticipantInput parseInput(Map<String, Object?> raw) {
    final siteId = raw['siteId'];
    final participantId = raw['participantId'];
    final reason = raw['reason'];
    if (siteId is! String || participantId is! String || reason is! String) {
      throw const FormatException(
        'ReactivateParticipantAction expects {siteId, participantId, reason}: String',
      );
    }
    return ReactivateParticipantInput(
      siteId: siteId.trim(),
      participantId: participantId.trim(),
      reason: reason.trim(),
    );
  }

  @override
  void validate(ReactivateParticipantInput input) {
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
    if (input.reason.isEmpty) {
      throw ArgumentError.value(input.reason, 'reason', 'must be non-empty');
    }
  }

  @override
  ScopeValue? scopeFor(Permission perm, ReactivateParticipantInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

  // Implements: DIARY-DEV-linking-code-lifecycle/A — generate the code +
  //   72h expiry server-side (deterministic from ctx.requestStartedAt) and emit
  //   the full participant_linking_code_issued contract.
  @override
  Future<ExecutionResult<ReactivateParticipantResult>> execute(
    ReactivateParticipantInput input,
    ActionContext ctx,
  ) async {
    final flowToken = flowTokenMinter.next(stream: 'PAT');
    final code = generateLinkingCode(
      prefix: linkingPrefix,
      sponsorKey: sponsorResolverKey,
    );
    final expiresAt = ctx.requestStartedAt
        .toUtc()
        .add(const Duration(hours: 72))
        .toIso8601String();
    return ExecutionResult<ReactivateParticipantResult>(
      result: ReactivateParticipantResult(
        participantId: input.participantId,
        linkingCode: code,
        expiresAt: expiresAt,
      ),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'participant',
          aggregateId: input.participantId,
          entryType: 'participant_reactivated',
          eventType: 'participant_reactivated',
          flowToken: flowToken,
          data: <String, Object?>{
            'reason': input.reason,
            'by': ctx.principal.id,
          },
        ),
        // purpose 'reconnect' (the code's function is device reconnection); the
        // reactivation context is carried by the co-emitted participant_reactivated
        // event sharing this flowToken — distinct from ACT-PAT-004's participant_reconnected.
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
      ],
    );
  }
}
