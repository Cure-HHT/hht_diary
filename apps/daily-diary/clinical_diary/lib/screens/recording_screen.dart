import 'dart:async';

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:clinical_diary/read/diary_view_builder.dart';
import 'package:clinical_diary/screens/overlap_compare_screen.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/settings/clinical_rules_scope.dart';
import 'package:clinical_diary/utils/app_page_route.dart';
import 'package:clinical_diary/utils/date_time_formatter.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/date_header.dart';
import 'package:clinical_diary/widgets/delete_confirmation_dialog.dart';
import 'package:clinical_diary/widgets/duration_confirmation_dialog.dart';
import 'package:clinical_diary/widgets/flash_highlight.dart';
import 'package:clinical_diary/widgets/intensity_picker.dart';
import 'package:clinical_diary/widgets/nosebleed_intensity.dart';
import 'package:clinical_diary/widgets/old_entry_justification_dialog.dart';
import 'package:clinical_diary/widgets/overlap_warning.dart';
import 'package:clinical_diary/widgets/time_picker_dial.dart';
import 'package:clinical_diary/widgets/timezone_picker.dart';
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

  // CUR-464: Flash intensity field when user tries to set end time without it.
  bool _flashIntensity = false;

  // DIARY-PRD-entry-time-restrictions: Old entry justification if required.
  OldEntryJustification? _oldEntryJustification;

  // The event-sourced clinical rules (justification/lock thresholds + duration
  // confirmations + review screen), read reactively from ClinicalRulesScope in
  // didChangeDependencies — NOT the legacy FeatureFlagService.
  ClinicalRules _rules = const ClinicalRules();
  bool _initialStepSet = false;

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

    // CUR-492: Reject negative duration (end time before start time) first.
    final duration = _durationMinutes();
    if (duration != null && duration < 0) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.endTimeAfterStart)));
      return false;
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
  /// current candidate range, excluding the entry being edited. Returns an
  /// empty list when there is no end time yet (an open-ended candidate is not
  /// matched against neighbours here).
  // Implements: DIARY-DEV-reactive-read-path/A
  List<EpistaxisEntryView> _overlappingEvents(DiaryView view) {
    if (_endDateTime == null) {
      return const <EpistaxisEntryView>[];
    }
    final rows = overlappingEpistaxisEntries(
      view.finalizedRows,
      _startDateTime,
      _endDateTime!,
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
    final result = await ReActionScope.of(context).actionSubmitter.submit(
      ActionSubmission(actionName: actionName, rawInput: rawInput),
    );
    switch (result) {
      case DispatchSuccess<Object?>(:final result):
        return result is String ? result : null;
      case DispatchIdempotencyHit<Object?>(:final cachedResult):
        return cachedResult is String ? cachedResult : null;
      default:
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
      if (mounted) {
        // If this finalize created/left an overlap, go STRAIGHT to the
        // side-by-side resolve screen (replacing this one) instead of returning
        // to the previous screen. When we were ourselves opened from the overlap
        // flow (an Edit on the compare screen) just pop back — that compare
        // screen re-derives and re-renders or auto-pops.
        final conflict = widget.fromOverlapResolution
            ? null
            : _firstOverlapConflict();
        if (conflict != null) {
          unawaited(
            Navigator.pushReplacement(
              context,
              AppPageRoute<void>(
                builder: (_) => OverlapCompareScreen(
                  leftId: conflict.aggregateId,
                  rightId: savedId,
                ),
              ),
            ),
          );
        } else {
          Navigator.pop(context, savedId);
        }
      }
      return newId;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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

    if (storedEndTime.isBefore(_startDateTime)) {
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
        body: SafeArea(
          child: Column(
            children: [
              // Header with back and delete buttons
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final shouldPop = await _handleExit();
                        if (shouldPop && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: Text(l10n.back),
                    ),
                    // Delete button — hidden on a locked (read-only) date.
                    if (!_isLocked)
                      IconButton(
                        onPressed: _handleDelete,
                        icon: const Icon(Icons.delete_outline),
                        color: Theme.of(context).colorScheme.error,
                        tooltip: l10n.deleteRecordTooltip,
                      ),
                  ],
                ),
              ),

              // DIARY-PRD-entry-time-restrictions: read-only lock notice.
              if (_isLocked) _buildLockBanner(),

              // Date header - not editable
              DateHeader(
                date: _startDateTime,
                editable: false,
                onChange: (newDate) => {},
              ),

              const SizedBox(height: 16),

              // Summary bar
              _buildSummaryBar(l10n),

              const SizedBox(height: 16),

              // Overlap warning
              if (overlappingEvents.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: OverlapWarning(
                    overlappingEntries: overlappingEvents,
                    onResolve: () => unawaited(_saveRecord()),
                  ),
                ),

              if (overlappingEvents.isNotEmpty) const SizedBox(height: 16),

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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Start time
          _buildSummaryItem(
            label: l10n.start,
            value: _formatStartTime(locale, l10n),
            subtitle: showStartTz ? startTzAbbr : null,
            isActive: _currentStep == RecordingStep.startTime,
            onTap: () => _goToStep(RecordingStep.startTime),
          ),

          _buildDivider(),

          // Intensity - wrapped in FlashHighlight for CUR-464
          FlashHighlight(
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

          _buildDivider(),

          // End time - CUR-464: flash intensity if not set
          _buildSummaryItem(
            label: l10n.end,
            value: _formatEndTime(locale, l10n),
            subtitle: showEndTz ? endTzAbbr : null,
            isActive: _currentStep == RecordingStep.endTime,
            onTap: _handleEndTimeTap,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              highlightColor ??
              (isActive
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive
                      ? Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
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
      height: 30,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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

    final durationMinutes = _durationMinutes();
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isEditing && !isExistingComplete
                ? l10n.completeRecord
                : isEditing
                ? l10n.editRecord
                : l10n.recordComplete,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

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

          if (durationMinutes != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.durationMinutes(durationMinutes),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _saveRecord,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(buttonText, style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}
