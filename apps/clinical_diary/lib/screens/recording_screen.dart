// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-CAL-p00001: Old Entry Modification Justification
//   REQ-CAL-p00002: Short Duration Nosebleed Confirmation
//   REQ-CAL-p00003: Long Duration Nosebleed Confirmation

import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/widgets/date_header.dart';
import 'package:clinical_diary/widgets/delete_confirmation_dialog.dart';
import 'package:clinical_diary/widgets/duration_confirmation_dialog.dart';
import 'package:clinical_diary/widgets/flash_highlight.dart';
import 'package:clinical_diary/widgets/intensity_picker.dart';

// CUR-408: notes_input import removed - notes step removed from recording flow
import 'package:clinical_diary/widgets/old_entry_justification_dialog.dart';
import 'package:clinical_diary/widgets/overlap_warning.dart';
import 'package:clinical_diary/widgets/time_picker_dial.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Recording flow screen for creating new nosebleed records.
/// Creation
/// The screen is created in three ways:
/// 1) The "Record Nosebleed" button on the home page to create a new entry for today.
///    The diaryEntryDate is null
///    The existingRecord is null
///    The onDelete callback is null
///    The State\<RecordingScreen>'s _startDateTime initializes to DateTime.now()
///    The State\<RecordingScreen>'s _endDateTime initializes to null
///
/// 2) The a selected date from the "Calendar" button on the home page.
///    The diaryEntryDate is the selected date from the Calendar
///    The existingRecord is null
///    The onDelete callback is null
///    The State\<RecordingScreen>'s _startTime initializes to diaryEntryDate with DateTime.now()'s time
///    The State\<RecordingScreen>'s _endDateTime initializes to null
///
/// 3) Editing an existing record.
///    The diaryEntryDate is null
///    The existingRecord is not null
///    The onDelete callback is not null
///    The State\<RecordingScreen>'s _startDateTime initializes to the existingRecords' startTime
///    The State\<RecordingScreen>'s _endDateTime initializes to the existingRecords' endDateTime
///
/// Widgets - all text is i18n'ed, all times and dates are l10n'ed.
/// Navigation
///     Top left: a Back button that goes back to the previous page, saving
///         the record, which might be an incomplete record.
///     Top reight: a Delete button which either calls
///         the record, which might be an incomplete record.
/// DateHeader - This is the dairy entry date, which is always the start date.
/// It's not editable (any longer, editable: false).
/// The displayed value changes when _startDateTime changes
/// (See Start DateTimeTZ Content)
///
/// Summary Row - the Summary Row is 3 widgets that track the user's progress.
/// (1) Start DateTimeTZ, it display's:
///         - the start time.
///         - the start date if different from the non-null endDate's date.
///         - the start timezone if different from the non-null endDate's timezone.
/// (2) Intensity - display's the Intensity text or "Tap to Set"
/// (3) End DateTimeTZ, it display's:
///         - the end time, or if null "Not set".
///         - the end date if different from the startDate's date.
///         - the end timezone if different from the startDate's timezone.
/// The Start DateTimeTZ content is always initially selected.
/// Clicking on a summary widget changes the content container below it so the user
/// can enter a datum into the nosebleed record. Exception: If user clicks the
/// end date and the Intensity is null, the content is not changed and the
/// Intensity summary block flashes twice to remind the user that Intensity
/// is required.
///
/// Content
/// (1) Start DateTimeTZ Content
///     Title: Nosebleed Start Time
///     Date Display:
///         When clicked, shows the calendar picker widget.
///         When the user picks a new date, it changes _startDateTime's
///         y/m/d (keeping the time) and sets diaryEntryDate to _startDateTime
///         If _endDateTime is null, it sets _endDateTime to _startDateTime
///     Time Display: Displays:
///         - the start time.
///         - the date if different from the non-null endDate's date.
///         - the timezone if different from the non-null endDate's timezone.
///         When clicked, shows the time picker widget.
///         When the user picks a new time, it changes _startDateTime
///             and set the diaryEntryDate to the new _startDateTime
///     Decrement/Increment Buttons: when clicked, moves _startDateTime
///         forward or backwards by the number of minutes on the button
/// (2) Intensity Content - a grid of Intensity's, when click, sets _intensity.
/// (3) End DateTimeTZ Content
///     Title: Nosebleed End Time
///     Time Display: When clicked, shows the time picker widget.
///         When the user picks a new time, it changes _endDateTime
///     Date Display: When clicked, shows the calendar picker widget.
///         When the user picks a new date, it changes _endDateTime's
///         y/m/d (keeping the old date's time)
///     Decrement/Increment Buttons: when clicked, moves the _endDateTime
///         forward or backwards by the number of minutes on the button
class RecordingScreen extends StatefulWidget {
  const RecordingScreen({
    required this.nosebleedService,
    required this.enrollmentService,
    required this.preferencesService,
    super.key,
    // from calendar
    this.diaryEntryDate,
    // edit mode
    this.existingRecord,
    this.allRecords = const [],
    this.onDelete,
  }) : assert(
         diaryEntryDate == null || existingRecord == null,
         'Cannot specify both initialDate and existingRecord',
       ),
       assert(
         existingRecord == null || onDelete != null,
         'Must specify an onDelete callback when existingRecord is non null.',
       );

  final NosebleedService nosebleedService;
  final EnrollmentService enrollmentService;
  final PreferencesService preferencesService;
  final DateTime? diaryEntryDate;
  final NosebleedRecord? existingRecord;
  final List<NosebleedRecord> allRecords;
  final Future<void> Function(String)? onDelete;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

// CUR-408: Removed notes step from recording flow
enum RecordingStep { startTime, intensity, endTime, complete }

class _RecordingScreenState extends State<RecordingScreen> {
  // The start date/time shown in the summary, timepicker and clock
  DateTime _startDateTime = DateTime.now();

  // The intensity shown in the summary and intensity display
  NosebleedIntensity? _intensity;

  // The end date/time shown in the summary, timepicker and clock
  DateTime? _endDateTime;

  // CUR-408: Notes field removed from recording flow TODO - needs to be put back

  RecordingStep _currentStep = RecordingStep.startTime;
  bool _isSaving = false;

  // CUR-464: Flash intensity field when user tries to set end time without intensity
  bool _flashIntensity = false;

  // REQ-CAL-p00001: Old entry justification if required
  OldEntryJustification? _oldEntryJustification;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Timezone is now embedded in ISO 8601 strings via DateTimeFormatter.
    // No separate timezone tracking needed.
    if (widget.existingRecord == null) {
      if (widget.diaryEntryDate == null) {
        _startDateTime = now;
      } else {
        _startDateTime = widget.diaryEntryDate!;
      }
      // Leave _endDateTime null for new records - it will be set when user
      // explicitly sets it. The end time picker will use _startDateTime as default.
      _endDateTime = null;
      _intensity = null;
      _currentStep = RecordingStep.startTime;
    } else {
      //defensive, startTime should always be set but json conversion could fail
      _startDateTime = widget.existingRecord?.startTime ?? now;
      _endDateTime = widget.existingRecord?.endTime;
      _intensity = widget.existingRecord!.intensity;
      _currentStep = _getInitialStepForExisting();
    }
  }

  /// REQ-CAL-p00001: Check if this is an old entry (more than one calendar day old)
  bool _isOldEntry() {
    final yesterday = DateUtils.addDaysToDate(
      DateUtils.dateOnly(DateTime.now()),
      -1,
    );
    final entryDate = DateUtils.dateOnly(_startDateTime);
    return entryDate.isBefore(yesterday);
  }

  /// REQ-CAL-p00001: Check if old entry justification is required and not yet provided
  bool get _needsOldEntryJustification {
    if (!FeatureFlagService.instance.requireOldEntryJustification) {
      return false;
    }
    return _isOldEntry() && _oldEntryJustification == null;
  }

  /// REQ-CAL-p00002: Check if short duration confirmation is needed
  bool get _needsShortDurationConfirmation {
    if (!FeatureFlagService.instance.enableShortDurationConfirmation) {
      return false;
    }
    final duration = _durationMinutes();
    return duration != null && duration <= 1;
  }

  /// REQ-CAL-p00003: Check if long duration confirmation is needed
  bool get _needsLongDurationConfirmation {
    if (!FeatureFlagService.instance.enableLongDurationConfirmation) {
      return false;
    }
    final duration = _durationMinutes();
    final threshold = FeatureFlagService.instance.longDurationThresholdMinutes;
    return duration != null && duration > threshold;
  }

  /// REQ-CAL: Run all validation checks before saving
  /// Returns true if save should proceed, false if cancelled
  Future<bool> _runValidationChecks() async {
    // REQ-CAL-p00001: Old entry justification check
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

    // REQ-CAL-p00002: Short duration confirmation
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

    // REQ-CAL-p00003: Long duration confirmation
    if (_needsLongDurationConfirmation) {
      final confirmed = await DurationConfirmationDialog.show(
        context: context,
        type: DurationConfirmationType.long,
        durationMinutes: _durationMinutes() ?? 0,
        thresholdMinutes:
            FeatureFlagService.instance.longDurationThresholdMinutes,
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

  // CUR-408: _loadEnrollmentStatus removed - notes step removed from recording flow - TODO PUT BACK

  RecordingStep _getInitialStepForExisting() {
    if (widget.existingRecord == null) {
      return RecordingStep.startTime;
    }
    if (widget.existingRecord!.intensity == null) {
      return RecordingStep.intensity;
    }
    if (widget.existingRecord!.endTime == null) {
      return RecordingStep.endTime;
    }
    // For complete records: show review screen if enabled, otherwise start time
    if (FeatureFlagService.instance.useReviewScreen) {
      return RecordingStep.complete;
    }
    return RecordingStep.startTime;
  }

  // CUR-408: _shouldRequireNotes removed - notes step removed from recording flow - TODO - put back

  /// CUR-488: Use localized "Not set" instead of "--:--" for better UX
  /// Times are displayed in the user's current local timezone.
  String _formatTime(DateTime? time, String locale, AppLocalizations l10n) {
    if (time == null) {
      return l10n.notSet;
    }
    return DateFormat.jm(locale).format(time);
  }

  /// Format end time with day offset indicator if dates differ from start.
  /// Shows "(+1 day)" or "(+N days)" suffix when end date is after start date.
  /// Times are displayed in the user's current local timezone.
  String _formatEndTime(
    DateTime? endTime,
    String locale,
    AppLocalizations l10n,
  ) {
    if (endTime == null) {
      return l10n.notSet;
    }

    final timeStr = DateFormat.jm(locale).format(endTime);

    // Add day difference suffix
    final startDate = DateUtils.dateOnly(_startDateTime);
    final endDate = DateUtils.dateOnly(endTime);
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

  List<NosebleedRecord> _getOverlappingEvents() {
    if (_endDateTime == null) {
      return [];
    }

    return widget.allRecords.where((record) {
      // You can't overlap yourself
      if (widget.existingRecord != null &&
          record.id == widget.existingRecord!.id) {
        return false;
      }

      // Only check real (not unknown or no nosebleed) events with
      // both start and end times
      if (!record.isRealNosebleedEvent || record.endTime == null) {
        return false;
      }

      // Check if events overlap
      return _startDateTime.isBefore(record.endTime!) &&
          _endDateTime!.isAfter(record.startTime);
    }).toList();
  }

  /// Saves the record and returns the record ID, or null if save failed.
  Future<String?> _saveRecord() async {
    debugPrint(
      '[RecordingScreen] _saveRecord: start=$_startDateTime, '
      'intensity=$_intensity, end=$_endDateTime',
    );
    // CUR-408: Notes validation removed - notes step removed from recording flow - TODO - put back

    // REQ-CAL: Run validation checks before saving
    final shouldProceed = await _runValidationChecks();
    debugPrint('[RecordingScreen] _saveRecord: shouldProceed=$shouldProceed');
    if (!shouldProceed) {
      return null;
    }

    setState(() => _isSaving = true);

    try {
      String recordId;
      if (widget.existingRecord != null) {
        // Update existing record (creates a new record that supersedes the original)
        // CUR-447: Use _startDateTime as the primary date for the record
        // Timezone is automatically embedded in ISO 8601 strings via DateTimeFormatter
        final record = await widget.nosebleedService.updateRecord(
          originalRecordId: widget.existingRecord!.id,
          startTime: _startDateTime,
          endTime: _endDateTime,
          intensity: _intensity,
          // CUR-408: notes parameter removed - TODO putback
        );
        recordId = record.id;
      } else {
        // Create new record
        // CUR-447: Use _startDateTime as the primary date for the record
        // Timezone is automatically embedded in ISO 8601 strings via DateTimeFormatter
        final record = await widget.nosebleedService.addRecord(
          startTime: _startDateTime,
          endTime: _endDateTime,
          intensity: _intensity,
          // CUR-408: notes parameter removed
        );
        recordId = record.id;
      }

      if (mounted) {
        // Return record ID so home screen can scroll to and highlight it
        Navigator.pop(context, recordId);
      }
      return recordId;
    } catch (e, s) {
      debugPrint('$e');
      debugPrintStack(stackTrace: s);
      // Show error snackbar to user
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
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _goToStep(RecordingStep step) {
    setState(() => _currentStep = step);
  }

  /// CUR-464: Handle end time tap - flash intensity if not set, otherwise navigate
  void _handleEndTimeTap() {
    if (_intensity == null) {
      // Flash the intensity field to remind user to set it first
      setState(() => _flashIntensity = true);
    } else {
      _goToStep(RecordingStep.endTime);
    }
  }

  // void _handleStartTimeConfirm(DateTime time) {
  //   setState(() {
  //     _startDateTime = time;
  //     _currentStep = RecordingStep.intensity;
  //   });
  // }

  void _handleIntensitySelect(NosebleedIntensity intensity) {
    setState(() {
      _intensity = intensity;
      _currentStep = RecordingStep.endTime;
    });
  }

  Future<void> _handleEndTimeConfirm(DateTime endTime) async {
    // Validate end time is after start time
    if (endTime.isBefore(_startDateTime)) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.endTimeAfterStart)));
      return;
    }

    setState(() {
      _endDateTime = endTime;
    });

    // CUR-464: When useReviewScreen is false, save immediately and return
    if (!FeatureFlagService.instance.useReviewScreen) {
      await _saveRecord();
      return;
    }

    // CUR-408: Go directly to complete step, notes step removed (TODO - put back)
    setState(() {
      _currentStep = RecordingStep.complete;
    });
  }

  // CUR-408: _handleNotesChange, _handleNotesBack, _handleNotesNext removed

  Future<void> _handleDelete() async {
    await DeleteConfirmationDialog.show(
      context: context,
      onConfirmDelete: (String reason) async {
        if (widget.onDelete != null) {
          await widget.onDelete!(reason);
        }
        // Pop the recording screen after the dialog closes
        //If no existing record/onDelete, pop without saving the partial.
        if (mounted) {
          Navigator.pop(context, true);
        }
      },
    );
  }

  /// Check if we have unsaved changes that could be saved as a partial record
  /// Save even if the user just comes in and goes back.  The nosebleed started,
  /// it records the start, they can pick it up later, easy-peasy
  bool _hasUnsavedPartialRecord() {
    // If we're editing an existing record, check if values changed
    if (widget.existingRecord != null) {
      return _startDateTime != widget.existingRecord!.startTime ||
          _endDateTime != widget.existingRecord!.endTime ||
          _intensity != widget.existingRecord!.intensity;
    }
    // For new records, we have unsaved data if
    // we're not at the complete step (which has its own save button)
    return _currentStep != RecordingStep.complete;
  }

  /// Auto-save partial record when user navigates away with unsaved changes.
  /// REQ-p00001: Incomplete Entry Preservation - automatically saves partial
  /// records without prompting the user.
  Future<bool> _handleExit() async {
    try {
      final hasUnsaved = _hasUnsavedPartialRecord();
      debugPrint(
        '[RecordingScreen] _handleExit: hasUnsavedPartialRecord=$hasUnsaved, '
        'step=$_currentStep, intensity=$_intensity, endTime=$_endDateTime',
      );
      if (!hasUnsaved) {
        return true;
      }

      // Auto-save the partial record without prompting
      debugPrint('[RecordingScreen] _handleExit: calling _saveRecord()');
      final recordId = await _saveRecord();
      if (recordId == null) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          // TODO - need an error dialog with an error id and o11y
          final controller = ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: SelectableText(
                l10n.failedToSave,
                style: const TextStyle(color: Colors.white),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
          await controller.closed;
        }
        // _saveRecord won't pop on error so we have to
        return true;
      }
      // _saveRecord handles navigation via Navigator.pop, so return false
      // to prevent double navigation
      return false;
    } catch (e, s) {
      //TODO - improve error handling
      debugPrint('Error exiting $e');
      debugPrintStack(stackTrace: s);
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlappingEvents = _getOverlappingEvents();
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
                    // Delete button
                    IconButton(
                      onPressed: _handleDelete,
                      icon: const Icon(Icons.delete_outline),
                      color: Theme.of(context).colorScheme.error,
                      tooltip: l10n.deleteRecordTooltip,
                    ),
                  ],
                ),
              ),

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
                    overlappingRecords: overlappingEvents,
                    onViewConflict: (conflictingRecord) {
                      // Pop back to view the conflicting record in context
                      Navigator.pop(context, false);
                    },
                  ),
                ),

              if (overlappingEvents.isNotEmpty) const SizedBox(height: 16),

              // Main content area
              Expanded(child: _buildCurrentStep(l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBar(AppLocalizations l10n) {
    final locale = Localizations.localeOf(context).languageCode;
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
            value: _formatTime(_startDateTime, locale, l10n),
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

          // End time - CUR-464: use _handleEndTimeTap to flash intensity if not set
          _buildSummaryItem(
            label: l10n.end,
            value: _formatEndTime(_endDateTime, locale, l10n),
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
    VoidCallback? onTap,
    Color? highlightColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          // CUR-464: Use highlight color when flashing, otherwise normal styling
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
        // Timezone is now automatically embedded in ISO 8601 strings
        // when saving via DateTimeFormatter. No separate timezone tracking needed.
        return TimePickerDial(
          key: const ValueKey('start_time_picker'),
          title: l10n.nosebleedStart,
          initialTime: _startDateTime,
          onConfirm: (DateTime time) {
            setStartTimeState(time, _startDateTime);
            setState(() {
              _currentStep = RecordingStep.intensity;
            });
          },
          onTimeChanged: (time) {
            setStartTimeState(time, _startDateTime);
          },
          confirmLabel: l10n.setStartTime,
          maxDateTime: DateTime.now(),
        );

      case RecordingStep.intensity:
        return IntensityPicker(
          key: const ValueKey('intensity_picker'),
          selectedIntensity: _intensity,
          onSelect: _handleIntensitySelect,
        );

      case RecordingStep.endTime:
        // Use start time as default for end time picker when not yet set
        final endInitialTime = _endDateTime ?? _startDateTime;
        // Timezone is now automatically embedded in ISO 8601 strings
        // when saving via DateTimeFormatter. No separate timezone tracking needed.
        return TimePickerDial(
          key: const ValueKey('end_time_picker'),
          title: l10n.nosebleedEndTime,
          initialTime: endInitialTime,
          onConfirm: _handleEndTimeConfirm,
          onTimeChanged: (time) {
            setState(() {
              _endDateTime = time;
            });
          },
          confirmLabel: l10n.setEndTime,
          maxDateTime: DateTime.now(),
        );

      // CUR-408: Notes case removed from recording flow - TODO PUT BACK

      case RecordingStep.complete:
        return _buildCompleteStep(l10n);
    }
  }

  void setStartTimeState(DateTime time, DateTime startInitialTime) {
    setState(() {
      _startDateTime = time;
      // _endDateTime remains null for new records until user explicitly sets it.
      // The end time picker will use _startDateTime as the default initial value.
    });
  }

  /// @return a DateTime where the Date is date and the time is time
  DateTime dateTimeForDateAndTime(DateTime date, DateTime time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Widget _buildCompleteStep(AppLocalizations l10n) {
    final isExistingComplete =
        widget.existingRecord != null &&
        widget.existingRecord!.intensity != null &&
        widget.existingRecord!.endTime != null;

    // CUR-408: Notes-related currentRecord and needsNotes removed
    // CUR-443: hasOverlaps removed - overlaps show warning but don't block save

    final buttonText = widget.existingRecord != null
        ? (isExistingComplete ? l10n.saveChanges : l10n.completeRecord)
        : l10n.finished;

    final durationMinutes = _durationMinutes();
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.existingRecord != null && !isExistingComplete
                ? l10n.completeRecord
                : widget.existingRecord != null
                ? l10n.editRecord
                : l10n.recordComplete,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            widget.existingRecord != null && !isExistingComplete
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

          // CUR-408: Notes display section removed from complete step
          const Spacer(),

          // CUR-443: Overlaps show warning but don't block save
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
