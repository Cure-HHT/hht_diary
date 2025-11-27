// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'dart:async';

import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:clinical_diary/widgets/yesterday_banner.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Main home screen showing recent events and recording button
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.nosebleedService,
    required this.enrollmentService,
    super.key,
  });
  final NosebleedService nosebleedService;
  final EnrollmentService enrollmentService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<NosebleedRecord> _records = [];
  bool _hasYesterdayRecords = false;
  bool _isLoading = true;
  List<NosebleedRecord> _incompleteRecords = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);

    final records = await widget.nosebleedService.getLocalRecords();
    final hasYesterday = await widget.nosebleedService.hasRecordsForYesterday();

    // Get incomplete records
    final incomplete = records
        .where((r) => r.isIncomplete && r.isRealEvent)
        .toList();

    setState(() {
      _records = records;
      _hasYesterdayRecords = hasYesterday;
      _incompleteRecords = incomplete;
      _isLoading = false;
    });
  }

  Future<void> _navigateToRecording() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RecordingScreen(
          nosebleedService: widget.nosebleedService,
          enrollmentService: widget.enrollmentService,
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
          enrollmentService: widget.enrollmentService,
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

  Future<void> _handleIncompleteRecordsClick() async {
    if (_incompleteRecords.isEmpty) return;

    // Navigate to edit the first incomplete record
    final firstIncomplete = _incompleteRecords.first;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RecordingScreen(
          nosebleedService: widget.nosebleedService,
          enrollmentService: widget.enrollmentService,
          initialDate: firstIncomplete.date,
          existingRecord: firstIncomplete,
        ),
      ),
    );

    if (result ?? false) {
      unawaited(_loadRecords());
    }
  }

  void _showLogoMenu(BuildContext context) {
    // TODO: Implement logo menu with:
    // - Add Example Data
    // - Reset All Data
    // - NOSE Study Questionnaire
    // - Quality of Life Survey
    // - End Clinical Trial (if enrolled)
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logo menu - coming soon')));
  }

  void _showUserMenu(BuildContext context) {
    // TODO: Implement user menu with:
    // - Accessibility and Preferences
    // - Privacy and Data Protection
    // - Enroll in Clinical Trial
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('User menu - coming soon')));
  }

  List<_GroupedRecords> _groupRecordsByDay() {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

    final groups = <_GroupedRecords>[];

    // Get incomplete records that are older than yesterday
    final olderIncompleteRecords =
        _records.where((r) {
          if (!r.isIncomplete || !r.isRealEvent) return false;
          final dateStr = DateFormat('yyyy-MM-dd').format(r.date);
          return dateStr != todayStr && dateStr != yesterdayStr;
        }).toList()..sort(
          (a, b) => (a.startTime ?? a.date).compareTo(b.startTime ?? b.date),
        );

    if (olderIncompleteRecords.isNotEmpty) {
      groups.add(
        _GroupedRecords(
          label: 'incomplete records',
          records: olderIncompleteRecords,
          isIncomplete: true,
        ),
      );
    }

    // Yesterday's records (excluding incomplete ones shown above)
    final yesterdayRecords =
        _records.where((r) {
          final dateStr = DateFormat('yyyy-MM-dd').format(r.date);
          return dateStr == yesterdayStr && r.isRealEvent;
        }).toList()..sort(
          (a, b) => (a.startTime ?? a.date).compareTo(b.startTime ?? b.date),
        );

    // Check if there are ANY records for yesterday (including special events)
    final hasAnyYesterdayRecords = _records.any((r) {
      final dateStr = DateFormat('yyyy-MM-dd').format(r.date);
      return dateStr == yesterdayStr;
    });

    groups.add(
      _GroupedRecords(
        label: 'yesterday',
        date: yesterday,
        records: yesterdayRecords,
        isEmpty: !hasAnyYesterdayRecords,
      ),
    );

    // Today's records
    final todayRecords =
        _records.where((r) {
          final dateStr = DateFormat('yyyy-MM-dd').format(r.date);
          return dateStr == todayStr && r.isRealEvent;
        }).toList()..sort(
          (a, b) => (a.startTime ?? a.date).compareTo(b.startTime ?? b.date),
        );

    // Check if there are ANY records for today (including special events)
    final hasAnyTodayRecords = _records.any((r) {
      final dateStr = DateFormat('yyyy-MM-dd').format(r.date);
      return dateStr == todayStr;
    });

    groups.add(
      _GroupedRecords(
        label: 'today',
        date: today,
        records: todayRecords,
        isEmpty: !hasAnyTodayRecords,
      ),
    );

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groupedRecords = _groupRecordsByDay();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with interactive logo and user menu
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Interactive logo
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.medical_services_outlined, size: 28),
                    tooltip: 'App settings menu',
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'add_example',
                        child: Row(
                          children: [
                            Icon(Icons.data_usage, size: 20),
                            SizedBox(width: 12),
                            Text('Add Example Data'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reset_data',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_forever,
                              size: 20,
                              color: Colors.red,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Reset All Data',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'nose_study',
                        child: Row(
                          children: [
                            Icon(Icons.description, size: 20),
                            SizedBox(width: 12),
                            Text('NOSE Study Questionnaire'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'quality_life',
                        child: Row(
                          children: [
                            Icon(Icons.assignment_turned_in, size: 20),
                            SizedBox(width: 12),
                            Text('Quality of Life Survey'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'end_trial',
                        child: Row(
                          children: [
                            Icon(Icons.group_off, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text(
                              'End Clinical Trial',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      _showLogoMenu(context);
                    },
                  ),

                  // Title
                  Text(
                    'Nosebleed Diary',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // User menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.person_outline, size: 28),
                    tooltip: 'User settings menu',
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'accessibility',
                        child: Row(
                          children: [
                            Icon(Icons.accessibility_new, size: 20),
                            SizedBox(width: 12),
                            Text('Accessibility and Preferences'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'privacy',
                        child: Row(
                          children: [
                            Icon(Icons.privacy_tip, size: 20),
                            SizedBox(width: 12),
                            Text('Privacy and Data Protection'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'enroll',
                        child: Row(
                          children: [
                            Icon(Icons.group_add, size: 20),
                            SizedBox(width: 12),
                            Text('Enroll in Clinical Trial'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      _showUserMenu(context);
                    },
                  ),
                ],
              ),
            ),

            // Banners section
            if (!_isLoading) ...[
              // Incomplete records banner (orange)
              if (_incompleteRecords.isNotEmpty)
                InkWell(
                  onTap: _handleIncompleteRecordsClick,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_incompleteRecords.length} incomplete record${_incompleteRecords.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          'Tap to complete →',
                          style: TextStyle(
                            color: Colors.orange.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Active questionnaire banner (blue) - placeholder
              // TODO: Add questionnaire functionality

              // Yesterday confirmation banner (yellow)
              if (!_hasYesterdayRecords)
                YesterdayBanner(
                  onNoNosebleeds: _handleYesterdayNoNosebleeds,
                  onHadNosebleeds: _handleYesterdayHadNosebleeds,
                  onDontRemember: _handleYesterdayDontRemember,
                ),
            ],

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
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Missing data button (placeholder)
                  // TODO: Add missing data functionality

                  // Main record button - large red button
                  SizedBox(
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Get screen height
                        final screenHeight = MediaQuery.of(context).size.height;
                        // Calculate 25vh (25% of viewport height)
                        final buttonHeight = screenHeight * 0.25;
                        // Ensure minimum height of 160px
                        final finalHeight = buttonHeight < 160
                            ? 160.0
                            : buttonHeight;

                        return SizedBox(
                          height: finalHeight,
                          child: FilledButton(
                            onPressed: _navigateToRecording,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 4,
                              shadowColor: Colors.black.withValues(alpha: 0.3),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, size: 48),
                                SizedBox(height: 12),
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
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Calendar button
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Calendar screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Calendar - coming soon')),
                      );
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
        // Divider with label (only show for incomplete records section)
        if (group.isIncomplete)
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
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),

        // Date display for today and yesterday
        if (group.date != null && !group.isIncomplete)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Column(
              children: [
                if (group.label != 'incomplete records')
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          group.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, MMMM d, y').format(group.date!),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

        // Records or empty state
        if (group.isEmpty || (group.records.isEmpty && !group.isIncomplete))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                'no events ${group.label}',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
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
                onTap: () async {
                  // Navigate to edit record
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecordingScreen(
                        nosebleedService: widget.nosebleedService,
                        enrollmentService: widget.enrollmentService,
                        initialDate: record.date,
                        existingRecord: record,
                      ),
                    ),
                  );

                  if (result ?? false) {
                    unawaited(_loadRecords());
                  }
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
    required this.records,
    this.date,
    this.isIncomplete = false,
    this.isEmpty = false,
  });
  final String label;
  final DateTime? date;
  final List<NosebleedRecord> records;
  final bool isIncomplete;
  final bool isEmpty;
}
