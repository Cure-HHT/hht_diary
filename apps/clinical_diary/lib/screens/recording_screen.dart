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

/// Recording flow screen for creating new nosebleed records
class RecordingScreen extends StatefulWidget {
  const RecordingScreen({
    required this.nosebleedService,
    required this.enrollmentService,
    required this.preferencesService,
    super.key,
    this.initialDate,
    this.existingRecord,
    this.allRecords = const [],
    this.onDelete,
  }) : assert(
         initialDate == null || existingRecord == null,
         'Cannot specify both initialDate and existingRecord',
       );

  final NosebleedService nosebleedService;
  final EnrollmentService enrollmentService;
  final PreferencesService preferencesService;
  final DateTime? initialDate;
  final NosebleedRecord? existingRecord;
  final List<NosebleedRecord> allRecords;
  final Future<void> Function(String)? onDelete;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

// CUR-408: Removed notes step from recording flow
enum RecordingStep { startTime, intensity, endTime, complete }

class _RecordingScreenState extends State<RecordingScreen> {
  // CUR-447: Separate dates for start and end to support cross-day nosebleeds
  // The top date field when setting the start time
  late DateTime _startDate;

  // The top date field when setting the end time
  late DateTime? _endDate;

  // The start time shown in the summary and the clock
  DateTime? _startTime;

  // The end time shown in the summary and the clock
  DateTime? _endTime;

  // The intensity shown in the summary and intensity display
  NosebleedIntensity? _intensity;

  // CUR-408: Notes field removed from recording flow TODO - needs to be put back

  RecordingStep _currentStep = RecordingStep.startTime;

  bool _isSaving = false;

  // CUR-464: Flash intensity field when user tries to set end time without intensity
  bool _flashIntensity = false;

  // REQ-CAL-p00001: Old entry justification if required
  OldEntryJustification? _oldEntryJustification;

  // Feature flag service for validation settings (sponsor-controlled)
  final _featureFlagService = FeatureFlagService.instance;

  /// Get the currently active date based on the current step
  DateTime get _headerDate {
    switch (_currentStep) {
      case RecordingStep.startTime:
        return _startDate;
      case RecordingStep.endTime:
        return _endDate ?? _startDate;
      case RecordingStep.intensity:
      case RecordingStep.complete:
        return _startDate;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingRecord != null) {
      _startTime = widget.existingRecord!.startTime;
      _endTime = widget.existingRecord!.endTime;
      _startDate = widget.existingRecord!.startTime ?? DateTime.now();
      _endDate =
          widget.existingRecord!.endTime ?? widget.existingRecord!.startTime;
      _intensity = widget.existingRecord!.intensity;
      // CUR-408: Notes field no longer loaded from existing record TOD - put back
      _currentStep = _getInitialStepForExisting();
    } else {
      final initialDate = widget.initialDate ?? DateTime.now();
      _startDate = initialDate;
      _startTime = initialDate;
      _endDate = null;
      _endTime = null;
      // CUR-408: Removed _loadEnrollmentStatus call - notes step removed, TODO - put it back
    }
  }

  /// REQ-CAL-p00001: Check if this is an old entry (more than one calendar day old)
  bool get _isOldEntry {
    if (_startTime == null) return false;
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final entryDate = DateTime(
      _startTime!.year,
      _startTime!.month,
      _startTime!.day,
    );
    return entryDate.isBefore(yesterday);
  }

  /// REQ-CAL-p00001: Check if old entry justification is required and not yet provided
  bool get _needsOldEntryJustification {
    if (!_featureFlagService.requireOldEntryJustification) return false;
    return _isOldEntry && _oldEntryJustification == null;
  }

  /// REQ-CAL-p00002: Check if short duration confirmation is needed
  bool get _needsShortDurationConfirmation {
    if (!_featureFlagService.enableShortDurationConfirmation) return false;
    final duration = _durationMinutes;
    return duration != null && duration <= 1;
  }

  /// REQ-CAL-p00003: Check if long duration confirmation is needed
  bool get _needsLongDurationConfirmation {
    if (!_featureFlagService.enableLongDurationConfirmation) return false;
    final duration = _durationMinutes;
    final threshold = _featureFlagService.longDurationThresholdMinutes;
    return duration != null && duration > threshold;
  }

  /// REQ-CAL: Run all validation checks before saving
  /// Returns true if save should proceed, false if cancelled
  Future<bool> _runValidationChecks() async {
    if (_startTime != null &&
        _endTime != null &&
        _endTime!.isBefore(_startTime!)) {
      return false;
    }
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
        durationMinutes: _durationMinutes!,
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
        durationMinutes: _durationMinutes!,
        thresholdMinutes: _featureFlagService.longDurationThresholdMinutes,
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
    final record = widget.existingRecord!;
    if (record.intensity == null) {
      return RecordingStep.intensity;
    }
    if (record.endTime == null) {
      return RecordingStep.endTime;
    }
    // For editing existing records, go to complete step
    return RecordingStep.complete; //TODO -check this, not start time?
  }

  // CUR-408: _shouldRequireNotes removed - notes step removed from recording flow - TODO - put back

  /// CUR-488: Use localized "Not set" instead of "--:--" for better UX
  String _formatTime(DateTime? time, String locale, AppLocalizations l10n) {
    if (time == null) return l10n.notSet;
    return DateFormat.jm(locale).format(time);
  }

  int? get _durationMinutes {
    if (_startTime == null || _endTime == null) return null;
    return _endTime!.difference(_startTime!).inMinutes;
  }

  DateTime? get _maxDateTimeForTimePicker {
    return DateTime.now();
  }

  List<NosebleedRecord> _getOverlappingEvents() {
    if (_startTime == null || _endTime == null) return [];

    return widget.allRecords.where((record) {
      // Skip the current record if editing
      if (widget.existingRecord != null &&
          record.id == widget.existingRecord!.id) {
        return false;
      }

      // Only check real events with both start and end times
      if (!record.isRealEvent ||
          record.startTime == null ||
          record.endTime == null) {
        return false;
      }

      // Check if events overlap
      return _startTime!.isBefore(record.endTime!) &&
          _endTime!.isAfter(record.startTime!);
    }).toList();
  }

  /// Saves the record and returns the record ID, or null if save failed.
  Future<String?> _saveRecord() async {
    // At minimum, we need a start time to save a record
    // Records without all fields will be marked as incomplete by the service
    if (_startTime == null) return null;

    // CUR-443: Overlapping events are allowed - warning shown in UI but doesn't block save
    // User can save and fix either record later

    // CUR-408: Notes validation removed - notes step removed from recording flow

    // REQ-CAL: Run validation checks before saving
    final shouldProceed = await _runValidationChecks();
    if (!shouldProceed) return null;

    setState(() => _isSaving = true);

    try {
      String? recordId;
      if (widget.existingRecord != null) {
        // Update existing record (creates a new record that supersedes the original)
        // CUR-447: Use _startDate as the primary date for the record
        final record = await widget.nosebleedService.updateRecord(
          originalRecordId: widget.existingRecord!.id,
          date: _startDate,
          startTime: _startTime,
          endTime: _endTime,
          intensity: _intensity,
          // CUR-408: notes parameter removed
        );
        recordId = record.id;
      } else {
        // Create new record
        // CUR-447: Use _startDate as the primary date for the record
        final record = await widget.nosebleedService.addRecord(
          date: _startDate,
          startTime: _startTime,
          endTime: _endTime,
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
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText(
              '${l10n.failedToSave}: $e',
              style: const TextStyle(color: Colors.white),
            ),
            duration: const Duration(seconds: 10),
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

  void _handleHeaderDateChange(DateTime newDate) {
    setState(() {
      // CUR-447: Update the date for the current step only
      switch (_currentStep) {
        case RecordingStep.startTime:
          _startDate = newDate;
          _startTime = dateTimeForDateAndTime(newDate, _startTime!);
          // If end date is before start date, update it to match
          if (_endDate == null) {
            _endDate = newDate;
          } else if (_endDate!.isBefore(newDate)) {
            _endDate = newDate;
            if (_endTime != null) {
              _endTime = dateTimeForDateAndTime(newDate, _endTime!);
            }
          }
          break;
        case RecordingStep.endTime:
          _endDate = newDate;
          _endTime ??= newDate;
          // Update end time to match new date while preserving time
          _endTime = dateTimeForDateAndTime(newDate, _endTime!);
          break;
        case RecordingStep.intensity:
        case RecordingStep.complete:
          break;
      }
    });
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

  void _handleIntensitySelect(NosebleedIntensity intensity) {
    setState(() {
      _intensity = intensity;
      _currentStep = RecordingStep.endTime;
    });
  }

  Future<void> _handleEndTimeConfirm(DateTime time) async {
    // Validate end time is after start time
    if (_startTime != null && time.isBefore(_startTime!)) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.endTimeAfterStart)));
      return;
    }

    setState(() {
      _endTime = time;
    });

    // CUR-464: When useReviewScreen is false, save immediately and return
    if (!FeatureFlagService.instance.useReviewScreen) {
      await _saveRecord();
      return;
    }

    // CUR-408: Go directly to complete step, notes step removed
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
        if (mounted) {
          Navigator.pop(context, true);
        }
      },
    );
  }

  /// Check if we have unsaved changes that could be saved as a partial record
  bool get _hasUnsavedPartialRecord {
    // If we're editing an existing record, check if values changed
    if (widget.existingRecord != null) {
      return _startTime != widget.existingRecord!.startTime ||
          _endTime != widget.existingRecord!.endTime ||
          _intensity != widget.existingRecord!.intensity;
    }
    // For new records, we have unsaved data if start time is set
    // and we're not at the complete step (which has its own save button)
    return _startTime != null && _currentStep != RecordingStep.complete;
  }

  /// Auto-save partial record when user navigates away with unsaved changes.
  /// REQ-p00001: Incomplete Entry Preservation - automatically saves partial
  /// records without prompting the user.
  Future<bool> _handleExit() async {
    try {
      if (!_hasUnsavedPartialRecord) return true;

      // Auto-save the partial record without prompting
      final recordId = await _saveRecord();
      if (recordId == null) {
        return true; //we pop
      }
      // _saveRecord handles navigation via Navigator.pop, so return false
      // to prevent double navigation
      return false;
    } catch (e, s) {
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
                    // Delete button only for existing records
                    if (widget.existingRecord != null)
                      IconButton(
                        onPressed: _handleDelete,
                        icon: const Icon(Icons.delete_outline),
                        color: Theme.of(context).colorScheme.error,
                        tooltip: l10n.deleteRecordTooltip,
                      ),
                  ],
                ),
              ),

              // Date header (tappable)
              // CUR-447: Show date for current step (start date or end date)
              DateHeader(date: _headerDate, onChange: _handleHeaderDateChange),

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
            value: _formatTime(_startTime, locale, l10n),
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
              onTap: _startTime != null
                  ? () => _goToStep(RecordingStep.intensity)
                  : null,
              highlightColor: highlightColor,
            ),
          ),

          _buildDivider(),

          // End time - CUR-464: use _handleEndTimeTap to flash intensity if not set
          _buildSummaryItem(
            label: l10n.end,
            value: _formatTime(_endTime, locale, l10n),
            isActive: _currentStep == RecordingStep.endTime,
            onTap: _startTime != null ? _handleEndTimeTap : null,
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
          borderRadius: BorderRadius.circular(8),
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
        final DateTime startInitialTime;
        if (_startTime != null) {
          // Use existing start time but ensure it's on current _startDate
          startInitialTime = dateTimeForDateAndTime(_startDate, _startTime!);
        } else {
          // Default to current time on _startDate
          startInitialTime = dateTimeForDateAndTime(_startDate, DateTime.now());
        }
        return TimePickerDial(
          key: const ValueKey('start_time_picker'),
          title: l10n.nosebleedStart,
          initialTime: startInitialTime,
          onConfirm: (DateTime time) {
            setStartTimeState(time, startInitialTime);
            setState(() {
              _currentStep = RecordingStep.intensity;
            });
          },
          onTimeChanged: (time) {
            setStartTimeState(time, startInitialTime);
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
        final endInitialTime = _endTime ?? _startTime ?? DateTime.now();
        return TimePickerDial(
          key: const ValueKey('end_time_picker'),
          title: l10n.nosebleedEndTime,
          initialTime: endInitialTime,
          onConfirm: _handleEndTimeConfirm,
          onTimeChanged: (time) {
            setState(() {
              _endDate = time;
              _endTime = time;
            });
          },
          confirmLabel: l10n.setEndTime,
          maxDateTime: _maxDateTimeForTimePicker,
        );

      // CUR-408: Notes case removed from recording flow - TODO PUT BACK

      case RecordingStep.complete:
        return _buildCompleteStep(l10n);
    }
  }

  void setStartTimeState(DateTime time, DateTime startInitialTime) {
    setState(() {
      _startTime = time;
      _startDate = time;
      // Crossing the date line either way sets the end date date,
      // if the end date is not already set
      if (_endTime == null || (!DateUtils.isSameDay(startInitialTime, time))) {
        _endDate = dateTimeForDateAndTime(startInitialTime, time);
      }
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

          if (_durationMinutes != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.durationMinutes(_durationMinutes!),
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
