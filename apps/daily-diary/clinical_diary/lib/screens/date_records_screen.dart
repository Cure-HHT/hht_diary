// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: Mobile App Diary Entry

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/utils/date_time_formatter.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Screen showing all events for a specific date with edit capability.
///
/// Consumes [DiaryEntry] rows directly from the materialized view; the
/// `currentAnswers['startTime']` and `currentAnswers['endTime']` answer fields
/// drive overlap detection.
class DateRecordsScreen extends StatelessWidget {
  const DateRecordsScreen({
    required this.date,
    required this.entries,
    required this.onAddEvent,
    required this.onEditEvent,
    super.key,
  });

  final DateTime date;
  final List<DiaryEntry> entries;
  final VoidCallback onAddEvent;
  final void Function(DiaryEntry) onEditEvent;

  String get _formattedDate => DateFormat('EEEE, MMMM d, y').format(date);

  String _eventCountText(AppLocalizations l10n) {
    return l10n.eventCount(entries.length);
  }

  /// Returns the start and end DateTimes from `currentAnswers`, or null if
  /// the entry's answer payload doesn't carry a parseable time range (e.g.
  /// no_epistaxis_event / unknown_day_event).
  ({DateTime? start, DateTime? end}) _timeRange(DiaryEntry entry) {
    DateTime? parse(Object? raw) =>
        raw is String ? DateTimeFormatter.parse(raw) : null;
    return (
      start: parse(entry.currentAnswers['startTime']),
      end: parse(entry.currentAnswers['endTime']),
    );
  }

  /// Check if an entry overlaps with any other entry in the list.
  /// CUR-443: Used to show warning icon on overlapping events
  bool _hasOverlap(DiaryEntry entry) {
    if (entry.entryType != 'epistaxis_event') return false;
    final r = _timeRange(entry);
    if (r.start == null || r.end == null) return false;

    for (final other in entries) {
      if (other.entryId == entry.entryId) continue;
      if (other.entryType != 'epistaxis_event') continue;
      final or = _timeRange(other);
      if (or.start == null || or.end == null) continue;
      if (r.start!.isBefore(or.end!) && r.end!.isAfter(or.start!)) {
        return true;
      }
    }
    return false;
  }

  /// Sort key: epistaxis_event entries use their startTime; other entry types
  /// fall back to effectiveDate (or updatedAt).
  DateTime _sortKey(DiaryEntry entry) {
    final start = _timeRange(entry).start;
    return start ?? entry.effectiveDate ?? entry.updatedAt;
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
    final sortedEntries = List<DiaryEntry>.from(entries)
      ..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: sortedEntries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        return EventListItem(
          entry: entry,
          onTap: () => onEditEvent(entry),
          hasOverlap: _hasOverlap(entry),
        );
      },
    );
  }
}
