// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'dart:async';

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/screens/calendar_screen.dart';
import 'package:clinical_diary/screens/clinical_trial_enrollment_screen.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/screens/settings_screen.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:clinical_diary/widgets/logo_menu.dart';
import 'package:clinical_diary/widgets/yesterday_banner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Main home screen showing recent events and recording button
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.nosebleedService,
    required this.enrollmentService,
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
    required this.preferencesService,
    super.key,
  });
  final NosebleedService nosebleedService;
  final EnrollmentService enrollmentService;
  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<bool> onThemeModeChanged;
  final PreferencesService preferencesService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<NosebleedRecord> _records = [];
  bool _hasYesterdayRecords = false;
  bool _isLoading = true;
  bool _isEnrolled = false;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _checkEnrollmentStatus();
  }

  Future<void> _checkEnrollmentStatus() async {
    final isEnrolled = await widget.enrollmentService.isEnrolled();
    if (mounted) {
      setState(() => _isEnrolled = isEnrolled);
    }
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

  Future<void> _handleAddExampleData() async {
    // Add some example nosebleed records for demonstration
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final twoDaysAgo = now.subtract(const Duration(days: 2));

    await widget.nosebleedService.addRecord(
      date: twoDaysAgo,
      startTime: DateTime(twoDaysAgo.year, twoDaysAgo.month, twoDaysAgo.day, 9, 30),
      endTime: DateTime(twoDaysAgo.year, twoDaysAgo.month, twoDaysAgo.day, 9, 45),
      severity: NosebleedSeverity.dripping,
      notes: 'Example morning nosebleed',
    );

    await widget.nosebleedService.addRecord(
      date: yesterday,
      startTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 14, 0),
      endTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 14, 30),
      severity: NosebleedSeverity.steadyStream,
      notes: 'Example afternoon nosebleed',
    );

    unawaited(_loadRecords());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Example data added'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleResetAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Data?'),
        content: const Text(
          'This will permanently delete all your recorded data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await widget.nosebleedService.clearLocalData();
      unawaited(_loadRecords());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data has been reset'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleEndClinicalTrial() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Clinical Trial?'),
        content: const Text(
          'Are you sure you want to end your participation in the clinical trial? '
          'Your data will be retained but no longer synced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('End Trial'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await widget.enrollmentService.clearEnrollment();
      unawaited(_checkEnrollmentStatus());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have left the clinical trial'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleInstructionsAndFeedback() async {
    final url = Uri.parse('https://curehht.org/app-support');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _navigateToEditRecord(NosebleedRecord record) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RecordingScreen(
          nosebleedService: widget.nosebleedService,
          enrollmentService: widget.enrollmentService,
          initialDate: record.date,
          existingRecord: record,
          allRecords: _records,
          onDelete: (reason) async {
            await widget.nosebleedService.deleteRecord(
              recordId: record.id,
              reason: reason,
            );
            unawaited(_loadRecords());
          },
        ),
      ),
    );

    if (result ?? false) {
      unawaited(_loadRecords());
    }
  }

  List<_GroupedRecords> _groupRecordsByDay(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
        label: l10n.incompleteRecords,
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
      label: l10n.yesterday,
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
      label: l10n.today,
      date: today,
      records: todayRecords,
    ));

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groupedRecords = _groupRecordsByDay(context);

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
                  // Logo menu
                  LogoMenu(
                    onAddExampleData: _handleAddExampleData,
                    onResetAllData: _handleResetAllData,
                    onEndClinicalTrial: _isEnrolled ? _handleEndClinicalTrial : null,
                    onInstructionsAndFeedback: _handleInstructionsAndFeedback,
                  ),
                  Text(
                    AppLocalizations.of(context).appTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.person_outline),
                    tooltip: 'User menu',
                    onSelected: (value) async {
                      if (value == 'accessibility') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (context) => SettingsScreen(
                              preferencesService: widget.preferencesService,
                              onLanguageChanged: widget.onLocaleChanged,
                              onThemeModeChanged: widget.onThemeModeChanged,
                            ),
                          ),
                        );
                      } else if (value == 'privacy') {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Privacy settings coming soon'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else if (value == 'enroll') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (context) => ClinicalTrialEnrollmentScreen(
                              enrollmentService: widget.enrollmentService,
                            ),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'accessibility',
                        child: Row(
                          children: [
                            const Icon(Icons.settings, size: 20),
                            const SizedBox(width: 12),
                            Text(AppLocalizations.of(context).accessibilityAndPreferences),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'privacy',
                        child: Row(
                          children: [
                            const Icon(Icons.privacy_tip, size: 20),
                            const SizedBox(width: 12),
                            Text(AppLocalizations.of(context).privacy),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'enroll',
                        child: Row(
                          children: [
                            const Icon(Icons.group_add, size: 20),
                            const SizedBox(width: 12),
                            Text(AppLocalizations.of(context).enrollInClinicalTrial),
                          ],
                        ),
                      ),
                    ],
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context).recordNosebleed,
                            style: const TextStyle(
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
                    onPressed: () async {
                      await showDialog<void>(
                        context: context,
                        builder: (context) => CalendarScreen(
                          nosebleedService: widget.nosebleedService,
                          enrollmentService: widget.enrollmentService,
                        ),
                      );
                      unawaited(_loadRecords());
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(AppLocalizations.of(context).calendar),
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
                onTap: () => _navigateToEditRecord(record),
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
