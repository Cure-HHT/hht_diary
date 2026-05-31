// Implements: DIARY-DEV-shared-events-catalog/A
//
// The cross-wire controlled vocabulary for an entry's `changeReason` (frozen +
// extended 2026-05-30). No free text — both the diary and the portal validate
// against this closed set so the audit trail aggregates over a fixed vocabulary.
library;

/// Reasons a finalized entry was changed or tombstoned.
enum DiaryChangeReason {
  /// Participant revised an existing entry.
  edited,

  /// A correction to previously-entered data.
  corrected,

  /// Portal/site withdrew the entry (e.g. a recalled questionnaire).
  portalWithdrawn,

  /// Participant deleted an entry recorded by mistake.
  enteredInError,

  /// Participant deleted a duplicate entry.
  duplicate;

  /// The wire value (kebab-case), e.g. `portal-withdrawn`.
  String get wire => switch (this) {
    DiaryChangeReason.edited => 'edited',
    DiaryChangeReason.corrected => 'corrected',
    DiaryChangeReason.portalWithdrawn => 'portal-withdrawn',
    DiaryChangeReason.enteredInError => 'entered-in-error',
    DiaryChangeReason.duplicate => 'duplicate',
  };

  /// Parses a wire value; returns null if not in the closed set.
  static DiaryChangeReason? fromWire(String value) {
    for (final r in DiaryChangeReason.values) {
      if (r.wire == value) return r;
    }
    return null;
  }
}

/// The closed set of valid `changeReason` wire values.
final Set<String> changeReasonWireValues = DiaryChangeReason.values
    .map((r) => r.wire)
    .toSet();
