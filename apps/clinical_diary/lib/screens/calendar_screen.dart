// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-p00008: Mobile App Diary Entry

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/screens/date_records_screen.dart';
import 'package:clinical_diary/screens/day_selection_screen.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

/// Calendar screen showing nosebleed history with color-coded days
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    required this.nosebleedService,
    required this.enrollmentService,
    super.key,
  });

  final NosebleedService nosebleedService;
  final EnrollmentService enrollmentService;

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
    final allRecords = await widget.nosebleedService.getLocalRecords();

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

  Future<void> _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    // Navigate to recording screen for the selected date
    final normalizedDay = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final status = _dayStatuses[normalizedDay] ?? DayStatus.notRecorded;

    // If no records exist for this day, show the day selection screen
    if (status == DayStatus.notRecorded) {
      await _showDaySelectionScreen(selectedDay);
    } else {
      // Show date records screen with existing events
      await _showDateRecordsScreen(selectedDay);
    }
  }

  Future<void> _showDateRecordsScreen(DateTime selectedDay) async {
    // Fetch records for the selected day
    final records = await widget.nosebleedService.getRecordsForDate(
      selectedDay,
    );

    if (!mounted) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => DateRecordsScreen(
          date: selectedDay,
          records: records,
          onAddEvent: () async {
            Navigator.pop(context);
            await _navigateToRecordingScreen(selectedDay);
          },
          onEditEvent: (record) async {
            Navigator.pop(context);
            await _navigateToRecordingScreen(
              selectedDay,
              existingRecord: record,
            );
          },
        ),
      ),
    );

    if (result ?? false) {
      await _loadDayStatuses();
    }
  }

  Future<void> _showDaySelectionScreen(DateTime selectedDay) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => DaySelectionScreen(
          date: selectedDay,
          onAddNosebleed: () async {
            Navigator.pop(context);
            await _navigateToRecordingScreen(selectedDay);
          },
          onNoNosebleeds: () async {
            await widget.nosebleedService.markNoNosebleeds(selectedDay);
            if (context.mounted) {
              Navigator.pop(context, true);
            }
          },
          onUnknown: () async {
            await widget.nosebleedService.markUnknown(selectedDay);
            if (context.mounted) {
              Navigator.pop(context, true);
            }
          },
        ),
      ),
    );

    if (result ?? false) {
      await _loadDayStatuses();
    }
  }

  Future<void> _navigateToRecordingScreen(
    DateTime selectedDay, {
    NosebleedRecord? existingRecord,
  }) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RecordingScreen(
          nosebleedService: widget.nosebleedService,
          enrollmentService: widget.enrollmentService,
          initialDate: selectedDay,
          existingRecord: existingRecord,
          allRecords: _allRecords,
        ),
      ),
    );

    if (result ?? false) {
      await _loadDayStatuses();
    }
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
