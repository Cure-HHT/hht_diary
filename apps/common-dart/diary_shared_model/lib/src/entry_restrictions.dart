// Implements: DIARY-PRD-entry-time-restrictions/A+E+F+G+J+L+M
//
// Shared pure decision for the time-based entry gate, so the diary's app-side
// submit guard AND the diary-server's ingest re-validation apply the SAME rule
// (anti-drift). Thresholds come from the sponsor settings projection; `now` and
// the event's local-midnight are supplied by the caller (timezone-aware).
library;

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

/// Sponsor-configurable time thresholds (from the settings projection). A null
/// threshold means that check is not configured for the deployment.
class EntryRestrictionConfig {
  const EntryRestrictionConfig({
    this.justificationThreshold,
    this.lockThreshold,
    this.trialStart,
  });

  /// Elapsed time from event-date midnight after which a justification is required.
  final Duration? justificationThreshold;

  /// Elapsed time from event-date midnight after which the date is fully locked.
  final Duration? lockThreshold;

  /// Trial Start date (local midnight). The lock applies only to event dates on
  /// or after this (assertion M); null disables that qualifier.
  final DateTime? trialStart;
}

/// Decides the [EntryGate] for an entry whose event date is [eventLocalMidnight]
/// (00:00 in the participant's local timezone), evaluated at [now], under
/// [config]. Pure and deterministic.
EntryGate entryGateForDate({
  required DateTime eventLocalMidnight,
  required DateTime now,
  required EntryRestrictionConfig config,
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
