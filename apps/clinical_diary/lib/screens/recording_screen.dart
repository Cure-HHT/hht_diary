// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/widgets/date_header.dart';
import 'package:clinical_diary/widgets/delete_confirmation_dialog.dart';
import 'package:clinical_diary/widgets/intensity_picker.dart';
// CUR-408: notes_input import removed - notes step removed from recording flow
import 'package:clinical_diary/widgets/overlap_warning.dart';
import 'package:clinical_diary/widgets/time_picker_dial.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Recording flow screen for creating new nosebleed records
class RecordingScreen extends StatefulWidget {
  const RecordingScreen({
    required this.nosebleedService,
    required this.enrollmentService,
    super.key,
    this.initialDate,
    this.existingRecord,
    this.allRecords = const [],
    this.onDelete,
  });

  final NosebleedService nosebleedService;
  final EnrollmentService enrollmentService;
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
  late DateTime _date;
  DateTime? _startTime;
  DateTime? _endTime;
  NosebleedIntensity? _intensity;
  // CUR-408: Notes field removed from recording flow

  RecordingStep _currentStep = RecordingStep.startTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    // CUR-408: Removed _loadEnrollmentStatus call - notes step removed

    if (widget.existingRecord != null) {
      _startTime = widget.existingRecord!.startTime;
      _endTime = widget.existingRecord!.endTime;
      _intensity = widget.existingRecord!.intensity;
      // CUR-408: Notes field no longer loaded from existing record
      _currentStep = _getInitialStepForExisting();
    } else {
      // Default start time to the selected date with current time of day
      // This ensures recording for past dates doesn't default to today's datetime
      _startTime = DateTime(
        _date.year,
        _date.month,
        _date.day,
        DateTime.now().hour,
        DateTime.now().minute,
      );
    }
  }

  // CUR-408: _loadEnrollmentStatus removed - notes step removed from recording flow

  RecordingStep _getInitialStepForExisting() {
    final record = widget.existingRecord!;
    if (record.intensity == null) return RecordingStep.intensity;
    if (record.endTime == null) return RecordingStep.endTime;
    // For editing existing records, go to complete step
    return RecordingStep.complete;
  }

  // CUR-408: _shouldRequireNotes removed - notes step removed from recording flow

  String _formatTime(DateTime? time, String locale) {
    if (time == null) return '--:--';
    return DateFormat.jm(locale).format(time);
  }

  int? get _durationMinutes {
    if (_startTime == null || _endTime == null) return null;
    return _endTime!.difference(_startTime!).inMinutes;
  }

  /// Returns the maximum DateTime allowed for time selection.
  /// For today, returns DateTime.now() to prevent future times.
  /// For past dates, returns end of that day (23:59:59) to allow any time.
  DateTime? get _maxDateTimeForTimePicker {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(_date.year, _date.month, _date.day);

    if (selectedDay.isBefore(today)) {
      // Past date: allow any time on that day
      return DateTime(_date.year, _date.month, _date.day, 23, 59, 59);
    }
    // Today or future: use current time as max (default behavior)
    return null;
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

  Future<void> _saveRecord() async {
    // At minimum, we need a start time to save a record
    // Records without all fields will be marked as incomplete by the service
    if (_startTime == null) return;

    // CUR-443: Overlapping events are allowed - warning shown in UI but doesn't block save
    // User can save and fix either record later

    // CUR-408: Notes validation removed - notes step removed from recording flow

    setState(() => _isSaving = true);

    try {
      if (widget.existingRecord != null) {
        // Update existing record (creates a new version that supersedes the original)
        await widget.nosebleedService.updateRecord(
          originalRecordId: widget.existingRecord!.id,
          date: _date,
          startTime: _startTime,
          endTime: _endTime,
          intensity: _intensity,
          // CUR-408: notes parameter removed
        );
      } else {
        // Create new record
        await widget.nosebleedService.addRecord(
          date: _date,
          startTime: _startTime,
          endTime: _endTime,
          intensity: _intensity,
          // CUR-408: notes parameter removed
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.failedToSave}: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _handleDateChange(DateTime newDate) {
    setState(() {
      _date = newDate;
      // Update start time to match new date while preserving time
      if (_startTime != null) {
        _startTime = DateTime(
          newDate.year,
          newDate.month,
          newDate.day,
          _startTime!.hour,
          _startTime!.minute,
        );
      }
    });
  }

  void _goToStep(RecordingStep step) {
    setState(() => _currentStep = step);
  }

  void _handleStartTimeConfirm(DateTime time) {
    setState(() {
      _startTime = time;
      _currentStep = RecordingStep.intensity;
    });
  }

  void _handleIntensitySelect(NosebleedIntensity intensity) {
    setState(() {
      _intensity = intensity;
      _currentStep = RecordingStep.endTime;
    });
  }

  void _handleEndTimeConfirm(DateTime time) {
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
      // CUR-408: Go directly to complete step, notes step removed
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
          if (mounted) {
            Navigator.pop(context, true);
          }
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
    if (!_hasUnsavedPartialRecord) return true;

    // Auto-save the partial record without prompting
    await _saveRecord();
    // _saveRecord handles navigation via Navigator.pop, so return false
    // to prevent double navigation
    return false;
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
              DateHeader(date: _date, onChange: _handleDateChange),

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
            value: _formatTime(_startTime, locale),
            isActive: _currentStep == RecordingStep.startTime,
            onTap: () => _goToStep(RecordingStep.startTime),
          ),

          _buildDivider(),

          // Intensity
          _buildSummaryItem(
            label: l10n.maxIntensity,
            value: _intensity != null
                ? l10n.intensityName(_intensity!.name)
                : l10n.selectIntensity,
            isActive: _currentStep == RecordingStep.intensity,
            onTap: _startTime != null
                ? () => _goToStep(RecordingStep.intensity)
                : null,
          ),

          _buildDivider(),

          // End time
          _buildSummaryItem(
            label: l10n.end,
            value: _formatTime(_endTime, locale),
            isActive: _currentStep == RecordingStep.endTime,
            onTap: _intensity != null
                ? () => _goToStep(RecordingStep.endTime)
                : null,
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
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
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
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
        // Use the selected date with current time, or existing start time
        final startInitialTime =
            _startTime ??
            DateTime(
              _date.year,
              _date.month,
              _date.day,
              DateTime.now().hour,
              DateTime.now().minute,
            );
        return TimePickerDial(
          key: const ValueKey('start_time_picker'),
          title: l10n.nosebleedStart,
          initialTime: startInitialTime,
          onConfirm: _handleStartTimeConfirm,
          confirmLabel: l10n.setStartTime,
          maxDateTime: _maxDateTimeForTimePicker,
        );

      case RecordingStep.intensity:
        return IntensityPicker(
          key: const ValueKey('intensity_picker'),
          selectedIntensity: _intensity,
          onSelect: _handleIntensitySelect,
        );

      case RecordingStep.endTime:
        // Use start time + 15 minutes as default, or existing end time
        final endInitialTime =
            _endTime ??
            (_startTime != null
                ? _startTime!.add(const Duration(minutes: 15))
                : DateTime(
                    _date.year,
                    _date.month,
                    _date.day,
                    DateTime.now().hour,
                    DateTime.now().minute,
                  ));
        return TimePickerDial(
          key: const ValueKey('end_time_picker'),
          title: l10n.nosebleedEndTime,
          initialTime: endInitialTime,
          onConfirm: _handleEndTimeConfirm,
          confirmLabel: l10n.nosebleedEnded,
          maxDateTime: _maxDateTimeForTimePicker,
        );

      // CUR-408: Notes case removed from recording flow

      case RecordingStep.complete:
        return _buildCompleteStep(l10n);
    }
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
          // CUR-443: Removed large checkmark icon - not in spec
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
