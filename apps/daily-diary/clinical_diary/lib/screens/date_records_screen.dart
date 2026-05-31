import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Screen showing all events for a specific date with edit capability.
///
/// Consumes typed [DiaryEntryView] view-models (sealed:
/// [EpistaxisEntryView] / [DayMarkerView]) from the live diary view. Only
/// epistaxis entries are editable; day-markers render but are not edited.
// Implements: DIARY-DEV-reactive-read-path/A
// Implements: DIARY-GUI-epistaxis-record/A
class DateRecordsScreen extends StatelessWidget {
  const DateRecordsScreen({
    required this.date,
    required this.entries,
    required this.onAddEvent,
    required this.onEditEvent,
    super.key,
  });

  final DateTime date;
  final List<DiaryEntryView> entries;
  final VoidCallback onAddEvent;
  final void Function(EpistaxisEntryView) onEditEvent;

  String get _formattedDate => DateFormat('EEEE, MMMM d, y').format(date);

  String _eventCountText(AppLocalizations l10n) {
    return l10n.eventCount(entries.length);
  }

  /// Check if an epistaxis [entry] overlaps with any other epistaxis entry in
  /// the list. CUR-443: used to show the warning icon on overlapping events.
  bool _hasOverlap(DiaryEntryView entry) {
    if (entry is! EpistaxisEntryView) return false;
    final start = entry.startTime;
    final end = entry.endTime;
    if (end == null) return false;

    for (final other in entries) {
      if (other.aggregateId == entry.aggregateId) continue;
      if (other is! EpistaxisEntryView) continue;
      final oEnd = other.endTime;
      if (oEnd == null) continue;
      if (start.isBefore(oEnd) && end.isAfter(other.startTime)) {
        return true;
      }
    }
    return false;
  }

  /// Sort key: epistaxis entries use their startTime; day-markers fall back to
  /// the start of the local day so they sort consistently.
  DateTime _sortKey(DiaryEntryView entry) {
    if (entry is EpistaxisEntryView) return entry.startTime;
    return date;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formattedDate,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (entries.isNotEmpty)
              Text(
                _eventCountText(l10n),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Add new event button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAddEvent,
                icon: const Icon(Icons.add),
                label: Text(l10n.addNewEvent),
              ),
            ),
          ),

          // Events list or empty state
          Expanded(
            child: entries.isEmpty
                ? _buildEmptyState(context, l10n)
                : _buildEventsList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noEventsRecordedForDay,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList(BuildContext context) {
    // CUR-585: Sort entries by start time ASC (earliest first) to match home page
    final sortedEntries = List<DiaryEntryView>.from(entries)
      ..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: sortedEntries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        return EventListItem(
          view: entry,
          // Only epistaxis entries are editable; day-markers render but the tap
          // is inert.
          onTap: entry is EpistaxisEntryView ? () => onEditEvent(entry) : null,
          hasOverlap: _hasOverlap(entry),
        );
      },
    );
  }
}
