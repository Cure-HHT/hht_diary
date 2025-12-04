// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00001: Incomplete Entry Preservation (CUR-405)

import 'package:clinical_diary/l10n/app_localizations.dart';
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
  NosebleedIntensity? _intensity;
  bool _isSaving = false;

  // Track which fields the user has explicitly set (vs default values)
  bool _userSetStart = false;
  bool _userSetEnd = false;
  bool _userSetIntensity = false;

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
      _intensity = widget.existingRecord!.intensity;
      // Existing record means all present fields were "set"
      _userSetStart = _startTime != null;
      _userSetEnd = _endTime != null;
      _userSetIntensity = _intensity != null;
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

  String _getButtonText(AppLocalizations l10n) {
    final isEditing = widget.existingRecord != null;

    // For editing, always show "Update Nosebleed" when complete
    if (isEditing) {
      if (_userSetStart && _userSetIntensity && _userSetEnd) {
        return l10n.updateNosebleed;
      }
      return l10n.saveChanges;
    }

    // Build list of what's been set
    final setParts = <String>[];
    if (_userSetStart) setParts.add(l10n.start);
    if (_userSetIntensity) setParts.add(l10n.intensity);
    if (_userSetEnd) setParts.add(l10n.end);

    // All three set - ready to add
    if (setParts.length == 3) {
      return l10n.addNosebleed;
    }

    // Some set - show what's been set
    if (setParts.isNotEmpty) {
      return l10n.setFields(setParts.join(' & '));
    }

    // Nothing set yet - show disabled "Add Nosebleed"
    return l10n.addNosebleed;
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

  Future<void> _saveRecord(AppLocalizations l10n) async {
    if (!_canSubmit()) return;

    // Check for overlapping events - block save if any exist
    final overlaps = _getOverlappingEvents();
    if (overlaps.isNotEmpty && _endTime != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.cannotSaveOverlapCount(overlaps.length)),
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
          intensity: _intensity,
        );
      } else {
        // Create new record (isIncomplete is calculated automatically by service)
        await widget.nosebleedService.addRecord(
          date: _date,
          startTime: _startTime,
          endTime: _endTime,
          intensity: _intensity,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
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

  void _handleEndTimeChange(DateTime time, AppLocalizations l10n) {
    // Validate end time is after start time
    if (_startTime != null && time.isBefore(_startTime!)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.endTimeAfterStart)));
      return;
    }
    setState(() {
      _endTime = time;
      _userSetEnd = true;
    });
  }

  void _handleIntensitySelect(NosebleedIntensity intensity) {
    setState(() {
      _intensity = intensity;
      _userSetIntensity = true;
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

  /// Check if we have unsaved changes that could be saved as a partial record
  bool get _hasUnsavedPartialRecord {
    // If we're editing an existing record, check if values changed
    if (widget.existingRecord != null) {
      return _startTime != widget.existingRecord!.startTime ||
          _endTime != widget.existingRecord!.endTime ||
          _intensity != widget.existingRecord!.intensity;
    }
    // For new records, we have unsaved data if user has explicitly set any field
    return _userSetStart || _userSetEnd || _userSetIntensity;
  }

  /// Auto-save partial record when user navigates away with unsaved changes.
  /// REQ-p00001: Incomplete Entry Preservation - automatically saves partial
  /// records without prompting the user.
  Future<bool> _handleExit() async {
    if (!_hasUnsavedPartialRecord) return true;

    // Auto-save the partial record without prompting
    final l10n = AppLocalizations.of(context);
    await _saveRecord(l10n);
    // _saveRecord handles navigation via Navigator.pop, so return false
    // to prevent double navigation
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final overlappingEvents = _getOverlappingEvents();
    final hasOverlaps = overlappingEvents.isNotEmpty && _endTime != null;
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
                            overlappingRecords: overlappingEvents,
                            onViewConflict: (conflictingRecord) {
                              // Pop back to view the conflicting record in context
                              Navigator.pop(context, false);
                            },
                          ),
                        ),

                      // Start Time Section
                      Text(
                        l10n.nosebleedStart,
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
                        l10n.intensity,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      IntensityRow(
                        selectedIntensity: _intensity,
                        onSelect: _handleIntensitySelect,
                      ),

                      const SizedBox(height: 24),

                      // End Time Section
                      Text(
                        l10n.nosebleedEnd,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InlineTimePicker(
                        key: _endTimePickerKey,
                        initialTime: _endTime,
                        onTimeChanged: (time) =>
                            _handleEndTimeChange(time, l10n),
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
                    // CUR-410: Red error container removed - overlap warning banner
                    // now shows the specific conflicting record time range
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (_isSaving || !_canSubmit())
                            ? null
                            : () => _saveRecord(l10n),
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
                                _getButtonText(l10n),
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
      ),
    );
  }
}
