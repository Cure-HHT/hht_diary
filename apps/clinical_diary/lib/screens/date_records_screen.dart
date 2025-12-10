// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: Mobile App Diary Entry

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Screen showing all events for a specific date with edit capability
class DateRecordsScreen extends StatelessWidget {
  const DateRecordsScreen({
    required this.date,
    required this.records,
    required this.onAddEvent,
    required this.onEditEvent,
    super.key,
  });

  final DateTime date;
  final List<NosebleedRecord> records;
  final VoidCallback onAddEvent;
  final void Function(NosebleedRecord) onEditEvent;

  String get _formattedDate => DateFormat('EEEE, MMMM d, y').format(date);

  String _eventCountText(AppLocalizations l10n) {
    return l10n.eventCount(records.length);
  }

  /// Check if a record overlaps with any other record in the list
  /// CUR-443: Used to show warning icon on overlapping events
  bool _hasOverlap(NosebleedRecord record) {
    if (!record.isRealNosebleedEvent || record.endTime == null) {
      return false;
    }

    for (final other in records) {
      // Skip same record
      if (other.id == record.id) continue;

      // Only check real events with both start and end times
      if (!other.isRealNosebleedEvent || other.endTime == null) {
        continue;
      }

      // Check if events overlap
      if (record.startTime.isBefore(other.endTime!) &&
          record.endTime!.isAfter(other.startTime)) {
        return true;
      }
    }
    return false;
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
            if (records.isNotEmpty)
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
            child: records.isEmpty
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
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: records.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final record = records[index];
        return EventListItem(
          record: record,
          onTap: () => onEditEvent(record),
          hasOverlap: _hasOverlap(record),
        );
      },
    );
  }
}
