// Pure participant linking-lifecycle status logic. The portal derives a
// participant's status from the latest lifecycle entryType stamped on the
// participant_record row, then gates the lifecycle action buttons by the
// per-state legal-action set. The pending -> connected transition fires when
// the device redeems its code at /link (participant_linking_code_used), which
// is the device confirming the link in the integrated device->portal flow;
// a mobile-originated participant_linked maps to the same connected state.
//
// Implements: DIARY-DEV-participant-status-projection/B

/// Linking-lifecycle status of a participant, derived from the latest
/// lifecycle entryType folded onto the participant_record row.
enum ParticipantStatus {
  notConnected('Not connected'),
  pending('Pending'),
  connected('Connected'),
  trialActive('Trial active'),
  disconnected('Disconnected'),
  notParticipating('Not participating'),
  unknown('Unknown');

  const ParticipantStatus(this.label);

  /// Human-readable label for display.
  final String label;
}

/// A lifecycle action the portal can take on a participant.
enum ParticipantAction {
  issueLinkingCode('Issue Linking Code'),
  showCode('Show Code'),
  startTrial('Start Trial'),
  disconnect('Disconnect'),
  reconnect('Reconnect'),
  markNotParticipating('Mark Not Participating'),
  reactivate('Reactivate');

  const ParticipantAction(this.label);

  /// Button label for display.
  final String label;
}

/// Maps the latest lifecycle entryType to a [ParticipantStatus]. Anything
/// unrecognised (including null) maps to [ParticipantStatus.unknown].
///
/// Implements: DIARY-DEV-participant-status-projection/B
ParticipantStatus statusFromEntryType(String? entryType) => switch (entryType) {
  'participant_synced_from_edc' => ParticipantStatus.notConnected,
  'participant_linking_code_issued' => ParticipantStatus.pending,
  // The device redeeming its code at /link IS the connect signal in the
  // integrated device->portal flow: the /link handler consumes the code
  // (participant_linking_code_used) and sets mobile_linking_status=connected.
  'participant_linking_code_used' => ParticipantStatus.connected,
  'participant_linked' => ParticipantStatus.connected,
  'participant_trial_started' => ParticipantStatus.trialActive,
  'participant_disconnected' => ParticipantStatus.disconnected,
  'participant_reconnected' => ParticipantStatus.pending,
  'participant_marked_not_participating' => ParticipantStatus.notParticipating,
  'participant_reactivated' => ParticipantStatus.pending,
  _ => ParticipantStatus.unknown,
};

/// The legal lifecycle actions for a participant in [status]. This is the
/// state machine: a button is enabled iff it is in the returned set.
///
/// Implements: DIARY-DEV-participant-status-projection/B
Set<ParticipantAction> enabledActions(ParticipantStatus status) =>
    switch (status) {
      ParticipantStatus.notConnected => {ParticipantAction.issueLinkingCode},
      ParticipantStatus.pending => {ParticipantAction.showCode},
      ParticipantStatus.connected => {
        ParticipantAction.startTrial,
        ParticipantAction.disconnect,
        ParticipantAction.showCode,
      },
      ParticipantStatus.trialActive => {
        ParticipantAction.disconnect,
        ParticipantAction.showCode,
      },
      ParticipantStatus.disconnected => {
        ParticipantAction.reconnect,
        ParticipantAction.markNotParticipating,
        ParticipantAction.showCode,
      },
      ParticipantStatus.notParticipating => {ParticipantAction.reactivate},
      ParticipantStatus.unknown => <ParticipantAction>{},
    };
