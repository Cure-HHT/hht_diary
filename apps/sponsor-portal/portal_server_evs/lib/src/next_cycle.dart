// Implements: DIARY-BASE-questionnaire-cycle-tracking/A+B+C+D
// Implements: DIARY-BASE-questionnaire-coordinator-workflow/A
// Implements: DIARY-BASE-questionnaire-finalization/E

// Pure next-cycle computation for the questionnaire send-orchestration
// endpoint.
//
// EVS actions cannot read projections mid-execute, so cycle computation is
// performed by the server's send-orchestration endpoint, which reads
// questionnaire_instance view rows and calls computeNextCycle.
//
// The caller is responsible for pre-filtering [existing] to exclude
// tombstoned (called-back) instances before passing them here.

/// Sealed result type returned by [computeNextCycle].
sealed class NextCycleResult {
  const NextCycleResult();
}

/// A send is allowed and the [studyEvent] has been determined (either
/// auto-computed or accepted from the caller's [requestedStudyEvent]).
/// [studyEvent] is null only when cycle tracking is disabled and no
/// study_event applies.
class NextCycleAuto extends NextCycleResult {
  const NextCycleAuto(this.studyEvent);

  final String? studyEvent;
}

/// No prior cycles exist and the sponsor configuration requires the Study
/// Coordinator to pick a Starting Cycle.
///
/// Implements: DIARY-BASE-questionnaire-cycle-tracking/C
class NextCycleNeedsSelection extends NextCycleResult {
  const NextCycleNeedsSelection();
}

/// No further questionnaires of this type may be sent right now.
///
/// Causes: an active (non-finalized) instance already exists (duplicate-open
/// guard), the single-use quota is exhausted when cycle tracking is disabled,
/// or the requested study_event duplicates a finalized cycle.
class NextCycleBlocked extends NextCycleResult {
  const NextCycleBlocked(this.reason);

  final String reason;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Formats cycle number [n] (>= 1) as the canonical study-event string.
String formatCycle(int n) => 'Cycle $n Day 1';

/// Parses the cycle number from a canonical study-event string.
/// Returns null when [studyEvent] is null or does not match the pattern.
int? parseCycleNumber(String? studyEvent) {
  if (studyEvent == null) return null;
  final match = RegExp(r'^Cycle ([1-9]\d*) Day 1$').firstMatch(studyEvent);
  if (match == null) return null;
  return int.parse(match.group(1)!);
}

// ---------------------------------------------------------------------------
// Core function
// ---------------------------------------------------------------------------

/// Computes the next-cycle result for a (participant, questionnaire-type) pair.
///
/// [existing] — all non-tombstoned questionnaire_instance view rows for this
///   (participant, type) pair. Each row must contain at least:
///   - `'entryType'`: a String event-type tag; rows where this equals
///     `'questionnaire_locked'` (or its frozen legacy alias
///     `'questionnaire_finalized'`, from pre-CUR-1539 logs) are treated as
///     locked/finalized; all others are treated as open/active.
///   - `'study_event'`: a String? cycle label (e.g. `'Cycle 2 Day 1'`) or null.
///
/// [cycleTrackingEnabled] — sponsor setting: whether Cycle values are assigned.
/// [requireInitialCycleSelection] — sponsor setting: whether the SC must pick
///   the Starting Cycle on first send.
/// [requestedStudyEvent] — optional Cycle label explicitly requested by the
///   caller (the SC has already selected or confirmed a cycle in the UI).
// Implements: DIARY-BASE-questionnaire-cycle-tracking/A+B+C+D
NextCycleResult computeNextCycle({
  required List<Map<String, Object?>> existing,
  required bool cycleTrackingEnabled,
  required bool requireInitialCycleSelection,
  required String? requestedStudyEvent,
}) {
  // CUR-1539: `questionnaire_finalized` is the frozen legacy alias of
  // `questionnaire_locked` (pre-rename event logs fold to rows carrying it).
  const lockedEntryTypes = {'questionnaire_locked', 'questionnaire_finalized'};
  final finalized = [
    for (final r in existing)
      if (lockedEntryTypes.contains(r['entryType'])) r,
  ];
  final open = [
    for (final r in existing)
      if (!lockedEntryTypes.contains(r['entryType'])) r,
  ];

  // DIARY-BASE-questionnaire-coordinator-workflow/A:
  // At most one active questionnaire of this type per participant.
  if (open.isNotEmpty) {
    return const NextCycleBlocked(
      'An active questionnaire of this type already exists for the participant.',
    );
  }

  // DIARY-BASE-questionnaire-finalization/E: a terminal close (End of Treatment
  // / End of Study) permanently blocks further sends of this type for this
  // participant. This applies regardless of cycle tracking, and takes
  // precedence over the single-use quota and the cycle auto-increment below.
  // Implements: DIARY-BASE-questionnaire-finalization/E
  final terminallyClosed = finalized.any((r) => r['end_event'] != null);
  if (terminallyClosed) {
    return const NextCycleBlocked(
      'This questionnaire type has been permanently closed '
      '(End of Treatment / End of Study) for this participant.',
    );
  }

  // DIARY-BASE-questionnaire-cycle-tracking/I+single-use:
  // When cycle tracking is disabled, the type is single-use.
  if (!cycleTrackingEnabled) {
    if (finalized.isNotEmpty) {
      return const NextCycleBlocked('Questionnaire already completed.');
    }
    return const NextCycleAuto(null);
  }

  // Determine the highest finalized Cycle N from the existing rows.
  // Terminal cycles (End of Treatment / End of Study) carry a non-null
  // `end_event` and are handled by the terminal-close guard above (which has
  // already returned NextCycleBlocked), so any remaining finalized rows here
  // are non-terminal cycle finalizes whose study_event parses to a Cycle N.
  int maxCycle = 0;
  for (final r in finalized) {
    final n = parseCycleNumber(r['study_event'] as String?);
    if (n != null && n > maxCycle) maxCycle = n;
  }

  if (maxCycle > 0) {
    // DIARY-BASE-questionnaire-cycle-tracking/B:
    // No two finalized questionnaires may share the same Cycle value.
    if (requestedStudyEvent != null) {
      final alreadyFinalized = finalized.any(
        (r) => r['study_event'] == requestedStudyEvent,
      );
      if (alreadyFinalized) {
        return NextCycleBlocked(
          'A questionnaire for $requestedStudyEvent already exists.',
        );
      }
    }
    // DIARY-BASE-questionnaire-cycle-tracking/D: auto-increment.
    return NextCycleAuto(requestedStudyEvent ?? formatCycle(maxCycle + 1));
  }

  // No finalized cycle-N instances yet — first send for this type.
  if (requestedStudyEvent != null) {
    return NextCycleAuto(requestedStudyEvent);
  }
  // DIARY-BASE-questionnaire-cycle-tracking/C:
  if (requireInitialCycleSelection) {
    return const NextCycleNeedsSelection();
  }
  // DIARY-BASE-questionnaire-cycle-tracking/K (config default → Cycle 1 Day 1).
  return NextCycleAuto(formatCycle(1));
}
