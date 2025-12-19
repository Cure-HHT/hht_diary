// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00008: Mobile App Diary Entry

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/screens/date_records_screen.dart';
import 'package:clinical_diary/screens/day_selection_screen.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/utils/app_page_route.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

/// Calendar screen showing nosebleed history with color-coded days
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    required this.nosebleedService,
    required this.enrollmentService,
    required this.preferencesService,
    super.key,
  });

  final NosebleedService nosebleedService;
  final EnrollmentService enrollmentService;
  final PreferencesService preferencesService;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, DayStatus> _dayStatuses = {};
  List<NosebleedRecord> _allRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDayStatuses();
  }

  Future<void> _loadDayStatuses() async {
    setState(() => _isLoading = true);

    // Load statuses for current month plus padding
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 2, 0);

    final statuses = await widget.nosebleedService.getDayStatusRange(
      firstDay,
      lastDay,
    );

    // Also load all records for overlap checking
    final allRecords = await widget.nosebleedService
        .getLocalMaterializedRecords();

    setState(() {
      _dayStatuses = statuses;
      _allRecords = allRecords;
      _isLoading = false;
    });
  }

  Color _getColorForStatus(DayStatus status) {
    switch (status) {
      case DayStatus.nosebleed:
        return Colors.red;
      case DayStatus.noNosebleed:
        return Colors.green;
      case DayStatus.unknown:
        return Colors.orange;
      case DayStatus.incomplete:
        return Colors.black87;
      case DayStatus.notRecorded:
        return Colors.grey.shade400;
    }
  }

  /// Check if a date should be disabled (future dates are not allowed)
  bool _isFutureDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.isAfter(today);
  }

  Future<void> _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    // Don't allow selection of future dates (CUR-407)
    if (_isFutureDate(selectedDay)) {
      return;
    }

    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    // CUR-543: TableCalendar returns UTC DateTimes (DateTime.utc(y,m,d)).
    // Convert to local time for correct timezone handling in RecordingScreen.
    // This ensures timestamps are stored with the user's local timezone offset.
    final localDay = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final status = _dayStatuses[localDay] ?? DayStatus.notRecorded;

    // If no records exist for this day, show the day selection screen
    if (status == DayStatus.notRecorded) {
      await _showDaySelectionScreen(localDay);
    } else {
      // Show date records screen with existing events
      await _showDateRecordsScreen(localDay);
    }
  }

  Future<void> _showDateRecordsScreen(DateTime selectedDay) async {
    // Fetch records for the selected day
    final records = await widget.nosebleedService.getRecordsForStartDate(
      selectedDay,
    );

    if (!mounted) return;

    final result = await Navigator.push<dynamic>(
      context,
      AppPageRoute(
        builder: (context) => DateRecordsScreen(
          date: selectedDay,
          records: records,
          onAddEvent: () {
            // CUR-586: Just pop with result, let parent handle navigation
            Navigator.pop(context, 'add');
          },
          onEditEvent: (record) {
            // CUR-586: Just pop with record, let parent handle navigation
            Navigator.pop(context, record);
          },
        ),
      ),
    );

    if (!mounted) return;

    // CUR-586: Handle result and refresh after ALL navigation is complete
    if (result == 'add') {
      await _navigateToRecordingScreen(selectedDay);
    } else if (result is NosebleedRecord) {
      await _navigateToRecordingScreen(selectedDay, existingRecord: result);
    }

    // Always refresh after returning
    if (mounted) {
      await _loadDayStatuses();
    }
  }

  Future<void> _showDaySelectionScreen(DateTime selectedDay) async {
    final result = await Navigator.push<String>(
      context,
      AppPageRoute(
        builder: (context) => DaySelectionScreen(
          date: selectedDay,
          onAddNosebleed: () {
            // CUR-586: Just pop with result, let parent handle navigation
            Navigator.pop(context, 'add');
          },
          onNoNosebleeds: () async {
            await widget.nosebleedService.markNoNosebleeds(selectedDay);
            if (context.mounted) {
              Navigator.pop(context, 'done');
            }
          },
          onUnknown: () async {
            await widget.nosebleedService.markUnknown(selectedDay);
            if (context.mounted) {
              Navigator.pop(context, 'done');
            }
          },
        ),
      ),
    );

    if (!mounted) return;

    // CUR-586: Handle result and refresh after ALL navigation is complete
    if (result == 'add') {
      // Navigate to RecordingScreen THEN refresh
      await _navigateToRecordingScreen(selectedDay);
    }

    // Always refresh after returning (whether from add, no-nosebleed, unknown, or back)
    if (mounted) {
      await _loadDayStatuses();
    }
  }

  /// Navigate to RecordingScreen and return the result.
  /// Returns: String (record ID) on save, true on delete, null on cancel, false on conflict.
  Future<dynamic> _navigateToRecordingScreen(
    DateTime selectedDay, {
    NosebleedRecord? existingRecord,
  }) async {
    // CUR-543: RecordingScreen returns String (record ID) on save, bool on delete/cancel
    // Using dynamic to handle both return types
    // CUR-543: Only pass diaryEntryDate for new records, not when editing existing records.
    // RecordingScreen asserts that only one of diaryEntryDate or existingRecord can be non-null.
    // CUR-543: Must pass onDelete callback when existingRecord is non-null.
    final result = await Navigator.push<dynamic>(
      context,
      AppPageRoute(
        builder: (context) => RecordingScreen(
          nosebleedService: widget.nosebleedService,
          enrollmentService: widget.enrollmentService,
          preferencesService: widget.preferencesService,
          diaryEntryDate: existingRecord == null ? selectedDay : null,
          existingRecord: existingRecord,
          allRecords: _allRecords,
          onDelete: existingRecord != null
              ? (reason) async {
                  await widget.nosebleedService.deleteRecord(
                    recordId: existingRecord.id,
                    reason: reason,
                  );
                }
              : null,
        ),
      ),
    );

    // CUR-586: Return the result to the caller instead of handling refresh here.
    // The caller (_showDateRecordsScreen) handles the refresh in its loop pattern.
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Date',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Calendar
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TableCalendar<void>(
                  firstDay: DateTime(2020, 1, 1),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  enabledDayPredicate: (day) => !_isFutureDate(day),
                  onDaySelected: _onDaySelected,
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                    _loadDayStatuses();
                  },
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextFormatter: (date, locale) =>
                        DateFormat('MMMM yyyy').format(date),
                  ),
                  calendarStyle: const CalendarStyle(outsideDaysVisible: true),
                  calendarBuilders: CalendarBuilders<void>(
                    disabledBuilder: (context, day, focusedDay) {
                      // Disabled future dates appear grayed out
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ),
                      );
                    },
                    defaultBuilder: (context, day, focusedDay) {
                      final normalizedDay = DateTime(
                        day.year,
                        day.month,
                        day.day,
                      );
                      final status =
                          _dayStatuses[normalizedDay] ?? DayStatus.notRecorded;
                      final color = _getColorForStatus(status);

                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: status == DayStatus.notRecorded
                                  ? Colors.black87
                                  : Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                    outsideBuilder: (context, day, focusedDay) {
                      final normalizedDay = DateTime(
                        day.year,
                        day.month,
                        day.day,
                      );
                      final status =
                          _dayStatuses[normalizedDay] ?? DayStatus.notRecorded;
                      final color = _getColorForStatus(status);

                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      );
                    },
                    todayBuilder: (context, day, focusedDay) {
                      final normalizedDay = DateTime(
                        day.year,
                        day.month,
                        day.day,
                      );
                      final status =
                          _dayStatuses[normalizedDay] ?? DayStatus.notRecorded;
                      final color = _getColorForStatus(status);

                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: status == DayStatus.notRecorded
                                  ? Colors.black87
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      final normalizedDay = DateTime(
                        day.year,
                        day.month,
                        day.day,
                      );
                      final status =
                          _dayStatuses[normalizedDay] ?? DayStatus.notRecorded;
                      final color = _getColorForStatus(status);
                      final isToday = isSameDay(day, todayNormalized);

                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isToday
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: status == DayStatus.notRecorded
                                  ? Colors.black87
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Legend
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildLegendItem(Colors.red, 'Nosebleed events'),
                      ),
                      Expanded(
                        child: _buildLegendItem(Colors.green, 'No nosebleeds'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLegendItem(Colors.orange, 'Unknown'),
                      ),
                      Expanded(
                        child: _buildLegendItem(
                          Colors.black87,
                          'Incomplete/Missing',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLegendItem(
                          Colors.grey.shade400,
                          'Not recorded',
                        ),
                      ),
                      Expanded(child: _buildLegendItemWithBorder('Today')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tap a date to add or edit events',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
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

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  Widget _buildLegendItemWithBorder(String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
