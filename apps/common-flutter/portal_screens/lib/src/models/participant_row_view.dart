import 'package:flutter/foundation.dart';

/// Display status of a participant row (Figma: Participant Summary).
///
/// Refines the lifecycle status the wiring layer derives from
/// `participant_record` with the linking-code expiry split (Code
/// Pending vs Expired — same lifecycle state, different urgency).
enum ParticipantRowStatus {
  notConnected('Not Connected'),
  codePending('Code Pending'),
  expired('Code Expired'),
  linkedAwaitingStart('Linked / Awaiting Start'),
  trialActive('Trial Active'),
  disconnected('Disconnected'),
  notParticipating('Not Participating'),
  unknown('Unknown');

  const ParticipantRowStatus(this.label);
  final String label;
}

/// The single context-dependent Action-column button (Figma: one primary
/// affordance per row; everything else lives in the overflow menu).
enum ParticipantPrimaryAction {
  linkParticipant('Link Participant'),
  showLinkingCode('Show Linking Code'),
  regenerateCode('Regenerate Code'),
  startTrial('Start Trial'),
  manageQuestionnaires('Manage Questionnaires'),
  reconnect('Reconnect'),
  reactivate('Reactivate'),
  none('');

  const ParticipantPrimaryAction(this.label);
  final String label;
}

/// Secondary lifecycle actions offered through the row's overflow menu.
enum ParticipantMenuAction {
  showCode('Show Linking Code'),
  disconnect('Disconnect'),
  reconnect('Reconnect'),
  markNotParticipating('Mark Not Participating'),
  reactivate('Reactivate');

  const ParticipantMenuAction(this.label);
  final String label;
}

/// Status filter tabs above the participants table (Figma order).
enum ParticipantStatusFilter {
  all('all', 'All users'),
  notConnected('not-connected', 'Not connected'),
  active('active', 'Active'),
  inactive('inactive', 'Inactive');

  const ParticipantStatusFilter(this.key, this.label);
  final String key;
  final String label;

  static ParticipantStatusFilter fromKey(String key) => values.firstWhere(
    (f) => f.key == key,
    orElse: () => ParticipantStatusFilter.all,
  );
}

/// One participants-table row. The wiring layer joins `participant_record`
/// with `sites_index` (site name), `linking_codes` (expiry split) and
/// `questionnaire_instance` (ready-to-review marker) and hands the
/// resolved snapshot here.
@immutable
class ParticipantRowView {
  const ParticipantRowView({
    required this.id,
    required this.siteName,
    required this.status,
    this.hasReadyToReview = false,
    this.menuActions = const <ParticipantMenuAction>[],
  });

  /// Participant id (rendered monospace, e.g. `001-1002567`).
  final String id;

  /// Resolved site display name (falls back to the site id upstream).
  final String siteName;

  final ParticipantRowStatus status;

  /// True when any of this participant's questionnaires awaits review —
  /// renders the bell marker next to the id.
  final bool hasReadyToReview;

  /// Lifecycle actions for the row's overflow menu (the state machine's
  /// legal set minus the primary action), resolved by the wiring layer.
  final List<ParticipantMenuAction> menuActions;
}

/// The Action-column affordance for a row status. Single source for the
/// status -> primary-button mapping (Figma's Action column).
// Implements: CAL-GUI-participant-dashboard-configuration/F — the per-status
// primary-Action column (Disconnected -> Reconnect, Not Participating ->
// Reactivate).
ParticipantPrimaryAction primaryActionFor(
  ParticipantRowStatus status,
) => switch (status) {
  ParticipantRowStatus.notConnected => ParticipantPrimaryAction.linkParticipant,
  ParticipantRowStatus.codePending => ParticipantPrimaryAction.showLinkingCode,
  ParticipantRowStatus.expired => ParticipantPrimaryAction.regenerateCode,
  ParticipantRowStatus.linkedAwaitingStart =>
    ParticipantPrimaryAction.startTrial,
  ParticipantRowStatus.trialActive =>
    ParticipantPrimaryAction.manageQuestionnaires,
  ParticipantRowStatus.disconnected => ParticipantPrimaryAction.reconnect,
  ParticipantRowStatus.notParticipating => ParticipantPrimaryAction.reactivate,
  ParticipantRowStatus.unknown => ParticipantPrimaryAction.none,
};

/// Whether [status] falls under [filter] (drives the tabs + their counts).
bool statusMatchesFilter(
  ParticipantRowStatus status,
  ParticipantStatusFilter filter,
) => switch (filter) {
  ParticipantStatusFilter.all => true,
  ParticipantStatusFilter.notConnected =>
    status == ParticipantRowStatus.notConnected ||
        status == ParticipantRowStatus.codePending ||
        status == ParticipantRowStatus.expired,
  ParticipantStatusFilter.active =>
    status == ParticipantRowStatus.linkedAwaitingStart ||
        status == ParticipantRowStatus.trialActive,
  ParticipantStatusFilter.inactive =>
    status == ParticipantRowStatus.disconnected ||
        status == ParticipantRowStatus.notParticipating,
};
