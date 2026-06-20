// Implements: DIARY-PRD-action-inventory/A+C  (ACT-PAT-001 Link Participant; scoped)
import 'package:event_sourcing/event_sourcing.dart';

import '../../linking_code_generator.dart';
import '../../portal_permissions.dart';

class LinkParticipantInput {
  const LinkParticipantInput({
    required this.siteId,
    required this.participantId,
  });
  final String siteId;
  final String participantId;
}

class LinkParticipantResult {
  const LinkParticipantResult({
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

/// Validity window for an issued linking code. Single source for the
/// expiry the action stamps and for read-only surfaces that report it
/// (the portal's GET /config/study).
const Duration linkingCodeTtl = Duration(hours: 72);

/// ACT-PAT-001: issue a linking code so a participant can associate their
/// device with this trial site. Emits `participant_linking_code_issued`.
class LinkParticipantAction
    extends Action<LinkParticipantInput, LinkParticipantResult> {
  LinkParticipantAction({
    this.linkingPrefix = 'XX',
    this.sponsorDiscoveryKey = '',
  });

  /// Sponsor prefix for generated codes; injected at server boot from
  /// SPONSOR_LINKING_PREFIX (default 'XX').
  final String linkingPrefix;

  /// Per-sponsor HMAC key for check chars; injected from SPONSOR_DISCOVERY_KEY.
  final String sponsorDiscoveryKey;

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
    if (siteId is! String || participantId is! String) {
      throw const FormatException(
        'LinkParticipantAction expects {siteId, participantId}: String',
      );
    }
    return LinkParticipantInput(
      siteId: siteId.trim(),
      participantId: participantId.trim(),
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
  }

  @override
  ScopeValue? scopeFor(Permission perm, LinkParticipantInput input) =>
      perm.scopeClass == 'site'
      ? BoundScope(class_: 'site', value: input.siteId)
      : null;

  // Implements: DIARY-DEV-linking-code-lifecycle/A — generate the code +
  //   72h expiry server-side (deterministic from ctx.requestStartedAt) and emit
  //   the full participant_linking_code_issued contract.
  @override
  Future<ExecutionResult<LinkParticipantResult>> execute(
    LinkParticipantInput input,
    ActionContext ctx,
  ) async {
    final code = generateLinkingCode(
      prefix: linkingPrefix,
      sponsorKey: sponsorDiscoveryKey,
    );
    final expiresAt = ctx.requestStartedAt
        .toUtc()
        .add(linkingCodeTtl)
        .toIso8601String();
    return ExecutionResult<LinkParticipantResult>(
      result: LinkParticipantResult(
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
          data: <String, Object?>{
            'linking_code': code,
            'participant_id': input.participantId,
            'site_id': input.siteId,
            'generated_by': ctx.principal.id,
            'expires_at': expiresAt,
            'purpose': 'link',
            'status': 'active',
            'mobile_linking_status': 'linking_in_progress',
          },
        ),
      ],
    );
  }
}
