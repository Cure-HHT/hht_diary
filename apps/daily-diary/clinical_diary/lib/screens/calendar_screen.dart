import 'dart:async';

import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:clinical_diary/read/diary_view_builder.dart';
import 'package:clinical_diary/screens/date_records_screen.dart';
import 'package:clinical_diary/screens/day_disposition.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/settings/app_preferences_scope.dart';
import 'package:clinical_diary/settings/clinical_rules_scope.dart';
import 'package:clinical_diary/utils/app_page_route.dart';
import 'package:diary_shared_model/diary_shared_model.dart'
    show EntryGate, entryGateForDate;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

/// Calendar screen showing nosebleed history with color-coded days.
///
/// Reads day status reactively from the live [DiaryView] (no async loading,
/// no local status cache); writes (day markers) go through the scope's
/// `actionSubmitter`.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  /// Check if animations are enabled (both feature flag and user preference).
  /// The user side is read reactively from the settings projection.
  bool _animationsEnabled(BuildContext context) =>
      FeatureFlagService.instance.useAnimations &&
      AppPreferencesScope.of(context).useAnimation;

  /// Month change just moves the focused day; day data is reactive.
  void _handleMonthChange(DateTime focusedDay) {
    setState(() => _focusedDay = focusedDay);
  }

  /// The `yyyy-MM-dd` local-date key for a calendar [day]. TableCalendar emits
  /// `DateTime.utc(y,m,d)`, so we read the calendar fields directly rather than
  /// converting through epoch time.
  static String _localDateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

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

  /// Day-tap dispatch: future days are inert; a day with no finalized records
  /// opens the 3-choice day-disposition picker, a day with records opens the
  /// [DateRecordsScreen] populated from the live view.
  // Implements: DIARY-GUI-calendar-day-view
  // Implements: DIARY-DEV-reactive-read-path/A
  Future<void> _onDaySelected(
    DiaryView view,
    DateTime selectedDay,
    DateTime focusedDay,
  ) async {
    // Don't allow selection of future dates (CUR-407)
    if (_isFutureDate(selectedDay)) {
      return;
    }

    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    // TableCalendar emits UTC DateTimes; use the local wall-clock day for both
    // the view lookup and the RecordingScreen's preselected date.
    final localDay = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final localDate = _localDateKey(selectedDay);
    // Surface BOTH finalized entries and in-progress (checkpoint) drafts for the
    // day: a day may hold only an incomplete draft (rendered black on the grid),
    // and tapping it must open the records list so the draft can be resumed —
    // not the 3-option picker, which is only for a day with no entries at all.
    final entries = <DiaryEntryView>[
      ...view.entriesOn(localDate),
      ...view.incompleteEntriesOn(localDate),
    ];

    // Day-level lock (the primary gate; recording screen + Actions are
    // defense-in-depth). A locked date is read-only for EVERYTHING — nosebleeds
    // AND the day markers — so route to the read-only records view rather than
    // offering the 3-choice disposition picker or an add button.
    // Implements: DIARY-PRD-entry-time-restrictions/E+F+G
    final locked =
        entryGateForDate(
          eventLocalMidnight: localDay,
          now: DateTime.now(),
          config: ClinicalRulesScope.of(context).gate,
        ) ==
        EntryGate.locked;
    if (locked) {
      await _showDateRecordsScreen(
        localDay,
        localDate,
        entries,
        view,
        locked: true,
      );
    } else if (entries.isEmpty) {
      // A genuinely empty day has no marker to tombstone — pass null.
      await showDayDispositionPicker(
        context,
        localDay: localDay,
        localDate: localDate,
      );
    } else {
      await _showDateRecordsScreen(localDay, localDate, entries, view);
    }
  }

  Future<void> _showDateRecordsScreen(
    DateTime selectedDay,
    String localDate,
    List<DiaryEntryView> entries,
    DiaryView view, {
    bool locked = false,
  }) async {
    // The lone marker on this day (if any) drives both convert-on-add and the
    // marker-tap re-disposition's tombstone target.
    final soleMarker = view.soleMarkerOn(localDate);
    final markerToReplace = soleMarker == null
        ? null
        : MarkerToReplace(
            aggregateId: soleMarker.aggregateId,
            entryType: soleMarker.entryType,
          );

    await Navigator.push<void>(
      context,
      AppPageRoute(
        builder: (context) => DateRecordsScreen(
          date: selectedDay,
          locked: locked,
          entries: entries,
          // "Add Event": a day whose only entry is a lone marker converts (the
          // new nosebleed tombstones that marker); a day with nosebleeds just
          // adds another (no tombstone).
          // Implements: DIARY-PRD-day-disposition/A+C
          onAddEvent: () {
            Navigator.pop(context);
            unawaited(
              recordNosebleedReplacingMarker(
                this.context,
                localDay: selectedDay,
                marker: markerToReplace,
              ),
            );
          },
          onEditEvent: (EpistaxisEntryView entry) {
            Navigator.pop(context);
            unawaited(_navigateToEdit(entry));
          },
          // Tapping a marker re-dispositions the day, seeded with that marker.
          // Implements: DIARY-PRD-day-disposition/B
          onRedispositionMarker: (DayMarkerView marker) {
            Navigator.pop(context);
            unawaited(
              showDayDispositionPicker(
                this.context,
                localDay: selectedDay,
                localDate: localDate,
                marker: MarkerToReplace(
                  aggregateId: marker.aggregateId,
                  entryType: marker.entryType,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _navigateToEdit(EpistaxisEntryView existing) async {
    await Navigator.push<dynamic>(
      context,
      AppPageRoute(builder: (context) => RecordingScreen(existing: existing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DiaryViewBuilder(builder: _buildDialog);
  }

  Widget _buildDialog(BuildContext context, DiaryView view) {
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
            // CUR-599: Fixed height with 6 weeks enforced to prevent flickering
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TableCalendar<void>(
                firstDay: DateTime(2020, 1, 1),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                // CUR-599: Always show 6 weeks to prevent height changes
                sixWeekMonthsEnforced: true,
                // CUR-599: Respect user animation preference for page transitions
                pageAnimationEnabled: _animationsEnabled(context),
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                enabledDayPredicate: (day) => !_isFutureDate(day),
                onDaySelected: (selectedDay, focusedDay) =>
                    _onDaySelected(view, selectedDay, focusedDay),
                onPageChanged: _handleMonthChange,
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
                    final status = view.dayStatus(_localDateKey(day));
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
                    final status = view.dayStatus(_localDateKey(day));
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
                    final status = view.dayStatus(_localDateKey(day));
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
                    final status = view.dayStatus(_localDateKey(day));
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
