// Verifies: DIARY-DEV-participant-status-projection/B
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/participant_status.dart';

void main() {
  test('entryType maps to status', () {
    expect(
      statusFromEntryType('participant_synced_from_edc'),
      ParticipantStatus.notConnected,
    );
    expect(
      statusFromEntryType('participant_linking_code_issued'),
      ParticipantStatus.pending,
    );
    expect(
      statusFromEntryType('participant_linking_code_used'),
      ParticipantStatus.connected,
      reason: 'the /link code redemption is the connect signal',
    );
    expect(
      statusFromEntryType('participant_linked'),
      ParticipantStatus.connected,
    );
    expect(
      statusFromEntryType('participant_trial_started'),
      ParticipantStatus.trialActive,
    );
    expect(
      statusFromEntryType('participant_disconnected'),
      ParticipantStatus.disconnected,
    );
    expect(
      statusFromEntryType('participant_reconnected'),
      ParticipantStatus.pending,
    );
    expect(
      statusFromEntryType('participant_marked_not_participating'),
      ParticipantStatus.notParticipating,
    );
    expect(
      statusFromEntryType('participant_reactivated'),
      ParticipantStatus.pending,
    );
    expect(statusFromEntryType('something_else'), ParticipantStatus.unknown);
  });
  test('effectiveParticipantStatus upgrades a re-linked started trial', () {
    // First link, trial not yet started -> Connected (Start Trial offered).
    expect(
      effectiveParticipantStatus(
        'participant_linking_code_used',
        trialStarted: false,
      ),
      ParticipantStatus.connected,
    );
    // Reactivated + re-linked with the original started_at preserved -> Trial
    // Active, so Start Trial is NOT re-offered (re-running it would overwrite
    // the original trial-start date / sync watermark).
    expect(
      effectiveParticipantStatus(
        'participant_linking_code_used',
        trialStarted: true,
      ),
      ParticipantStatus.trialActive,
    );
    // Non-connected states are unaffected by a preserved started_at.
    expect(
      effectiveParticipantStatus(
        'participant_marked_not_participating',
        trialStarted: true,
      ),
      ParticipantStatus.notParticipating,
    );
    expect(
      effectiveParticipantStatus('participant_reactivated', trialStarted: true),
      ParticipantStatus.pending,
    );
    expect(
      effectiveParticipantStatus(
        'participant_disconnected',
        trialStarted: true,
      ),
      ParticipantStatus.disconnected,
    );
  });
  test('enabledActions per state', () {
    expect(enabledActions(ParticipantStatus.notConnected), {
      ParticipantAction.issueLinkingCode,
    });
    expect(enabledActions(ParticipantStatus.pending), {
      ParticipantAction.showCode,
    });
    expect(enabledActions(ParticipantStatus.connected), {
      ParticipantAction.startTrial,
      ParticipantAction.disconnect,
      ParticipantAction.showCode,
    });
    expect(enabledActions(ParticipantStatus.trialActive), {
      ParticipantAction.disconnect,
      ParticipantAction.showCode,
    });
    expect(enabledActions(ParticipantStatus.disconnected), {
      ParticipantAction.reconnect,
      ParticipantAction.markNotParticipating,
      ParticipantAction.showCode,
    });
    expect(enabledActions(ParticipantStatus.notParticipating), {
      ParticipantAction.reactivate,
    });
    expect(enabledActions(ParticipantStatus.unknown), <ParticipantAction>{});
  });
}
