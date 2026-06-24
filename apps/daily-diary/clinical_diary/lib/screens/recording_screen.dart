import 'dart:async';

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:clinical_diary/read/diary_view_builder.dart';
import 'package:clinical_diary/scope/diary_participant_id.dart';
import 'package:clinical_diary/screens/overlap_compare_screen.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/settings/clinical_rules_scope.dart';
import 'package:clinical_diary/utils/app_page_route.dart';
import 'package:clinical_diary/utils/date_time_formatter.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/back_to_home_row.dart';
import 'package:clinical_diary/widgets/delete_confirmation_dialog.dart';
import 'package:clinical_diary/widgets/duration_confirmation_dialog.dart';
import 'package:clinical_diary/widgets/flash_highlight.dart';
import 'package:clinical_diary/widgets/intensity_picker.dart';
import 'package:clinical_diary/widgets/nosebleed_intensity.dart';
import 'package:clinical_diary/widgets/old_entry_justification_dialog.dart';
import 'package:clinical_diary/widgets/overlap_warning.dart';
import 'package:clinical_diary/widgets/time_picker_dial.dart';
import 'package:clinical_diary/widgets/timezone_picker.dart';
import 'package:diary_design_system/diary_design_system.dart';
import 'package:diary_shared_model/diary_shared_model.dart'
    show ClinicalRules, EntryGate, entryGateForDate;
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

/// Multi-step recording flow for creating, resuming, or editing a nosebleed
/// (`epistaxis_event`).
///
/// Reads (overlap detection) come from the live diary views via
/// [DiaryViewBuilder]; writes go through the diary Actions
/// (`record_epistaxis_event`, `edit_epistaxis_event`,
/// `checkpoint_epistaxis_event`, `delete_entry`) submitted through the scope's
/// `actionSubmitter`. The screen holds no authoritative state.
class RecordingScreen extends StatefulWidget {
  const RecordingScreen({
    super.key,
    this.existing,
    this.initialDate,
    this.fromOverlapResolution = false,
    this.saveTimeout = const Duration(seconds: 10),
  }) : assert(
         existing == null || initialDate == null,
         'Cannot specify both existing and initialDate',
       );

  /// The entry to edit or resume. `null` for a brand-new entry.
  final EpistaxisEntryView? existing;

  /// True when this screen was opened from the overlap-resolution flow (an Edit
  /// on the compare screen). A finalize that still overlaps then just pops back
  /// to that compare screen (which re-derives) instead of pushing a NEW one.
  final bool fromOverlapResolution;

  /// Preselected day for a NEW entry (calendar / yesterday banner). Ignored
  /// when [existing] is non-null.
  final DateTime? initialDate;

  /// CUR-1397: ceiling on how long a single action dispatch (the save path)
  /// is awaited before [_RecordingScreenState._submitAction] treats it as a
  /// failure. Without it a hung submit traps the user — the Back path
  /// (PopScope → _handleExit → _saveRecord) awaits the same call, so
  /// `canPop: false` never reaches `Navigator.pop`. 10s is generous for a
  /// local write (typically sub-100ms) while still bounding the back-out UX.
  /// Override in tests.
  final Duration saveTimeout;

  /// Default start time for a NEW recording. With no preselected day it is
  /// [now]; for a day preselected on the calendar it is **noon** of that day —
  /// not midnight, which made nudging the start time backwards (e.g. -5 min)
  /// wrap onto the previous day.
  static DateTime defaultStartTime(DateTime? initialDate, DateTime now) {
    if (initialDate == null) return now;
    return DateTime(initialDate.year, initialDate.month, initialDate.day, 12);
  }

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

// CUR-408: Removed notes step from recording flow
enum RecordingStep { startTime, intensity, endTime, complete }

/// A resolution the participant chose on the Resolution Screen but has not yet
/// confirmed. The choice is held — NOT written — so the Confirm Record step can
/// apply it atomically on the single confirming save (edit the survivor + delete
/// the [loserId]), and Back can re-open the Resolution Screen ([leftId]/[rightId]
/// both still exist) with nothing changed (CUR-1548 follow-up).
class _PendingResolution {
  const _PendingResolution({
    required this.leftId,
    required this.rightId,
    required this.loserId,
  });

  /// The original pair, re-pushed to the compare screen when Back re-opens it.
  final String leftId;
  final String rightId;

  /// The entry to tombstone when the resolution is confirmed.
  final String loserId;
}

class _RecordingScreenState extends State<RecordingScreen> {
  // The aggregate id of the entry being edited/resumed; null for a brand-new
  // entry until the first save mints one (and stores it back here).
  String? _aggregateId;

  // Whether the entry being edited is already finalized (data-complete). Drives
  // the back-out auto-save decision (never downgrade a finalized entry to a
  // checkpoint).
  bool _isComplete = false;

  // The start date/time shown in the summary, timepicker and clock.
  DateTime _startDateTime = DateTime.now();

  // The intensity shown in the summary and intensity display.
  NosebleedIntensity? _intensity;

  // The end date/time shown in the summary, timepicker and clock.
  DateTime? _endDateTime;

  // CUR-516: Selected timezone for start time (IANA, e.g. "America/Los_Angeles").
  String? _startTimeTimezone;

  // CUR-516: Selected timezone for end time (IANA).
  String? _endTimeTimezone;

  RecordingStep _currentStep = RecordingStep.startTime;
  bool _isSaving = false;

  // Latch: true once the participant has reached the Confirm Record (complete)
  // step. The overlap warning banner is informational during the initial
  // start→end pass, but on the Confirm Record screen — and when a summary chip
  // is tapped to edit a step from there — it stays hidden so the review/confirm
  // flow stays clean.
  bool _hasReachedConfirm = false;

  // CUR-464: Flash intensity field when user tries to set end time without it.
  bool _flashIntensity = false;

  // DIARY-PRD-entry-time-restrictions: Old entry justification if required.
  OldEntryJustification? _oldEntryJustification;

  // The event-sourced clinical rules (justification/lock thresholds + duration
  // confirmations + review screen), read reactively from ClinicalRulesScope in
  // didChangeDependencies.
  ClinicalRules _rules = const ClinicalRules();
  bool _initialStepSet = false;

  // A chosen-but-unconfirmed overlap resolution. While set, the Confirm Record
  // step is reviewing the result; the single confirming save applies it (edit
  // survivor + delete loser) and Back re-opens the Resolution Screen.
  _PendingResolution? _pendingResolution;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final existing = widget.existing;
    if (existing == null) {
      _aggregateId = null;
      _isComplete = false;
      _startDateTime = RecordingScreen.defaultStartTime(
        widget.initialDate,
        now,
      );
      // Leave _endDateTime null for new records - set when the user explicitly
      // sets it. The end time picker uses _startDateTime as default.
      _endDateTime = null;
      _intensity = null;
      _startTimeTimezone = null;
      _endTimeTimezone = null;
      _currentStep = RecordingStep.startTime;
    } else {
      _aggregateId = existing.aggregateId;
      _isComplete = existing.isComplete;
      _startDateTime = existing.startTime;
      _endDateTime = existing.endTime;
      _intensity = _toWidgetIntensity(existing.intensity);
      _startTimeTimezone = existing.startTimeZone;
      _endTimeTimezone = existing.endTimeZone;
      // The review-screen-dependent initial step is finalized in
      // didChangeDependencies, where ClinicalRulesScope is available.
      _currentStep = RecordingStep.startTime;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rules = ClinicalRulesScope.of(context);
    if (!_initialStepSet) {
      _initialStepSet = true;
      final existing = widget.existing;
      if (existing != null) {
        _currentStep = _getInitialStepForExisting(existing);
      }
    }
  }

  /// Maps the shared-model intensity (carried by [EpistaxisEntryView]) to the
  /// UI-only [NosebleedIntensity] used by the picker/summary. Both enums share
  /// identical value names, so the conversion is by enum-name.
  static NosebleedIntensity? _toWidgetIntensity(Object? shared) {
    if (shared == null) return null;
    return NosebleedIntensity.fromString((shared as Enum).name);
  }

  RecordingStep _getInitialStepForExisting(EpistaxisEntryView existing) {
    if (existing.intensity == null) {
      return RecordingStep.intensity;
    }
    if (existing.endTime == null) {
      return RecordingStep.endTime;
    }
    // For complete records: show review screen if enabled, otherwise start time.
    if (_rules.useReviewScreen) {
      return RecordingStep.complete;
    }
    return RecordingStep.startTime;
  }

  /// DIARY-PRD-entry-time-restrictions: the sponsor/user time-window gate for
  /// this entry's date, evaluated now against the event-sourced [ClinicalRules].
  // Implements: DIARY-PRD-entry-time-restrictions/A+E+L+M
  EntryGate get _entryGate => entryGateForDate(
    eventLocalMidnight: DateUtils.dateOnly(_startDateTime),
    now: DateTime.now(),
    config: _rules.gate,
  );

  /// Whether this date is fully locked (no create/edit/delete) — read-only.
  bool get _isLocked => _entryGate == EntryGate.locked;

  /// Whether old-entry justification is required and not yet provided.
  bool get _needsOldEntryJustification =>
      _entryGate == EntryGate.requiresJustification &&
      _oldEntryJustification == null;

  /// Whether short duration confirmation is needed.
  bool get _needsShortDurationConfirmation {
    if (!_rules.shortDurationConfirm) {
      return false;
    }
    final duration = _durationMinutes();
    return duration != null && duration <= 1;
  }

  /// Whether long duration confirmation is needed.
  bool get _needsLongDurationConfirmation {
    if (!_rules.longDurationConfirm) {
      return false;
    }
    final duration = _durationMinutes();
    return duration != null && duration > _rules.longDurationThresholdMinutes;
  }

  /// Run all validation checks before saving.
  /// Returns true if save should proceed, false if cancelled.
  Future<bool> _runValidationChecks() async {
    // DIARY-PRD-entry-time-restrictions: a locked date is read-only — never
    // save/create/edit. (Entry points keep the user out of here for locked
    // dates; this is the defense-in-depth backstop.)
    if (_isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        // TODO(i18n): localize (tracked with the other hardcoded strings).
        const SnackBar(
          content: Text('This date is locked and can no longer be changed.'),
        ),
      );
      return false;
    }

    // CUR-492: Reject end time that is before start time. Equal start/end is
    // permitted only when the sponsor enables shortDurationConfirm — the
    // confirmation dialog below is the gate. With shortDurationConfirm off,
    // equal start/end is also rejected here so the user sees the specific
    // "End time must be after start time" message rather than the generic
    // save-failure snackbar from a dispatcher rejection.
    if (_endDateTime != null) {
      final endsBeforeStart = _endDateTime!.isBefore(_startDateTime);
      final endsAtStart = _endDateTime!.isAtSameMomentAs(_startDateTime);
      if (endsBeforeStart || (endsAtStart && !_rules.shortDurationConfirm)) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.endTimeAfterStart)));
        return false;
      }
    }

    // DIARY-PRD-entry-time-restrictions: Old entry justification check.
    if (_needsOldEntryJustification) {
      final justification = await OldEntryJustificationDialog.show(
        context: context,
      );
      if (!mounted) {
        return false;
      }
      if (justification == null) {
        return false; // User cancelled
      }
      setState(() => _oldEntryJustification = justification);
    }

    // Short duration confirmation.
    if (_needsShortDurationConfirmation) {
      final confirmed = await DurationConfirmationDialog.show(
        context: context,
        type: DurationConfirmationType.short,
        durationMinutes: _durationMinutes() ?? 0,
      );
      if (!mounted) {
        return false;
      }
      if (!confirmed) {
        return false; // User chose to edit
      }
    }

    // Long duration confirmation.
    if (_needsLongDurationConfirmation) {
      final confirmed = await DurationConfirmationDialog.show(
        context: context,
        type: DurationConfirmationType.long,
        durationMinutes: _durationMinutes() ?? 0,
        thresholdMinutes: _rules.longDurationThresholdMinutes,
      );
      if (!mounted) {
        return false;
      }
      if (!confirmed) {
        return false; // User chose to edit
      }
    }

    return true;
  }

  /// CUR-488/CUR-583: Format the start time in the selected timezone.
  String _formatStartTime(String locale, AppLocalizations l10n) {
    final displayTime = _getDisplayedDateTime(
      _startDateTime,
      _startTimeTimezone,
    );
    return DateFormat.jm(locale).format(displayTime);
  }

  /// CUR-583: Format end time with day-offset suffix when the displayed dates
  /// differ from start.
  String _formatEndTime(String locale, AppLocalizations l10n) {
    if (_endDateTime == null) {
      return l10n.notSet;
    }

    final startDisplayTime = _getDisplayedDateTime(
      _startDateTime,
      _startTimeTimezone,
    );
    final endDisplayTime = _getDisplayedDateTime(
      _endDateTime!,
      _endTimeTimezone,
    );

    final timeStr = DateFormat.jm(locale).format(endDisplayTime);

    final startDate = DateUtils.dateOnly(startDisplayTime);
    final endDate = DateUtils.dateOnly(endDisplayTime);
    final dayDiff = endDate.difference(startDate).inDays;

    if (dayDiff == 1) {
      return '$timeStr (+1 day)';
    } else if (dayDiff > 1) {
      return '$timeStr (+$dayDiff days)';
    }

    return timeStr;
  }

  int? _durationMinutes() {
    if (_endDateTime == null) {
      return null;
    }
    return _endDateTime!.difference(_startDateTime).inMinutes;
  }

  /// Overlapping finalized epistaxis entries (as typed view-models) for the
  /// current candidate range, excluding the entry being edited.
  ///
  /// Before the participant sets an end time the entry is ONGOING — it spans
  /// from its start up to the present moment. Evaluating the candidate as
  /// `[start, now]` (rather than the start instant alone) makes the early
  /// warning surface CONSISTENTLY whenever an existing record falls anywhere in
  /// that span — including when the start time precedes an existing record that
  /// the ongoing event now runs into. The previous start-instant-only check
  /// missed that case, so the warning only appeared after the end time was set
  /// (CUR-1518 Issue 1). `now` is clamped to never precede the start (it cannot
  /// in production, since a future start is rejected) so the candidate range
  /// stays well-formed.
  // Implements: DIARY-DEV-reactive-read-path/A
  // Implements: DIARY-GUI-entry-overlap-resolution/A
  // Implements: DIARY-PRD-entry-overlap-resolution/A+C
  List<EpistaxisEntryView> _overlappingEvents(DiaryView view) {
    final now = DateTime.now();
    final candidateEnd =
        _endDateTime ?? (now.isAfter(_startDateTime) ? now : _startDateTime);
    final rows = overlappingEpistaxisEntries(
      view.finalizedRows,
      _startDateTime,
      candidateEnd,
      excludeAggregateId: _aggregateId,
    );
    return rows
        .map((r) => diaryEntryViewOf(r, isComplete: true))
        .whereType<EpistaxisEntryView>()
        .toList();
  }

  /// Builds the `EpistaxisEventPayload` JSON for the current screen state. The
  /// required start fields are always present; the optional end/intensity keys
  /// are omitted when unset so a checkpoint can carry just the start.
  Map<String, Object?> _buildPayload() {
    // When the participant hasn't explicitly picked a zone, the entry is in the
    // DEVICE's zone — store that IANA name, NOT 'UTC'. The stored offset comes
    // from the device-local _startDateTime, so a 'UTC' name here would disagree
    // with the offset (e.g. zone 'UTC' + offset '-07:00') and the renderer would
    // mis-relabel the wall-clock.
    final deviceZone = TimezoneService.instance.currentTimezone ?? 'UTC';
    final startIso = DateTimeFormatter.format(_startDateTime);
    final payload = <String, Object?>{
      'startTime': startIso,
      'startTimeZone': _startTimeTimezone ?? deviceZone,
      'startTimeUtcOffset': _utcOffsetOf(startIso, _startTimeTimezone),
      // Stamp the enrolled participant so the canonical `diary_entries` row can
      // be filtered by participant (epistaxis events use a fresh-UUID aggregate
      // id that does not embed it). Same id the action attributes the event to.
      'participantId': diaryParticipantId(context),
    };
    if (_endDateTime != null) {
      final endIso = DateTimeFormatter.format(_endDateTime!);
      payload['endTime'] = endIso;
      payload['endTimeZone'] =
          _endTimeTimezone ?? _startTimeTimezone ?? deviceZone;
      payload['endTimeUtcOffset'] = _utcOffsetOf(endIso, _endTimeTimezone);
    }
    if (_intensity != null) {
      payload['intensity'] = _intensity!.name;
    }
    return payload;
  }

  /// Derives the ISO UTC offset (e.g. `-05:00`) for a formatted timestamp.
  /// Prefers the offset embedded in [iso] (the screen formats wall-clock time
  /// with the device offset); falls back to computing it from the selected
  /// [timezone] when the embedded offset is absent.
  static String _utcOffsetOf(String iso, String? timezone) {
    final embedded = DateTimeFormatter.extractTimezoneOffset(iso);
    if (embedded != null && embedded != 'Z') return embedded;
    if (embedded == 'Z') return '+00:00';
    final mins = TimezoneConverter.getTimezoneOffsetMinutes(timezone);
    if (mins == null) return '+00:00';
    final sign = mins.isNegative ? '-' : '+';
    final h = (mins.abs() ~/ 60).toString().padLeft(2, '0');
    final m = (mins.abs() % 60).toString().padLeft(2, '0');
    return '$sign$h:$m';
  }

  /// Submits [actionName] with [rawInput] and returns the dispatched result's
  /// aggregate id (for actions that mint/return one), or null on failure.
  ///
  /// Surfaces a save-failure snackbar on any non-success outcome.
  Future<String?> _submitAction(
    String actionName,
    Map<String, Object?> rawInput,
  ) async {
    try {
      // CUR-1397: bound the dispatch so a hung submit can't trap the user.
      // Both the Save button and the Back path (PopScope → _handleExit →
      // _saveRecord) await this same call; on timeout fall through to the
      // failure handling below so callers un-trap and reset _isSaving.
      final result = await ReActionScope.of(context).actionSubmitter
          .submit(ActionSubmission(actionName: actionName, rawInput: rawInput))
          .timeout(widget.saveTimeout);
      switch (result) {
        case DispatchSuccess<Object?>(:final result):
          return result is String ? result : null;
        case DispatchIdempotencyHit<Object?>(:final cachedResult):
          return cachedResult is String ? cachedResult : null;
        default:
          break;
      }
    } on TimeoutException {
      // fall through to the shared failure path below
    }
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.failedToSave),
          duration: const Duration(seconds: 5),
        ),
      );
    }
    return null;
  }

  /// Save-decision table for a "Complete Record" tap (an explicit finalize).
  ///
  /// - new entry (`_aggregateId == null`)  -> `record_epistaxis_event`
  /// - existing entry                      -> `edit_epistaxis_event`
  ///
  /// Finalizing a resumed draft via `edit_epistaxis_event` on the SAME
  /// aggregate makes the incomplete projection self-remove the checkpoint (it
  /// tombstones on `finalized`).
  // Implements: DIARY-PRD-incomplete-entry-preservation/A+C
  // Implements: DIARY-GUI-epistaxis-record/A
  // Implements: DIARY-PRD-entry-time-restrictions/D
  // Implements: DIARY-DEV-action-write-path/A
  // Implements: DIARY-PRD-entry-overlap-resolution/C — an overlapping entry is
  //   allowed to save; the overlap is resolved afterwards from the home surface.
  Future<String?> _saveRecord() async {
    final shouldProceed = await _runValidationChecks();
    if (!shouldProceed) {
      return null;
    }

    setState(() => _isSaving = true);
    try {
      final payload = _buildPayload();
      final justification = _oldEntryJustification?.name;
      final String? newId;
      if (_aggregateId == null) {
        newId = await _submitAction('record_epistaxis_event', <String, Object?>{
          ...payload,
          'entryJustification': ?justification,
        });
      } else {
        newId = await _submitAction('edit_epistaxis_event', <String, Object?>{
          'aggregateId': _aggregateId,
          ...payload,
          'entryJustification': ?justification,
        });
      }
      if (newId == null) {
        return null; // _submitAction already surfaced the failure.
      }
      final savedId = newId;
      _aggregateId = savedId;
      if (!mounted) return newId;

      // CONFIRMING a chosen overlap resolution: the edit just submitted wrote the
      // survivor's reviewed/merged data; now apply the other half atomically by
      // tombstoning the discarded entry. Nothing was written until this single
      // confirm, so the resolution stayed reversible up to here (Back re-opened
      // the Resolution Screen). The overlap is resolved by this pair of actions,
      // so skip the conflict re-check (it would still see the not-yet-deleted
      // loser and loop the participant back — CUR-1548).
      final pending = _pendingResolution;
      if (pending != null) {
        await _submitAction('delete_entry', <String, Object?>{
          'aggregateId': pending.loserId,
          'entryType': 'epistaxis_event',
          'changeReason': 'duplicate',
        });
        _pendingResolution = null;
        if (mounted) Navigator.pop(context, savedId);
        return newId;
      }

      // Normal finalize: if this created/left an overlap, go STRAIGHT to the
      // side-by-side Resolution Screen, PUSHED on top of this recording screen
      // so Cancel/Back returns here, not to the Main Screen
      // (DIARY-GUI-entry-overlap-resolution/M, CUR-1518 Issue 4). When we were
      // ourselves opened from the overlap flow (an Edit on the compare screen)
      // just pop back — that compare screen re-derives or auto-pops.
      final conflict = widget.fromOverlapResolution
          ? null
          : _firstOverlapConflict();
      if (conflict != null) {
        await _resolveOverlap(conflict.aggregateId, savedId);
      } else {
        Navigator.pop(context, savedId);
      }
      return newId;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Opens the side-by-side Resolution Screen for the overlapping pair and, on
  /// the participant's choice, re-points the Confirm Record step at the SURVIVING
  /// entry. Every choice routes through this one Confirm Record step so the
  /// participant reviews + confirms exactly once, identically for all three
  /// options (DIARY-GUI-entry-overlap-resolution/J+K+M):
  ///   - Keep New: the new entry survives — adopting it runs the identical
  ///     render path as the other two.
  ///   - Keep Existing: the pre-existing entry survives.
  ///   - Merge: the pre-existing entry survives, pre-filled with the union span.
  ///
  /// The screen DEFERS all writes (`deferApplication`) and hands back the loser
  /// id; we hold it in [_pendingResolution] and apply it on the confirming save.
  /// Until then both entries still exist, so Back ([_handleExit]) re-opens this
  /// screen with nothing changed. Also reused by the Back path to re-open.
  Future<void> _resolveOverlap(String leftId, String rightId) async {
    final result = await Navigator.push<OverlapResolutionResult>(
      context,
      AppPageRoute<OverlapResolutionResult>(
        builder: (_) => OverlapCompareScreen(
          leftId: leftId,
          rightId: rightId,
          deferApplication: true,
        ),
      ),
    );
    if (!mounted) return;
    final survivor = result?.survivor;
    // Cancel/Back on the Resolution Screen returns null. Land on the recording
    // EDIT flow (the start/intensity/end steps), NOT the Confirm Record review —
    // so Back steps OUT of resolution toward editing instead of bouncing back to
    // the confirmation screen. Drop any pending choice; the overlap is still
    // unresolved, so the next back-out re-routes into resolution (CUR-1518's
    // "resolve or delete before leaving" still holds).
    if (survivor == null) {
      setState(() {
        _pendingResolution = null;
        _currentStep = RecordingStep.startTime;
      });
      return;
    }
    _adoptResolvedSurvivor(survivor, merged: result?.mergedPrefill);
    final loserId = result?.loserId;
    setState(() {
      _pendingResolution = loserId == null
          // Reactive (Edit-removed) resolution: nothing left to discard.
          ? null
          : _PendingResolution(
              leftId: leftId,
              rightId: rightId,
              loserId: loserId,
            );
    });
  }

  /// Re-points the Confirm Record step at the entry the participant chose to
  /// keep. Pulling its values into the screen fields means the final review
  /// shows the resulting data and the confirming save edits that LIVE aggregate.
  ///
  /// For Keep New / Keep Existing the fields come from the survivor's stored data
  /// (an unchanged review). For Merge, [merged] overrides them with the union
  /// span + max severity, so the single confirming save writes the merged record
  /// onto the surviving aggregate. No write happens here — the discard of the
  /// other entry is held in [_pendingResolution] and applied on confirm.
  // Implements: DIARY-GUI-entry-overlap-resolution/A+J+K
  // Implements: DIARY-PRD-entry-overlap-resolution/D
  void _adoptResolvedSurvivor(
    EpistaxisEntryView survivor, {
    OverlapMergePrefill? merged,
  }) {
    setState(() {
      _aggregateId = survivor.aggregateId;
      if (merged != null) {
        _isComplete = merged.endTime != null;
        _startDateTime = merged.startTime;
        _endDateTime = merged.endTime;
        _intensity = _toWidgetIntensity(merged.intensity);
        _startTimeTimezone = merged.startTimeZone;
        _endTimeTimezone = merged.endTimeZone;
      } else {
        _isComplete = survivor.isComplete;
        _startDateTime = survivor.startTime;
        _endDateTime = survivor.endTime;
        _intensity = _toWidgetIntensity(survivor.intensity);
        _startTimeTimezone = survivor.startTimeZone;
        _endTimeTimezone = survivor.endTimeZone;
      }
      _currentStep = RecordingStep.complete;
    });
  }

  void _goToStep(RecordingStep step) {
    setState(() => _currentStep = step);
  }

  /// CUR-464: Handle end time tap - flash intensity if not set, else navigate.
  void _handleEndTimeTap() {
    if (_intensity == null) {
      setState(() => _flashIntensity = true);
    } else {
      _goToStep(RecordingStep.endTime);
    }
  }

  /// CUR-583: Handle start time confirmation with future-time validation.
  // Implements: DIARY-PRD-entry-time-restrictions/D
  void _handleStartTimeConfirm(DateTime displayedTime) {
    final storedStartTime = TimezoneConverter.toStoredDateTime(
      displayedTime,
      _startTimeTimezone,
    );

    if (storedStartTime.isAfter(DateTime.now())) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.cannotSelectFutureTime)));
      return;
    }

    setState(() {
      _startDateTime = storedStartTime;
      // CUR-560: skip intensity if already set.
      _currentStep = _intensity != null
          ? RecordingStep.endTime
          : RecordingStep.intensity;
    });
  }

  void _handleIntensitySelect(NosebleedIntensity intensity) {
    setState(() {
      _intensity = intensity;
      _currentStep = RecordingStep.endTime;
    });
  }

  /// CUR-516/583: validate end time and (when no review screen) save.
  // Implements: DIARY-PRD-entry-time-restrictions/D
  Future<void> _handleEndTimeConfirm(DateTime displayedTime) async {
    final storedEndTime = TimezoneConverter.toStoredDateTime(
      displayedTime,
      _endTimeTimezone,
    );

    final endsBeforeStart = storedEndTime.isBefore(_startDateTime);
    final endsAtStart = storedEndTime.isAtSameMomentAs(_startDateTime);
    if (endsBeforeStart || (endsAtStart && !_rules.shortDurationConfirm)) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.endTimeAfterStart)));
      return;
    }

    if (storedEndTime.isAfter(DateTime.now())) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.cannotSelectFutureTime)));
      return;
    }

    setState(() {
      _endDateTime = storedEndTime;
    });

    // CUR-1518 Issue 3 (DIARY-GUI-entry-overlap-resolution/C): confirming an end
    // time that confirms an overlap routes STRAIGHT to the Resolution Screen,
    // rather than continuing the normal flow or waiting on a button. `_saveRecord`
    // persists the entry first (DIARY-PRD-entry-overlap-resolution/D) and then
    // pushes the compare screen. The Confirm Record step is staged underneath so
    // the participant lands on it for a final review once the conflict resolves.
    if (_firstOverlapConflict() != null) {
      if (_rules.useReviewScreen) {
        setState(() => _currentStep = RecordingStep.complete);
      }
      await _saveRecord();
      return;
    }

    // CUR-464: When useReviewScreen is false, save immediately and return.
    if (!_rules.useReviewScreen) {
      await _saveRecord();
      return;
    }

    setState(() {
      _currentStep = RecordingStep.complete;
    });
  }

  /// Delete pressed: tombstone the aggregate via `delete_entry`.
  // Implements: DIARY-PRD-incomplete-entry-preservation/A+C
  // Implements: DIARY-DEV-action-write-path/A
  Future<void> _handleDelete() async {
    if (_isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        // TODO(i18n): localize.
        const SnackBar(
          content: Text('This date is locked and can no longer be changed.'),
        ),
      );
      return;
    }
    final aggregateId = _aggregateId;
    if (aggregateId == null) {
      // Nothing persisted yet; just discard. The screen returns a String?
      // aggregate id (null = nothing saved) — NEVER a bool, or the typed
      // `Navigator.push<String?>` callers throw on the result.
      if (mounted) Navigator.pop<String?>(context, null);
      return;
    }
    await DeleteConfirmationDialog.show(
      context: context,
      onConfirmDelete: (String reason) async {
        await _submitAction('delete_entry', <String, Object?>{
          'aggregateId': aggregateId,
          'entryType': 'epistaxis_event',
          'changeReason': 'entered-in-error',
        });
        if (mounted) {
          Navigator.pop<String?>(context, null);
        }
      },
    );
  }

  /// Whether there are unsaved changes worth auto-saving on back-out.
  bool _hasUnsavedPartialRecord() {
    final existing = widget.existing;
    if (existing != null) {
      return _startDateTime != existing.startTime ||
          _endDateTime != existing.endTime ||
          _intensity != _toWidgetIntensity(existing.intensity);
    }
    // For new records, we have unsaved data unless we're at the complete step
    // (which has its own save button).
    return _currentStep != RecordingStep.complete;
  }

  /// Auto-save on back-out (DIARY-PRD-incomplete-entry-preservation).
  ///
  /// - editing an already-finalized entry (`_isComplete == true`) ->
  ///   `edit_epistaxis_event` (never downgrade to a checkpoint).
  /// - new or resumed draft (`!_isComplete`) -> `checkpoint_epistaxis_event`
  ///   (aggregateId may be null; the action mints one and returns it).
  // Implements: DIARY-PRD-incomplete-entry-preservation/A+C
  // Implements: DIARY-DEV-action-write-path/A
  Future<bool> _handleExit() async {
    // A locked date is read-only; never auto-save on back-out.
    if (_isLocked) {
      return true;
    }

    // A chosen-but-unconfirmed overlap resolution: Back re-opens the Resolution
    // Screen with BOTH entries intact (nothing was written yet), so the
    // participant can pick again. Do NOT auto-save and do NOT pop to the Main
    // Screen (DIARY-GUI-entry-overlap-resolution/M).
    final pending = _pendingResolution;
    if (pending != null) {
      await _resolveOverlap(pending.leftId, pending.rightId);
      return false;
    }

    // CUR-1518 Issue 4 (DIARY-GUI-entry-overlap-resolution/M): once an end time
    // confirms an overlap, the participant must resolve the conflict (or delete
    // the entry via the trash action) before leaving — they CANNOT slip back to
    // the Main Screen with a logically-impossible overlapping record. Route back
    // into the Resolution flow instead of popping. The compare screen is pushed
    // ON TOP, so this screen stays beneath it as the Confirm Record host.
    // (The Edit-from-compare case is exempt — backing out there belongs to the
    // compare screen above us, which re-derives or auto-pops.)
    if (!widget.fromOverlapResolution &&
        _endDateTime != null &&
        _firstOverlapConflict() != null) {
      await _saveRecord();
      return false;
    }

    if (!_hasUnsavedPartialRecord()) {
      return true;
    }

    final shouldProceed = await _runValidationChecks();
    if (!shouldProceed) {
      // Validation cancelled — stay on the screen.
      return false;
    }

    setState(() => _isSaving = true);
    try {
      final payload = _buildPayload();
      final String? newId;
      if (_isComplete) {
        newId = await _submitAction('edit_epistaxis_event', <String, Object?>{
          'aggregateId': _aggregateId,
          ...payload,
        });
      } else {
        newId = await _submitAction(
          'checkpoint_epistaxis_event',
          <String, Object?>{'aggregateId': _aggregateId, ...payload},
        );
      }
      if (newId == null) {
        // _submitAction surfaced the failure; allow the pop so the user isn't
        // trapped, mirroring the prior behavior.
        return true;
      }
      _aggregateId = newId;
      if (mounted) {
        Navigator.pop(context);
      }
      // We popped ourselves; tell PopScope not to pop again.
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DiaryViewBuilder(
      builder: (context, view) {
        _latestView = view;
        return _buildScaffold(context, view);
      },
    );
  }

  // The most recent DiaryView from the builder, captured so the imperative
  // finalize path can detect an overlap and route into the compare screen.
  DiaryView? _latestView;
  static final DiaryView _emptyView = DiaryView(
    finalized: const [],
    incomplete: const [],
  );

  /// The pre-existing finalized entry the current candidate overlaps, or null.
  /// Used at finalize to route straight into overlap resolution.
  EpistaxisEntryView? _firstOverlapConflict() {
    final overlaps = _overlappingEvents(_latestView ?? _emptyView);
    return overlaps.isEmpty ? null : overlaps.first;
  }

  Widget _buildScaffold(BuildContext context, DiaryView view) {
    final overlappingEvents = _overlappingEvents(view);
    final l10n = AppLocalizations.of(context);

    // Latch the confirm-reached flag (idempotent; no rebuild). Once set it
    // suppresses the overlap banner for the rest of this screen's life.
    if (_currentStep == RecordingStep.complete) _hasReachedConfirm = true;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleExit();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        // Figma 515-2320: the recording flow renders on a plain white page,
        // not the grey app-shell background.
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Header with back ("< Home") and delete buttons (Figma 682:2813)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BackToHomeRow(
                      onBack: () async {
                        final shouldPop = await _handleExit();
                        if (shouldPop && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    // Delete button — hidden on a locked (read-only) date.
                    // Figma 682:2821: exported trash glyph (Critical red).
                    if (!_isLocked)
                      IconButton(
                        onPressed: _handleDelete,
                        icon: Image.asset(
                          'assets/icons/figma/delete_record.png',
                          width: 26,
                          height: 26,
                          fit: BoxFit.contain,
                        ),
                        tooltip: l10n.deleteRecordTooltip,
                      ),
                  ],
                ),
              ),

              // DIARY-PRD-entry-time-restrictions: read-only lock notice.
              if (_isLocked) _buildLockBanner(),

              // Date title — plain centered text (Figma 515:3077), not editable
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  DateFormat(
                    'EEEE, MMM d',
                    Localizations.localeOf(context).languageCode,
                  ).format(_startDateTime),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    letterSpacing: -0.33,
                    color: Color(0xFF0A0A0A),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Summary bar
              _buildSummaryBar(l10n),

              const SizedBox(height: 24),

              // Overlap warning — informational only (no action). It surfaces as
              // soon as the start time indicates a potential overlap and stays
              // non-blocking so the participant keeps recording
              // (DIARY-GUI-entry-overlap-resolution/A+B). Resolution is triggered
              // automatically when the end time confirms the overlap, not from
              // this banner. Once the Confirm Record step is reached it stays
              // hidden (via _hasReachedConfirm) — including when a summary chip
              // is tapped to edit a step from there — so review stays clean.
              if (overlappingEvents.isNotEmpty && !_hasReachedConfirm)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: OverlapWarning(overlappingEntries: overlappingEvents),
                ),

              if (overlappingEvents.isNotEmpty && !_hasReachedConfirm)
                const SizedBox(height: 16),

              // Main content area. On a locked date the editing controls are
              // inert (read-only); the summary bar still navigates between the
              // read-only step views.
              Expanded(
                child: AbsorbPointer(
                  absorbing: _isLocked,
                  child: _buildCurrentStep(l10n),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Read-only banner shown when the entry's date is past the lock threshold.
  Widget _buildLockBanner() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              // TODO(i18n): localize.
              'This date is locked. Entries can be viewed but no longer added, '
              'edited, or deleted.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(AppLocalizations l10n) {
    final locale = Localizations.localeOf(context).languageCode;

    final timeZoneName =
        TimezoneService.instance.currentTimezone ?? DateTime.now().timeZoneName;
    final deviceTzAbbr = normalizeDeviceTimezone(timeZoneName);
    final startTzAbbr = _startTimeTimezone != null
        ? getTimezoneAbbreviation(
            _startTimeTimezone!,
            at: TimezoneConverter.toDisplayedDateTime(
              _startDateTime,
              _startTimeTimezone,
            ),
          )
        : null;
    final endTzAbbr = _endTimeTimezone != null
        ? getTimezoneAbbreviation(
            _endTimeTimezone!,
            at: TimezoneConverter.toDisplayedDateTime(
              _endDateTime ?? _startDateTime,
              _endTimeTimezone,
            ),
          )
        : null;

    final startDiffersFromDevice =
        startTzAbbr != null && startTzAbbr != deviceTzAbbr;
    final endDiffersFromDevice = endTzAbbr != null && endTzAbbr != deviceTzAbbr;
    final timezonesDiffer =
        startTzAbbr != null && endTzAbbr != null && startTzAbbr != endTzAbbr;

    final showStartTz = startDiffersFromDevice || timezonesDiffer;
    final showEndTz = endDiffersFromDevice || timezonesDiffer;

    // Figma 682:2993: light-gray card, equal-width segments separated by
    // hairline dividers; the active segment gets a white rounded chip.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECEEF0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // Start time
          Expanded(
            child: _buildSummaryItem(
              label: l10n.start,
              value: _formatStartTime(locale, l10n),
              subtitle: showStartTz ? startTzAbbr : null,
              isActive: _currentStep == RecordingStep.startTime,
              onTap: () => _goToStep(RecordingStep.startTime),
            ),
          ),

          _buildDivider(),

          // Intensity - wrapped in FlashHighlight for CUR-464
          Expanded(
            child: FlashHighlight(
              flash: _flashIntensity,
              highlightColor: Colors.orange,
              onFlashComplete: () {
                if (mounted) {
                  setState(() => _flashIntensity = false);
                }
              },
              builder: (context, highlightColor) => _buildSummaryItem(
                label: l10n.maxIntensity,
                value: _intensity != null
                    ? l10n.intensityName(_intensity!.name)
                    : l10n.selectIntensity,
                isActive: _currentStep == RecordingStep.intensity,
                onTap: () => _goToStep(RecordingStep.intensity),
                highlightColor: highlightColor,
              ),
            ),
          ),

          _buildDivider(),

          // End time - CUR-464: flash intensity if not set
          Expanded(
            child: _buildSummaryItem(
              label: l10n.end,
              value: _formatEndTime(locale, l10n),
              subtitle: showEndTz ? endTzAbbr : null,
              isActive: _currentStep == RecordingStep.endTime,
              onTap: _handleEndTimeTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required bool isActive,
    String? subtitle,
    VoidCallback? onTap,
    Color? highlightColor,
  }) {
    // Figma 682:2995: active segment is a white rounded chip; labels are
    // 12px Dark Grey, values 16px Medium Black regardless of active state.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: highlightColor ?? (isActive ? Colors.white : null),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 17 / 12,
                letterSpacing: -0.06,
                color: Color(0xFF54636A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 25.5 / 16,
                letterSpacing: -0.43,
                color: Color(0xFF04161E),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Color(0xFF54636A)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFFA4B9C2).withValues(alpha: 0.5),
    );
  }

  Widget _buildCurrentStep(AppLocalizations l10n) {
    switch (_currentStep) {
      case RecordingStep.startTime:
        return TimePickerDial(
          key: const ValueKey('start_time_picker'),
          title: l10n.nosebleedStart,
          initialTime: _getDisplayedDateTime(
            _startDateTime,
            _startTimeTimezone,
          ),
          initialTimezone: _startTimeTimezone,
          onConfirm: _handleStartTimeConfirm,
          onTimeChanged: _setStartDateTime,
          onTimezoneChanged: _handleStartTimezoneChanged,
          confirmLabel: l10n.setStartTime,
        );

      case RecordingStep.intensity:
        return IntensityPicker(
          key: const ValueKey('intensity_picker'),
          selectedIntensity: _intensity,
          onSelect: _handleIntensitySelect,
        );

      case RecordingStep.endTime:
        final endInitialTime = _endDateTime != null
            ? _getDisplayedDateTime(_endDateTime!, _endTimeTimezone)
            : _getDisplayedDateTime(_startDateTime, _startTimeTimezone);
        return TimePickerDial(
          key: const ValueKey('end_time_picker'),
          title: l10n.nosebleedEndTime,
          initialTime: endInitialTime,
          initialTimezone: _endTimeTimezone ?? _startTimeTimezone,
          onConfirm: _handleEndTimeConfirm,
          onTimeChanged: _setEndDateTime,
          onTimezoneChanged: _handleEndTimezoneChanged,
          confirmLabel: l10n.setEndTime,
        );

      case RecordingStep.complete:
        return _buildCompleteStep(l10n);
    }
  }

  /// CUR-583: Convert stored DateTime to displayed time for the selected tz.
  DateTime _getDisplayedDateTime(DateTime storedDateTime, String? timezone) {
    return TimezoneConverter.toDisplayedDateTime(storedDateTime, timezone);
  }

  void _setStartDateTime(DateTime displayedDateTime) {
    final storedTime = TimezoneConverter.toStoredDateTime(
      displayedDateTime,
      _startTimeTimezone,
    );
    setState(() {
      _startDateTime = storedTime;
    });
  }

  void _setEndDateTime(DateTime displayedDateTime) {
    final storedTime = TimezoneConverter.toStoredDateTime(
      displayedDateTime,
      _endTimeTimezone,
    );
    setState(() {
      _endDateTime = storedTime;
    });
  }

  void _handleStartTimezoneChanged(String newTimezone) {
    final adjustedTime = TimezoneConverter.recalculateForTimezoneChange(
      _startDateTime,
      _startTimeTimezone,
      newTimezone,
    );
    setState(() {
      _startDateTime = adjustedTime;
      _startTimeTimezone = newTimezone;
    });
  }

  void _handleEndTimezoneChanged(String newTimezone) {
    if (_endDateTime == null) {
      setState(() {
        _endTimeTimezone = newTimezone;
      });
      return;
    }

    final adjustedTime = TimezoneConverter.recalculateForTimezoneChange(
      _endDateTime!,
      _endTimeTimezone,
      newTimezone,
    );
    setState(() {
      _endDateTime = adjustedTime;
      _endTimeTimezone = newTimezone;
    });
  }

  Widget _buildCompleteStep(AppLocalizations l10n) {
    final isEditing = _aggregateId != null;
    final isExistingComplete = _isComplete;

    final buttonText = isEditing
        ? (isExistingComplete ? l10n.saveChanges : l10n.completeRecord)
        : l10n.finished;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (isEditing && !isExistingComplete) ...[
            Text(
              l10n.completeRecord,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),
          ],

          Text(
            isEditing && !isExistingComplete
                ? l10n.reviewAndSave
                : l10n.tapFieldToEdit,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20,),

          AppButton(
            size: AppButtonSize.large,
            fullWidth: true,
            label: buttonText,
            loading: _isSaving,
            onPressed: _isSaving ? null : _saveRecord,
          ),

          const SizedBox(height: 12),

          // Cancel returns to the previous (end time) step without saving.
          AppButton(
            size: AppButtonSize.large,
            fullWidth: true,
            variant: AppButtonVariant.secondary,
            label: l10n.cancel,
            onPressed: _isSaving
                ? null
                : () => _goToStep(RecordingStep.endTime),
          ),
        ],
      ),
    );
  }
}
