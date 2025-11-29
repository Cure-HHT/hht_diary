// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/widgets/date_header.dart';
import 'package:clinical_diary/widgets/delete_confirmation_dialog.dart';
import 'package:clinical_diary/widgets/notes_input.dart';
import 'package:clinical_diary/widgets/overlap_warning.dart';
import 'package:clinical_diary/widgets/severity_picker.dart';
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

enum RecordingStep { startTime, severity, endTime, notes, complete }

class _RecordingScreenState extends State<RecordingScreen> {
  late DateTime _date;
  DateTime? _startTime;
  DateTime? _endTime;
  NosebleedSeverity? _severity;
  String? _notes;
  bool _isEnrolledInTrial = false;
  DateTime? _enrollmentDateTime;

  RecordingStep _currentStep = RecordingStep.startTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    _loadEnrollmentStatus();

    if (widget.existingRecord != null) {
      _startTime = widget.existingRecord!.startTime;
      _endTime = widget.existingRecord!.endTime;
      _severity = widget.existingRecord!.severity;
      _notes = widget.existingRecord!.notes;
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

  Future<void> _loadEnrollmentStatus() async {
    final enrollment = await widget.enrollmentService.getEnrollment();
    if (mounted) {
      setState(() {
        _isEnrolledInTrial = enrollment != null;
        _enrollmentDateTime = enrollment?.enrolledAt;
      });
    }
  }

  RecordingStep _getInitialStepForExisting() {
    final record = widget.existingRecord!;
    if (record.severity == null) return RecordingStep.severity;
    if (record.endTime == null) return RecordingStep.endTime;
    // For editing existing records, go to complete step
    return RecordingStep.complete;
  }

  bool _shouldRequireNotes(NosebleedRecord? record) {
    if (!_isEnrolledInTrial || _enrollmentDateTime == null) return false;
    if (record == null) return false;

    final recordStartTime = record.startTime ?? record.date;
    return recordStartTime.isAfter(_enrollmentDateTime!) ||
        recordStartTime.isAtSameMomentAs(_enrollmentDateTime!);
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '--:--';
    return DateFormat('h:mm a').format(time);
  }

  int? get _durationMinutes {
    if (_startTime == null || _endTime == null) return null;
    return _endTime!.difference(_startTime!).inMinutes;
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
    if (_startTime == null || _endTime == null || _severity == null) return;

    // Check for overlapping events - block save if any exist
    final overlaps = _getOverlappingEvents();
    if (overlaps.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot save: This event overlaps with ${overlaps.length} existing ${overlaps.length == 1 ? 'event' : 'events'}',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Check if notes are required
    final currentRecord = NosebleedRecord(
      id: widget.existingRecord?.id ?? '',
      date: _date,
      startTime: _startTime,
      endTime: _endTime,
      severity: _severity,
      notes: _notes,
    );

    if (_shouldRequireNotes(currentRecord) &&
        (_notes == null || _notes!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notes are required for clinical trial participants'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.existingRecord != null) {
        // Update existing record (creates a new version that supersedes the original)
        await widget.nosebleedService.updateRecord(
          originalRecordId: widget.existingRecord!.id,
          date: _date,
          startTime: _startTime,
          endTime: _endTime,
          severity: _severity,
          notes: _notes,
        );
      } else {
        // Create new record
        await widget.nosebleedService.addRecord(
          date: _date,
          startTime: _startTime,
          endTime: _endTime,
          severity: _severity,
          notes: _notes,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
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
      _currentStep = RecordingStep.severity;
    });
  }

  void _handleSeveritySelect(NosebleedSeverity severity) {
    setState(() {
      _severity = severity;
      _currentStep = RecordingStep.endTime;
      // Initialize end time to start time + 15 minutes if not set
      // This preserves the date from _startTime instead of using today's date
      if (_endTime == null && _startTime != null) {
        _endTime = _startTime!.add(const Duration(minutes: 15));
      }
    });
  }

  void _handleEndTimeConfirm(DateTime time) {
    // Validate end time is after start time
    if (_startTime != null && time.isBefore(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    setState(() {
      _endTime = time;
      // Always show notes step, it will be optional for non-enrolled users
      _currentStep = RecordingStep.notes;
    });
  }

  void _handleNotesChange(String notes) {
    setState(() {
      _notes = notes;
    });
  }

  void _handleNotesBack() {
    setState(() {
      _currentStep = RecordingStep.endTime;
    });
  }

  void _handleNotesNext() {
    setState(() {
      _currentStep = RecordingStep.complete;
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final overlappingEvents = _getOverlappingEvents();

    return Scaffold(
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
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                  // Delete button only for existing records
                  if (widget.existingRecord != null)
                    IconButton(
                      onPressed: _handleDelete,
                      icon: const Icon(Icons.delete_outline),
                      color: Theme.of(context).colorScheme.error,
                      tooltip: 'Delete record',
                    ),
                ],
              ),
            ),

            // Date header (tappable)
            DateHeader(date: _date, onChange: _handleDateChange),

            const SizedBox(height: 16),

            // Summary bar
            _buildSummaryBar(),

            const SizedBox(height: 16),

            // Overlap warning
            if (overlappingEvents.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: OverlapWarning(
                  overlappingCount: overlappingEvents.length,
                ),
              ),

            if (overlappingEvents.isNotEmpty) const SizedBox(height: 16),

            // Main content area
            Expanded(child: _buildCurrentStep()),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
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
            label: 'Start',
            value: _formatTime(_startTime),
            isActive: _currentStep == RecordingStep.startTime,
            onTap: () => _goToStep(RecordingStep.startTime),
          ),

          _buildDivider(),

          // Severity
          _buildSummaryItem(
            label: 'Severity',
            value: _severity?.displayName ?? 'Select...',
            isActive: _currentStep == RecordingStep.severity,
            onTap: _startTime != null
                ? () => _goToStep(RecordingStep.severity)
                : null,
          ),

          _buildDivider(),

          // End time
          _buildSummaryItem(
            label: 'End',
            value: _formatTime(_endTime),
            isActive: _currentStep == RecordingStep.endTime,
            onTap: _severity != null
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

  Widget _buildCurrentStep() {
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
          title: 'Nosebleed Start',
          initialTime: startInitialTime,
          onConfirm: _handleStartTimeConfirm,
          confirmLabel: 'Set Start Time',
        );

      case RecordingStep.severity:
        return SeverityPicker(
          key: const ValueKey('severity_picker'),
          selectedSeverity: _severity,
          onSelect: _handleSeveritySelect,
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
          title: 'Nosebleed End Time',
          initialTime: endInitialTime,
          onConfirm: _handleEndTimeConfirm,
          confirmLabel: 'Nosebleed Ended',
        );

      case RecordingStep.notes:
        return NotesInput(
          key: const ValueKey('notes_input'),
          notes: _notes ?? '',
          onNotesChange: _handleNotesChange,
          onBack: _handleNotesBack,
          onNext: _handleNotesNext,
          isRequired: _isEnrolledInTrial,
        );

      case RecordingStep.complete:
        return _buildCompleteStep();
    }
  }

  Widget _buildCompleteStep() {
    final isExistingComplete =
        widget.existingRecord != null &&
        widget.existingRecord!.severity != null &&
        widget.existingRecord!.endTime != null;

    final currentRecord = NosebleedRecord(
      id: widget.existingRecord?.id ?? '',
      date: _date,
      startTime: _startTime,
      endTime: _endTime,
      severity: _severity,
      notes: _notes,
    );

    final needsNotes = _shouldRequireNotes(currentRecord);
    final hasOverlaps = _getOverlappingEvents().isNotEmpty;
    final buttonText = widget.existingRecord != null
        ? (isExistingComplete ? 'Save Changes' : 'Complete Record')
        : 'Finished';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),

          const SizedBox(height: 24),

          Text(
            widget.existingRecord != null && !isExistingComplete
                ? 'Complete Record'
                : widget.existingRecord != null
                ? 'Edit Record'
                : 'Record Complete',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            widget.existingRecord != null && !isExistingComplete
                ? 'Review the information and save when ready'
                : 'Tap any field above to edit it',
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
                'Duration: $_durationMinutes minutes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],

          // Show notes if required
          if (needsNotes) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _currentStep = RecordingStep.notes),
                    child: Text(
                      (_notes?.isNotEmpty ?? false)
                          ? _notes!
                          : 'Tap to add notes (required)',
                      style: TextStyle(
                        fontSize: 14,
                        color: (_notes?.isNotEmpty ?? false)
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          // Show overlap error message if overlaps exist
          if (hasOverlaps) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cannot save: This event overlaps with existing events. Please adjust the time.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  (_isSaving ||
                      hasOverlaps ||
                      (needsNotes &&
                          (_notes == null || _notes!.trim().isEmpty)))
                  ? null
                  : _saveRecord,
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
