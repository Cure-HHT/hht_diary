// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

/// Status types for date classification in the calendar
enum DateStatus {
  nosebleed,
  noNosebleed,
  unknown,
  incomplete,
  noEvents,
  beforeFirst,
}

/// Calendar overlay for selecting dates to add or edit nosebleed events
class CalendarOverlay extends StatefulWidget {
  const CalendarOverlay({
    required this.isOpen,
    required this.onClose,
    required this.onDateSelect,
    super.key,
    this.selectedDate,
    this.records = const [],
    this.incompleteRecords = const [],
    this.missingDays = const [],
  });

  final bool isOpen;
  final VoidCallback onClose;
  final ValueChanged<DateTime> onDateSelect;
  final DateTime? selectedDate;
  final List<NosebleedRecord> records;
  final List<NosebleedRecord> incompleteRecords;
  final List<DateTime> missingDays;

  @override
  State<CalendarOverlay> createState() => _CalendarOverlayState();
}

class _CalendarOverlayState extends State<CalendarOverlay> {
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.selectedDate ?? DateTime.now();
  }

  /// Get the earliest record date from all records
  DateTime? _getEarliestRecordDate() {
    if (widget.records.isEmpty) return null;

    DateTime? earliest;
    for (final record in widget.records) {
      if (earliest == null || record.date.isBefore(earliest)) {
        earliest = record.date;
      }
    }
    return earliest;
  }

  /// Get the date status for classification
  DateStatus _getDateStatus(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final earliestDate = _getEarliestRecordDate();

    // Check if it's missing data
    final isMissingData = widget.missingDays.any((d) {
      final dOnly = DateTime(d.year, d.month, d.day);
      return dOnly == dateOnly;
    });

    // Check if it's before the first recorded event
    final isBeforeFirstRecord =
        earliestDate != null &&
        dateOnly.isBefore(
          DateTime(earliestDate.year, earliestDate.month, earliestDate.day),
        );

    // Check for records on this date
    final recordsForDate = widget.records.where((record) {
      final recordDateOnly = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      return recordDateOnly == dateOnly;
    }).toList();

    // Check for incomplete records on this date
    final hasIncompleteRecords = widget.incompleteRecords.any((record) {
      final recordDateOnly = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      return recordDateOnly == dateOnly;
    });

    if (hasIncompleteRecords || isMissingData) {
      return DateStatus.incomplete;
    }

    if (recordsForDate.isEmpty) {
      return isBeforeFirstRecord ? DateStatus.beforeFirst : DateStatus.noEvents;
    }

    // Check types of records - prioritize based on type
    final hasNosebleedEvents = recordsForDate.any(
      (r) => !r.isNoNosebleedsEvent && !r.isUnknownEvent,
    );
    final hasNoNosebleedEvents = recordsForDate.any(
      (r) => r.isNoNosebleedsEvent,
    );
    final hasUnknownEvents = recordsForDate.any((r) => r.isUnknownEvent);

    if (hasNosebleedEvents) {
      return DateStatus.nosebleed;
    } else if (hasNoNosebleedEvents) {
      return DateStatus.noNosebleed;
    } else if (hasUnknownEvents) {
      return DateStatus.unknown;
    }

    return DateStatus.noEvents;
  }

  /// Get color based on date status
  Color _getDateColor(DateTime date) {
    final status = _getDateStatus(date);
    switch (status) {
      case DateStatus.nosebleed:
        return const Color(0xFFDC2626); // Red
      case DateStatus.noNosebleed:
        return const Color(0xFF16A34A); // Green
      case DateStatus.unknown:
        return const Color(0xFFEAB308); // Yellow
      case DateStatus.incomplete:
        return const Color(0xFF000000); // Black
      case DateStatus.noEvents:
      case DateStatus.beforeFirst:
        return const Color(0xFF6B7280); // Gray
    }
  }

  /// Check if a date should be disabled (future dates are not allowed)
  bool _isDisabled(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.isAfter(today);
  }

  /// Handle date selection
  void _handleDateSelect(DateTime selectedDay, DateTime focusedDay) {
    if (_isDisabled(selectedDay)) {
      return; // Don't allow selection of disabled dates
    }

    setState(() {
      _focusedDay = focusedDay;
    });

    widget.onDateSelect(selectedDay);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: GestureDetector(
        onTap: widget.onClose,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping the card
            child: Container(
              margin: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with close button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Date',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: widget.onClose,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // Calendar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TableCalendar(
                      firstDay: DateTime.now().subtract(
                        const Duration(days: 730),
                      ),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) {
                        if (widget.selectedDate == null) return false;
                        return isSameDay(day, widget.selectedDate);
                      },
                      onDaySelected: _handleDateSelect,
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                        selectedTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders<dynamic>(
                        defaultBuilder: (context, day, focusedDay) {
                          return _buildDateCell(context, day, false);
                        },
                        todayBuilder: (context, day, focusedDay) {
                          return _buildDateCell(context, day, true);
                        },
                        selectedBuilder: (context, day, focusedDay) {
                          return _buildDateCell(
                            context,
                            day,
                            false,
                            isSelected: true,
                          );
                        },
                        disabledBuilder: (context, day, focusedDay) {
                          return _buildDateCell(
                            context,
                            day,
                            false,
                            isDisabled: true,
                          );
                        },
                        outsideBuilder: (context, day, focusedDay) {
                          return _buildDateCell(
                            context,
                            day,
                            false,
                            isOutside: true,
                          );
                        },
                      ),
                      enabledDayPredicate: (day) => !_isDisabled(day),
                    ),
                  ),

                  // Legend
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 2,
                          childAspectRatio: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildLegendItem(
                              color: const Color(0xFFDC2626),
                              label: 'Nosebleed events',
                            ),
                            _buildLegendItem(
                              color: const Color(0xFF16A34A),
                              label: 'No nosebleeds',
                            ),
                            _buildLegendItem(
                              color: const Color(0xFFEAB308),
                              label: 'Unknown',
                            ),
                            _buildLegendItem(
                              color: const Color(0xFF000000),
                              label: 'Incomplete/Missing',
                            ),
                            _buildLegendItem(
                              color: const Color(0xFF6B7280),
                              label: 'Not recorded',
                            ),
                            _buildLegendItem(
                              color: Colors.transparent,
                              label: 'Today',
                              isBorder: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap a date to add or edit events',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateCell(
    BuildContext context,
    DateTime day,
    bool isToday, {
    bool isSelected = false,
    bool isDisabled = false,
    bool isOutside = false,
  }) {
    final color = isDisabled || isOutside
        ? const Color(0xFF6B7280).withValues(alpha: 0.5)
        : _getDateColor(day);

    final textColor = isDisabled || isOutside
        ? Colors.white.withValues(alpha: 0.5)
        : (color.computeLuminance() > 0.5 ? Colors.black : Colors.white);

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected ? Theme.of(context).colorScheme.primary : color,
        shape: BoxShape.circle,
        border: isToday
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: isSelected ? Colors.white : textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    bool isBorder = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isBorder ? Colors.transparent : color,
            border: isBorder ? Border.all(color: Colors.grey, width: 2) : null,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
