// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'dart:async';

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:clinical_diary/widgets/yesterday_banner.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Main home screen showing recent events and recording button
class HomeScreen extends StatefulWidget {

  const HomeScreen({
    required this.nosebleedService, super.key,
  });
  final NosebleedService nosebleedService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<NosebleedRecord> _records = [];
  bool _hasYesterdayRecords = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);

    final records = await widget.nosebleedService.getLocalRecords();
    final hasYesterday = await widget.nosebleedService.hasRecordsForYesterday();

    setState(() {
      _records = records;
      _hasYesterdayRecords = hasYesterday;
      _isLoading = false;
    });
  }

  Future<void> _navigateToRecording() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RecordingScreen(
          nosebleedService: widget.nosebleedService,
        ),
      ),
    );

    if (result ?? false) {
      unawaited(_loadRecords());
    }
  }

  Future<void> _handleYesterdayNoNosebleeds() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await widget.nosebleedService.markNoNosebleeds(yesterday);
    unawaited(_loadRecords());
  }

  Future<void> _handleYesterdayHadNosebleeds() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RecordingScreen(
          nosebleedService: widget.nosebleedService,
          initialDate: yesterday,
        ),
      ),
    );

    if (result ?? false) {
      unawaited(_loadRecords());
    }
  }

  Future<void> _handleYesterdayDontRemember() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await widget.nosebleedService.markUnknown(yesterday);
    unawaited(_loadRecords());
  }

  List<_GroupedRecords> _groupRecordsByDay() {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

    final groups = <_GroupedRecords>[];

    // Get incomplete records first
    final incompleteRecords = _records
        .where((r) => r.isIncomplete && r.isRealEvent)
        .toList();

    if (incompleteRecords.isNotEmpty) {
      groups.add(_GroupedRecords(
        label: 'Incomplete Records',
        records: incompleteRecords,
        isIncomplete: true,
      ));
    }

    // Yesterday's records
    final yesterdayRecords = _records.where((r) {
      final dateStr = DateFormat('yyyy-MM-dd').format(r.date);
      return dateStr == yesterdayStr && r.isRealEvent && !r.isIncomplete;
    }).toList()
      ..sort((a, b) => (a.startTime ?? a.date).compareTo(b.startTime ?? b.date));

    groups.add(_GroupedRecords(
      label: 'Yesterday',
      date: yesterday,
      records: yesterdayRecords,
    ));

    // Today's records
    final todayRecords = _records.where((r) {
      final dateStr = DateFormat('yyyy-MM-dd').format(r.date);
      return dateStr == todayStr && r.isRealEvent && !r.isIncomplete;
    }).toList()
      ..sort((a, b) => (a.startTime ?? a.date).compareTo(b.startTime ?? b.date));

    groups.add(_GroupedRecords(
      label: 'Today',
      date: today,
      records: todayRecords,
    ));

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groupedRecords = _groupRecordsByDay();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo placeholder
                  const Icon(Icons.medical_services_outlined, size: 28),
                  Text(
                    'Nosebleed Diary',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_outline),
                    onPressed: () {
                      // TODO: Profile screen
                    },
                  ),
                ],
              ),
            ),

            // Yesterday banner if no records
            if (!_hasYesterdayRecords && !_isLoading)
              YesterdayBanner(
                onNoNosebleeds: _handleYesterdayNoNosebleeds,
                onHadNosebleeds: _handleYesterdayHadNosebleeds,
                onDontRemember: _handleYesterdayDontRemember,
              ),

            // Records list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadRecords,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: groupedRecords.length,
                        itemBuilder: (context, index) {
                          final group = groupedRecords[index];
                          return _buildGroup(context, group);
                        },
                      ),
                    ),
            ),

            // Bottom action area
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Main record button
                  SizedBox(
                    width: double.infinity,
                    height: 140,
                    child: FilledButton(
                      onPressed: _navigateToRecording,
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 48),
                          SizedBox(height: 8),
                          Text(
                            'Record Nosebleed',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Calendar button
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Calendar screen
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Calendar'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
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

  Widget _buildGroup(BuildContext context, _GroupedRecords group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider with label
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  group.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: group.isIncomplete ? FontWeight.bold : FontWeight.normal,
                    color: group.isIncomplete
                        ? Colors.orange.shade700
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
        ),

        // Date display
        if (group.date != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Center(
              child: Text(
                DateFormat('EEEE, MMMM d, y').format(group.date!),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ),

        // Records or empty state
        if (group.records.isEmpty && !group.isIncomplete)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                'no events ${group.label.toLowerCase()}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          )
        else
          ...group.records.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: EventListItem(
                record: record,
                onTap: () {
                  // TODO: Edit record
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupedRecords {

  _GroupedRecords({
    required this.label,
    required this.records, this.date,
    this.isIncomplete = false,
  });
  final String label;
  final DateTime? date;
  final List<NosebleedRecord> records;
  final bool isIncomplete;
}
