// Implements: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';

import '../../portal_permissions.dart';

class AssignSiteInput {
  AssignSiteInput({
    required this.userId,
    required this.sites,
    // Phase 2: previousSites is caller-supplied; Phase 2 reads from a projection.
    required this.previousSites,
  });
  final String userId;
  final List<String> sites;
  final List<String> previousSites;
}

class AssignSiteResult {
  const AssignSiteResult({required this.userId});
  final String userId;
  Map<String, Object?> toJson() => <String, Object?>{'userId': userId};
}

/// ACT-USR-008: assign sites to a staff user account. Emits user_sites_changed;
/// if the change narrows authz (a site is removed), also emits
/// user_sessions_revoked to invalidate existing sessions.
class AssignSiteAction extends Action<AssignSiteInput, AssignSiteResult> {
  AssignSiteAction();

  @override
  String get name => 'ACT-USR-008';

  @override
  String get description =>
      'Assign sites to a staff user. Emits user_sites_changed; also emits '
      'user_sessions_revoked when authz is narrowed (a site is removed).';

  @override
  Set<Permission> get permissions => <Permission>{
    portalPermissionsByActId['ACT-USR-008']!,
  };

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  AssignSiteInput parseInput(Map<String, Object?> raw) {
    final userId = raw['userId'];
    if (userId is! String) {
      throw const FormatException('AssignSiteAction expects {userId}: String');
    }
    final rawSites = raw['sites'];
    if (rawSites is! List || !rawSites.every((dynamic e) => e is String)) {
      throw const FormatException(
        'AssignSiteAction: sites must be a List<String>',
      );
    }
    final rawPreviousSites = raw['previousSites'];
    if (rawPreviousSites is! List ||
        !rawPreviousSites.every((dynamic e) => e is String)) {
      throw const FormatException(
        'AssignSiteAction: previousSites must be a List<String>',
      );
    }
    return AssignSiteInput(
      userId: userId.trim(),
      sites: List<String>.from(rawSites),
      previousSites: List<String>.from(rawPreviousSites),
    );
  }

  @override
  void validate(AssignSiteInput input) {
    if (input.userId.trim().isEmpty) {
      throw ArgumentError.value(input.userId, 'userId', 'must be non-empty');
    }
  }

  @override
  Future<ExecutionResult<AssignSiteResult>> execute(
    AssignSiteInput input,
    ActionContext ctx,
  ) async {
    final events = <EventDraft>[
      EventDraft(
        aggregateType: 'portal_user',
        aggregateId: input.userId,
        entryType: 'user_sites_changed',
        eventType: 'user_sites_changed',
        data: <String, Object?>{
          'before': input.previousSites,
          'after': input.sites,
          'changed_by': ctx.principal.id,
        },
      ),
    ];
    // Narrowing: a site was removed → authz narrows → revoke sessions.
    final narrowed = input.previousSites
        .toSet()
        .difference(input.sites.toSet())
        .isNotEmpty;
    if (narrowed) {
      events.add(
        EventDraft(
          aggregateType: 'portal_user',
          aggregateId: input.userId,
          entryType: 'user_sessions_revoked',
          eventType: 'user_sessions_revoked',
          data: <String, Object?>{
            'reason_kind': 'authz_narrowed',
            'by': ctx.principal.id,
          },
        ),
      );
    }
    return ExecutionResult<AssignSiteResult>(
      result: AssignSiteResult(userId: input.userId),
      events: events,
    );
  }
}
