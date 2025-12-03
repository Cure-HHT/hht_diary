// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/widgets/date_header.dart';
import 'package:clinical_diary/widgets/delete_confirmation_dialog.dart';
import 'package:clinical_diary/widgets/inline_time_picker.dart';
import 'package:clinical_diary/widgets/intensity_row.dart';
import 'package:clinical_diary/widgets/overlap_warning.dart';
import 'package:flutter/material.dart';

/// Simplified recording screen with all controls on one page
class SimpleRecordingScreen extends StatefulWidget {
  const SimpleRecordingScreen({
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
  State<SimpleRecordingScreen> createState() => _SimpleRecordingScreenState();
}

class _SimpleRecordingScreenState extends State<SimpleRecordingScreen> {
  late DateTime _date;
  DateTime? _startTime;
  DateTime? _endTime;
  NosebleedSeverity? _severity;
  bool _isSaving = false;

  // Track which fields the user has explicitly set (vs default values)
  bool _userSetStart = false;
  bool _userSetEnd = false;
  bool _userSetSeverity = false;

  // Keys for independent time picker state
  final _startTimePickerKey = GlobalKey<State>();
  final _endTimePickerKey = GlobalKey<State>();

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();

    if (widget.existingRecord != null) {
      _startTime = widget.existingRecord!.startTime;
      _endTime = widget.existingRecord!.endTime;
      _severity = widget.existingRecord!.severity;
      // Existing record means all present fields were "set"
      _userSetStart = _startTime != null;
      _userSetEnd = _endTime != null;
      _userSetSeverity = _severity != null;
    } else {
      // Default start time to the selected date with current time of day
      // but don't mark it as user-set yet
      _startTime = DateTime(
        _date.year,
        _date.month,
        _date.day,
        DateTime.now().hour,
        DateTime.now().minute,
      );
      // End time is null (unset) by default - user must explicitly set it
      // This prevents end time from being in the future
      _endTime = null;
    }
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

  String _getButtonText() {
    final isEditing = widget.existingRecord != null;

    // For editing, always show "Update Nosebleed" when complete
    if (isEditing) {
      if (_userSetStart && _userSetSeverity && _userSetEnd) {
        return 'Update Nosebleed';
      }
      return 'Save Changes';
    }

    // Build list of what's been set
    final setParts = <String>[];
    if (_userSetStart) setParts.add('Start');
    if (_userSetSeverity) setParts.add('Intensity');
    if (_userSetEnd) setParts.add('End');

    // All three set - ready to add
    if (setParts.length == 3) {
      return 'Add Nosebleed';
    }

    // Some set - show what's been set
    if (setParts.isNotEmpty) {
      return 'Set ${setParts.join(' & ')}';
    }

    // Nothing set yet - show disabled "Add Nosebleed"
    return 'Add Nosebleed';
  }

  bool _canSubmit() {
    // Must have user-set at least start time
    if (!_userSetStart) return false;

    // Check for overlapping events if we have both start and end set
    if (_userSetEnd && _getOverlappingEvents().isNotEmpty) {
      return false;
    }

    return true;
  }

  Future<void> _saveRecord() async {
    if (!_canSubmit()) return;

    // Check for overlapping events - block save if any exist
    final overlaps = _getOverlappingEvents();
    if (overlaps.isNotEmpty && _endTime != null) {
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

    setState(() => _isSaving = true);

    try {
      if (widget.existingRecord != null) {
        // Update existing record
        await widget.nosebleedService.updateRecord(
          originalRecordId: widget.existingRecord!.id,
          date: _date,
          startTime: _startTime,
          endTime: _endTime,
          severity: _severity,
        );
      } else {
        // Create new record (isIncomplete is calculated automatically by service)
        await widget.nosebleedService.addRecord(
          date: _date,
          startTime: _startTime,
          endTime: _endTime,
          severity: _severity,
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
      // Update end time similarly
      if (_endTime != null) {
        _endTime = DateTime(
          newDate.year,
          newDate.month,
          newDate.day,
          _endTime!.hour,
          _endTime!.minute,
        );
      }
    });
  }

  void _handleStartTimeChange(DateTime time) {
    setState(() {
      _startTime = time;
      _userSetStart = true;
      // If end time is before start time, clear it (user must re-set)
      // This prevents automatically setting a potentially future time
      if (_endTime != null && _endTime!.isBefore(time)) {
        _endTime = null;
        _userSetEnd = false;
      }
    });
  }

  void _handleEndTimeChange(DateTime time) {
    // Validate end time is after start time
    if (_startTime != null && time.isBefore(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }
    setState(() {
      _endTime = time;
      _userSetEnd = true;
    });
  }

  void _handleSeveritySelect(NosebleedSeverity severity) {
    setState(() {
      _severity = severity;
      _userSetSeverity = true;
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
    final hasOverlaps = overlappingEvents.isNotEmpty && _endTime != null;

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

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overlap warning
                    if (hasOverlaps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: OverlapWarning(
                          overlappingCount: overlappingEvents.length,
                        ),
                      ),

                    // Start Time Section
                    Text(
                      'Nosebleed Start',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InlineTimePicker(
                      key: _startTimePickerKey,
                      initialTime:
                          _startTime ??
                          DateTime(
                            _date.year,
                            _date.month,
                            _date.day,
                            DateTime.now().hour,
                            DateTime.now().minute,
                          ),
                      onTimeChanged: _handleStartTimeChange,
                      allowFutureTimes: false,
                      maxDateTime: _maxDateTimeForTimePicker,
                    ),

                    const SizedBox(height: 24),

                    // Intensity Section
                    Text(
                      'Intensity',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    IntensityRow(
                      selectedIntensity: _severity,
                      onSelect: _handleSeveritySelect,
                    ),

                    const SizedBox(height: 24),

                    // End Time Section
                    Text(
                      'Nosebleed End',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InlineTimePicker(
                      key: _endTimePickerKey,
                      initialTime: _endTime,
                      onTimeChanged: _handleEndTimeChange,
                      allowFutureTimes: false,
                      minTime: _startTime,
                      maxDateTime: _maxDateTimeForTimePicker,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom action button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Show overlap error message if overlaps exist
                  if (hasOverlaps)
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cannot save: This event overlaps with existing events.',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_isSaving || !_canSubmit())
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
                          : Text(
                              _getButtonText(),
                              style: const TextStyle(fontSize: 18),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
