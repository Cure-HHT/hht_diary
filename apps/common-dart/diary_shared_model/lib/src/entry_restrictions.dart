// Implements: DIARY-PRD-entry-time-restrictions/A+E+F+G+J+L+M
//
// Shared pure decision for the time-based entry gate, so the diary's app-side
// submit guard AND the diary-server's ingest re-validation apply the SAME rule
// (anti-drift). Thresholds come from the sponsor settings projection; `now` and
// the event's local-midnight are supplied by the caller (timezone-aware).
library;

import 'settings.dart';

/// The gate verdict for creating/editing/deleting an entry on a given day.
enum EntryGate {
  /// No restriction — save freely.
  allowed,

  /// Past the Justification Threshold (but not the Lock Threshold): the
  /// participant must select an Entry Justification before saving.
  requiresJustification,

  /// Past the Lock Threshold: no create/edit/delete permitted for that date.
  locked,
}

/// Sponsor-configurable time thresholds (from the settings projection) that
/// drive [entryGateForDate]. A null threshold means that check is not
/// configured for the deployment.
class EntryGateRules {
  const EntryGateRules({
    this.justificationThreshold,
    this.lockThreshold,
    this.trialStart,
  });

  /// Derives the rules from the folded settings map. Clinical thresholds are
  /// sponsor settings (integer hours); [trialStart] comes from the
  /// participant-lifecycle projection over `participant_trial_started`, NOT
  /// from settings. Pure and deterministic.
  factory EntryGateRules.fromSettings(
    Map<String, SettingPayload> settings, {
    required DateTime? trialStart,
  }) {
    Duration? hours(String key) {
      final v = settings[key]?.value;
      return v is int ? Duration(hours: v) : null;
    }

    return EntryGateRules(
      justificationThreshold: hours(justificationThresholdHoursKey),
      lockThreshold: hours(lockThresholdHoursKey),
      trialStart: trialStart,
    );
  }

  /// Elapsed time from event-date midnight after which a justification is required.
  final Duration? justificationThreshold;

  /// Elapsed time from event-date midnight after which the date is fully locked.
  final Duration? lockThreshold;

  /// Trial Start date (local midnight). The lock applies only to event dates on
  /// or after this (assertion M); null disables that qualifier.
  final DateTime? trialStart;

  @override
  bool operator ==(Object other) =>
      other is EntryGateRules &&
      other.justificationThreshold == justificationThreshold &&
      other.lockThreshold == lockThreshold &&
      other.trialStart == trialStart;

  @override
  int get hashCode =>
      Object.hash(justificationThreshold, lockThreshold, trialStart);
}

/// Decides the [EntryGate] for an entry whose event date is [eventLocalMidnight]
/// (00:00 in the participant's local timezone), evaluated at [now], under
/// [config]. Pure and deterministic.
EntryGate entryGateForDate({
  required DateTime eventLocalMidnight,
  required DateTime now,
  required EntryGateRules config,
}) {
  // L: when neither threshold is configured, apply no restrictions.
  if (config.justificationThreshold == null && config.lockThreshold == null) {
    return EntryGate.allowed;
  }
  final elapsed = now.difference(eventLocalMidnight);

  // M: the lock applies only to event dates on/after Trial Start.
  final lockApplies =
      config.lockThreshold != null &&
      (config.trialStart == null ||
          !eventLocalMidnight.isBefore(config.trialStart!));
  // J holds (lock >= justification), so checking lock first is correct.
  if (lockApplies && elapsed > config.lockThreshold!) {
    return EntryGate.locked;
  }
  if (config.justificationThreshold != null &&
      elapsed > config.justificationThreshold!) {
    return EntryGate.requiresJustification;
  }
  return EntryGate.allowed;
}

/// The full set of configurable clinical entry rules, derived from the folded
/// settings. Combines the time-window [gate] (justification/lock — shared with
/// the diary-server's ingest re-validation via [entryGateForDate]) with the
/// recording-flow flags (duration-reasonableness confirmations + review screen).
///
/// Every field defaults to "no restriction": absent keys ⇒ a permissive
/// [EntryGateRules], confirmations off, review screen off. The same keys can be
/// written by the participant (`source: user`, voluntary) or by the sponsor
/// (`source: sponsor, locked`) — the derivation is source-agnostic.
class ClinicalRules {
  const ClinicalRules({
    this.gate = const EntryGateRules(),
    this.shortDurationConfirm = false,
    this.longDurationConfirm = false,
    this.longDurationThresholdMinutes = 240,
    this.useReviewScreen = false,
    this.lockedKeys = const <String>{},
  });

  /// Derives the rules from the folded settings map. [trialStart] (for the gate's
  /// lock qualifier) comes from the participant-lifecycle projection, NOT
  /// settings; pass null when unknown (the lock then applies to all dates past
  /// its threshold). Pure and deterministic.
  factory ClinicalRules.fromSettings(
    Map<String, SettingPayload> settings, {
    required DateTime? trialStart,
  }) {
    bool boolOf(String key, {required bool fallback}) {
      final v = settings[key]?.value;
      return v is bool ? v : fallback;
    }

    int intOf(String key, {required int fallback}) {
      final v = settings[key]?.value;
      return v is int ? v : fallback;
    }

    return ClinicalRules(
      gate: EntryGateRules.fromSettings(settings, trialStart: trialStart),
      shortDurationConfirm: boolOf(shortDurationConfirmKey, fallback: false),
      longDurationConfirm: boolOf(longDurationConfirmKey, fallback: false),
      longDurationThresholdMinutes: intOf(
        longDurationThresholdMinutesKey,
        fallback: 240,
      ),
      useReviewScreen: boolOf(useReviewScreenKey, fallback: false),
      lockedKeys: <String>{
        for (final e in settings.entries)
          if (e.value.locked) e.key,
      },
    );
  }

  /// Time-window gate (justification/lock thresholds + trial-start qualifier).
  final EntryGateRules gate;

  /// Confirm before saving an implausibly short nosebleed (≤ 1 minute).
  final bool shortDurationConfirm;

  /// Confirm before saving a nosebleed longer than [longDurationThresholdMinutes].
  final bool longDurationConfirm;

  /// Threshold (minutes) above which [longDurationConfirm] triggers.
  final int longDurationThresholdMinutes;

  /// Show the review step before saving a completed entry.
  final bool useReviewScreen;

  /// Setting keys currently locked by the sponsor (read-only to the participant
  /// while participating). A user-settable rule whose key is in here must be
  /// shown read-only and not written.
  final Set<String> lockedKeys;

  /// Whether [key] is sponsor-locked (read-only to the participant).
  bool isLocked(String key) => lockedKeys.contains(key);

  @override
  bool operator ==(Object other) =>
      other is ClinicalRules &&
      other.gate == gate &&
      other.shortDurationConfirm == shortDurationConfirm &&
      other.longDurationConfirm == longDurationConfirm &&
      other.longDurationThresholdMinutes == longDurationThresholdMinutes &&
      other.useReviewScreen == useReviewScreen &&
      other.lockedKeys.length == lockedKeys.length &&
      other.lockedKeys.containsAll(lockedKeys);

  @override
  int get hashCode => Object.hash(
    gate,
    shortDurationConfirm,
    longDurationConfirm,
    longDurationThresholdMinutes,
    useReviewScreen,
    Object.hashAllUnordered(lockedKeys),
  );
}
