// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-CAL-p00020: Patient Disconnection Workflow
//   REQ-CAL-p00077: Disconnection Notification
//   REQ-CAL-p00076: Participation Status Badge
//   REQ-CAL-p00081: Patient Task System

import 'dart:async';
import 'dart:convert';

import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/screens/account_profile_screen.dart';
import 'package:clinical_diary/screens/calendar_screen.dart';
import 'package:clinical_diary/screens/clinical_trial_enrollment_screen.dart';
import 'package:clinical_diary/screens/feature_flags_screen.dart';
import 'package:clinical_diary/screens/login_screen.dart';
import 'package:clinical_diary/screens/profile_screen.dart';
import 'package:clinical_diary/screens/questionnaire_placeholder_screen.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/screens/settings_screen.dart';
import 'package:clinical_diary/screens/simple_recording_screen.dart';
import 'package:clinical_diary/services/auth_service.dart';
import 'package:clinical_diary/services/data_export_service.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/file_save_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/utils/app_page_route.dart';
import 'package:clinical_diary/widgets/disconnection_banner.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:clinical_diary/widgets/flash_highlight.dart';
import 'package:clinical_diary/widgets/logo_menu.dart';
import 'package:clinical_diary/widgets/task_list_widget.dart';
import 'package:clinical_diary/widgets/yesterday_banner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Main home screen showing recent events and recording button
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.nosebleedService,
    required this.enrollmentService,
    required this.authService,
    required this.taskService,
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
    required this.onLargerTextChanged,
    required this.preferencesService,
    this.onFontChanged,
    this.onEnrolled,
    super.key,
  });
  final NosebleedService nosebleedService;
  final EnrollmentService enrollmentService;
  final AuthService authService;
  // REQ-CAL-p00081: Task service for questionnaire task management
  final TaskService taskService;
  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<bool> onThemeModeChanged;
  // CUR-488: Callback for larger text preference changes
  final ValueChanged<bool> onLargerTextChanged;
  // CUR-528: Callback for font selection changes
  final ValueChanged<String>? onFontChanged;
  final PreferencesService preferencesService;
  // REQ-CAL-p00082: Called after successful enrollment to register FCM token
  final VoidCallback? onEnrolled;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<NosebleedRecord> _records = [];
  bool _hasYesterdayRecords = false;
  bool _isLoading = true;
  List<NosebleedRecord> _incompleteRecords = [];
  bool _isEnrolled = false;
  // ignore: unused_field
  bool _isLoggedIn = false;
  bool _useAnimation = true; // User preference for animations
  bool _compactView = false; // User preference for compact list view

  // REQ-CAL-p00077: Disconnection banner state
  bool _isDisconnected = false;
  bool _disconnectionBannerDismissed = false;
  String? _siteName;
  String? _sitePhoneNumber;

  // CUR-464: Track record to flash/highlight after save
  String? _flashRecordId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _loadPreferences();
    _checkEnrollmentStatus();
    _checkLoginStatus();
    _checkDisconnectionStatus();
    // REQ-CAL-p00077: Reset banner dismissed state on app start
    widget.enrollmentService.resetDisconnectionBannerDismissed();
  }

  Future<void> _loadPreferences() async {
    final useAnimation = await widget.preferencesService.getUseAnimation();
    final compactView = await widget.preferencesService.getCompactView();
    if (mounted) {
      setState(() {
        _useAnimation = useAnimation;
        _compactView = compactView;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await widget.authService.isLoggedIn();
    if (mounted) {
      setState(() => _isLoggedIn = isLoggedIn);
    }
  }

  /// Sync records from cloud and reload local records
  Future<void> _syncFromCloudAndReload() async {
    await widget.nosebleedService.fetchRecordsFromCloud();
    await _loadRecords();
    // REQ-CAL-p00077: Check disconnection status after sync
    await _checkDisconnectionStatus();
  }

  Future<void> _checkEnrollmentStatus() async {
    final isEnrolled = await widget.enrollmentService.isEnrolled();
    if (mounted) {
      setState(() => _isEnrolled = isEnrolled);
    }
  }

  /// REQ-CAL-p00077: Check if patient is disconnected from the study
  Future<void> _checkDisconnectionStatus() async {
    final isDisconnected = await widget.enrollmentService.isDisconnected();
    final bannerDismissed = await widget.enrollmentService
        .isDisconnectionBannerDismissed();
    // REQ-CAL-p00065: Get site contact info for disconnection banner
    final enrollment = await widget.enrollmentService.getEnrollment();
    if (mounted) {
      setState(() {
        _isDisconnected = isDisconnected;
        _disconnectionBannerDismissed = bannerDismissed;
        _siteName = enrollment?.siteName;
        _sitePhoneNumber = enrollment?.sitePhoneNumber;
      });
    }
  }

  /// REQ-CAL-p00077: Handle dismissing the disconnection banner
  Future<void> _handleDismissDisconnectionBanner() async {
    await widget.enrollmentService.setDisconnectionBannerDismissed(true);
    if (mounted) {
      setState(() => _disconnectionBannerDismissed = true);
    }
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);

    final records = await widget.nosebleedService.getLocalMaterializedRecords();
    final hasYesterday = await widget.nosebleedService.hasRecordsForYesterday();

    // Get incomplete records
    final incomplete = records
        .where((r) => r.isIncomplete && r.isRealNosebleedEvent)
        .toList();

    setState(() {
      _records = records;
      _hasYesterdayRecords = hasYesterday;
      _incompleteRecords = incomplete;
      _isLoading = false;
    });
  }

  Future<void> _navigateToRecording() async {
    // CUR-464: Result is now record ID (String) instead of bool
    // CUR-508: Use feature flag to determine which recording screen to show
    final useOnePage = FeatureFlagService.instance.useOnePageRecordingScreen;
    final result = await Navigator.push<String?>(
      context,
      AppPageRoute(
        builder: (context) => useOnePage
            ? SimpleRecordingScreen(
                nosebleedService: widget.nosebleedService,
                enrollmentService: widget.enrollmentService,
                preferencesService: widget.preferencesService,
                allRecords: _records,
              )
            : RecordingScreen(
                nosebleedService: widget.nosebleedService,
                enrollmentService: widget.enrollmentService,
                preferencesService: widget.preferencesService,
                allRecords: _records,
              ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _flashRecordId = result;
      });
      await _loadRecords();
      _scrollToRecord(result);
    }
  }

  // CUR-489: Track GlobalKeys for each record to enable scroll-to-item
  final Map<String, GlobalKey> _recordKeys = {};

  /// Get or create a GlobalKey for a record
  GlobalKey _getKeyForRecord(String recordId) {
    return _recordKeys.putIfAbsent(recordId, GlobalKey.new);
  }

  /// Scroll to a specific record in the list and ensure it's visible.
  /// CUR-489: Uses Scrollable.ensureVisible to scroll to actual item position
  void _scrollToRecord(String recordId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _recordKeys[recordId];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.3, // Position item 30% from top for visibility
        );
      }
    });
  }

  Future<void> _handleYesterdayNoNosebleeds() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await widget.nosebleedService.markNoNosebleeds(yesterday);
    unawaited(_loadRecords());
  }

  Future<void> _handleYesterdayHadNosebleeds() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    // CUR-464: Result is now record ID (String) instead of bool
    // CUR-508: Use feature flag to determine which recording screen to show
    final useOnePage = FeatureFlagService.instance.useOnePageRecordingScreen;
    final result = await Navigator.push<String?>(
      context,
      AppPageRoute(
        builder: (context) => useOnePage
            ? SimpleRecordingScreen(
                nosebleedService: widget.nosebleedService,
                enrollmentService: widget.enrollmentService,
                preferencesService: widget.preferencesService,
                initialStartDate: yesterday,
                allRecords: _records,
              )
            : RecordingScreen(
                nosebleedService: widget.nosebleedService,
                enrollmentService: widget.enrollmentService,
                preferencesService: widget.preferencesService,
                diaryEntryDate: yesterday,
                allRecords: _records,
              ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _flashRecordId = result;
      });
      await _loadRecords();
      _scrollToRecord(result);
    }
  }

  Future<void> _handleYesterdayDontRemember() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await widget.nosebleedService.markUnknown(yesterday);
    unawaited(_loadRecords());
  }

  Future<void> _handleExportData() async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final exportService = DataExportService(
        nosebleedService: widget.nosebleedService,
        preferencesService: widget.preferencesService,
        enrollmentService: widget.enrollmentService,
      );

      final jsonData = await exportService.exportAppState();
      final filename = exportService.generateExportFilename();

      // Save file using platform-aware service
      final result = await FileSaveService.saveFile(
        fileName: filename,
        data: jsonData,
        dialogTitle: l10n.exportData,
      );

      if (result) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(l10n.exportSuccess),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Export error: $e');
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.exportFailed),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleImportData() async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importConfirmTitle),
        content: Text(l10n.importConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: l10n.importData,
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(l10n.importFailed('Could not read file')),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      final jsonData = utf8.decode(file.bytes!);

      final exportService = DataExportService(
        nosebleedService: widget.nosebleedService,
        preferencesService: widget.preferencesService,
        enrollmentService: widget.enrollmentService,
      );

      final importResult = await exportService.importAppState(jsonData);

      if (importResult.success) {
        unawaited(_loadRecords());
        unawaited(_loadPreferences());

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(l10n.importSuccess(importResult.recordsImported)),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.importFailed(importResult.error ?? 'Unknown error'),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Import error: $e');
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.importFailed(e.toString())),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleResetAllData() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.resetAllData),
        content: Text(l10n.resetAllDataMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.reset),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      // ignore: invalid_use_of_visible_for_testing_member
      await widget.nosebleedService.clearLocalData();
      unawaited(_loadRecords());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).allDataReset),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _handleFeatureFlags() {
    Navigator.push(
      context,
      AppPageRoute<void>(builder: (context) => const FeatureFlagsScreen()),
    );
  }

  Future<void> _handleEndClinicalTrial() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.endClinicalTrial),
        content: Text(l10n.endClinicalTrialMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.endTrial),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await widget.enrollmentService.clearEnrollment();
      unawaited(_checkEnrollmentStatus());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).leftClinicalTrial),
            duration: const Duration(seconds: 2),
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

  Future<void> _handleLogin() async {
    await Navigator.push(
      context,
      AppPageRoute<void>(
        builder: (context) => LoginScreen(
          authService: widget.authService,
          onLoginSuccess: () {
            unawaited(_checkLoginStatus());
            // Fetch user's synced data from cloud after login
            unawaited(_syncFromCloudAndReload());
          },
        ),
      ),
    );
    unawaited(_checkLoginStatus());
  }

  Future<void> _handleLogout() async {
    // Check if user has stored credentials to remind them
    final hasCredentials = await widget.authService.hasStoredCredentials();

    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logout),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.savedCredentialsQuestion),
            const SizedBox(height: 16),
            if (hasCredentials)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.credentialsAvailableInAccount,
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.yesLogout),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      // Show syncing progress dialog (fire-and-forget, closed after sync)
      if (mounted) {
        unawaited(
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 24),
                  Text(AppLocalizations.of(context).syncingData),
                ],
              ),
            ),
          ),
        );
      }

      // Sync records before logout
      final syncResult = await widget.nosebleedService
          .syncAllRecordsWithResult();

      // Close progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (!syncResult.isSuccess) {
        // Sync failed - show error and don't logout
        if (mounted) {
          final l10nError = AppLocalizations.of(context);
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10nError.syncFailed),
              content: Text(
                '${l10nError.syncFailedMessage}\n\n'
                'Error: ${syncResult.errorMessage}',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10nError.ok),
                ),
              ],
            ),
          );
        }
        return; // Don't logout
      }

      // Sync succeeded - proceed with logout
      await widget.authService.logout();
      unawaited(_checkLoginStatus());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).loggedOut),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleShowAccountProfile() async {
    await Navigator.push(
      context,
      AppPageRoute<void>(
        builder: (context) =>
            AccountProfileScreen(authService: widget.authService),
      ),
    );
  }

  /// REQ-CAL-p00076: Navigate to profile screen with participation status badge
  Future<void> _handleShowProfile() async {
    final enrollment = await widget.enrollmentService.getEnrollment();
    if (!mounted) return;
    await Navigator.push(
      context,
      AppPageRoute<void>(
        builder: (context) => ProfileScreen(
          onBack: () => Navigator.pop(context),
          onStartClinicalTrialEnrollment: () async {
            Navigator.pop(context);
            await Navigator.push(
              context,
              AppPageRoute<void>(
                builder: (context) => ClinicalTrialEnrollmentScreen(
                  enrollmentService: widget.enrollmentService,
                ),
              ),
            );
            await _checkEnrollmentStatus();
            if (_isEnrolled) {
              widget.onEnrolled?.call();
            }
            await _checkDisconnectionStatus();
          },
          onShowSettings: () async {
            await Navigator.push(
              context,
              AppPageRoute<void>(
                builder: (context) => SettingsScreen(
                  preferencesService: widget.preferencesService,
                  onLanguageChanged: widget.onLocaleChanged,
                  onThemeModeChanged: widget.onThemeModeChanged,
                  onLargerTextChanged: widget.onLargerTextChanged,
                  onFontChanged: widget.onFontChanged,
                ),
              ),
            );
            await _loadPreferences();
          },
          onShareWithCureHHT: () {
            // TODO: Implement CureHHT data sharing
          },
          onStopSharingWithCureHHT: () {
            // TODO: Implement stop sharing
          },
          isEnrolledInTrial: _isEnrolled,
          isDisconnected: _isDisconnected,
          enrollmentStatus: _isEnrolled ? 'active' : 'none',
          isSharingWithCureHHT: false,
          userName: 'User',
          onUpdateUserName: (name) {
            // TODO: Implement username update
          },
          enrollmentCode: enrollment?.patientId,
          enrollmentDateTime: enrollment?.enrolledAt,
          siteName: _siteName,
          sitePhoneNumber: _sitePhoneNumber,
        ),
      ),
    );
    // Refresh enrollment status after returning from profile
    await _checkEnrollmentStatus();
    await _checkDisconnectionStatus();
  }

  Future<void> _handleIncompleteRecordsClick() async {
    if (_incompleteRecords.isEmpty) return;

    // Navigate to edit the first incomplete record
    // CUR-508: Use feature flag to determine which recording screen to show
    final useOnePage = FeatureFlagService.instance.useOnePageRecordingScreen;
    final firstIncomplete = _incompleteRecords.first;
    final result = await Navigator.push<bool>(
      context,
      AppPageRoute(
        builder: (context) => useOnePage
            ? SimpleRecordingScreen(
                nosebleedService: widget.nosebleedService,
                enrollmentService: widget.enrollmentService,
                preferencesService: widget.preferencesService,
                initialStartDate: firstIncomplete.startTime,
                existingRecord: firstIncomplete,
                allRecords: _records,
                onDelete: (reason) async {
                  await widget.nosebleedService.deleteRecord(
                    recordId: firstIncomplete.id,
                    reason: reason,
                  );
                  unawaited(_loadRecords());
                },
              )
            : RecordingScreen(
                nosebleedService: widget.nosebleedService,
                enrollmentService: widget.enrollmentService,
                preferencesService: widget.preferencesService,
                diaryEntryDate: firstIncomplete.startTime,
                existingRecord: firstIncomplete,
                allRecords: _records,
                onDelete: (reason) async {
                  await widget.nosebleedService.deleteRecord(
                    recordId: firstIncomplete.id,
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

  Future<void> _navigateToEditRecord(NosebleedRecord record) async {
    // CUR-464: Result is now record ID (String) instead of bool
    // CUR-508: Use feature flag to determine which recording screen to show
    final useOnePage = FeatureFlagService.instance.useOnePageRecordingScreen;
    final result = await Navigator.push<String?>(
      context,
      AppPageRoute(
        builder: (context) => useOnePage
            ? SimpleRecordingScreen(
                nosebleedService: widget.nosebleedService,
                enrollmentService: widget.enrollmentService,
                preferencesService: widget.preferencesService,
                initialStartDate: null,
                existingRecord: record,
                allRecords: _records,
                onDelete: (reason) async {
                  await widget.nosebleedService.deleteRecord(
                    recordId: record.id,
                    reason: reason,
                  );
                  unawaited(_loadRecords());
                },
              )
            : RecordingScreen(
                nosebleedService: widget.nosebleedService,
                enrollmentService: widget.enrollmentService,
                preferencesService: widget.preferencesService,
                diaryEntryDate: null,
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

    if (result != null && result.isNotEmpty) {
      setState(() {
        _flashRecordId = result;
      });
      await _loadRecords();
      _scrollToRecord(result);
    }
  }

  /// Check if a record overlaps with any other record in the list
  /// CUR-443: Used to show warning icon on overlapping events
  bool _hasOverlap(NosebleedRecord record) {
    if (!record.isRealNosebleedEvent || record.endTime == null) {
      return false;
    }

    for (final other in _records) {
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

  List<_GroupedRecords> _groupRecordsByDay(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

    final groups = <_GroupedRecords>[];

    // Get incomplete records that are older than yesterday
    final olderIncompleteRecords = _records.where((r) {
      if (!r.isIncomplete || !r.isRealNosebleedEvent) return false;
      final dateStr = DateFormat('yyyy-MM-dd').format(r.startTime);
      return dateStr != todayStr && dateStr != yesterdayStr;
    }).toList()..sort((a, b) => (a.startTime).compareTo(b.startTime));

    if (olderIncompleteRecords.isNotEmpty) {
      groups.add(
        _GroupedRecords(
          label: l10n.incompleteRecords,
          records: olderIncompleteRecords,
          isIncomplete: true,
        ),
      );
    }

    // Yesterday's records (excluding incomplete ones shown above)
    final yesterdayRecords = _records.where((r) {
      final dateStr = DateFormat('yyyy-MM-dd').format(r.startTime);
      return dateStr == yesterdayStr && r.isRealNosebleedEvent;
    }).toList()..sort((a, b) => (a.startTime).compareTo(b.startTime));

    // Check if there are ANY records for yesterday (including special events)
    final hasAnyYesterdayRecords = _records.any((r) {
      final dateStr = DateFormat('yyyy-MM-dd').format(r.startTime);
      return dateStr == yesterdayStr;
    });

    groups.add(
      _GroupedRecords(
        label: l10n.yesterday,
        date: yesterday,
        records: yesterdayRecords,
        isEmpty: !hasAnyYesterdayRecords,
      ),
    );

    // Today's records (including incomplete - CUR-488)
    final todayRecords = _records.where((r) {
      final dateStr = DateFormat('yyyy-MM-dd').format(r.startTime);
      return dateStr == todayStr && r.isRealNosebleedEvent;
    }).toList()..sort((a, b) => (a.startTime).compareTo(b.startTime));

    // Check if there are ANY records for today (including special events)
    final hasAnyTodayRecords = _records.any((r) {
      final dateStr = DateFormat('yyyy-MM-dd').format(r.startTime);
      return dateStr == todayStr;
    });

    groups.add(
      _GroupedRecords(
        label: l10n.today,
        date: today,
        records: todayRecords,
        isEmpty: !hasAnyTodayRecords,
      ),
    );

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groupedRecords = _groupRecordsByDay(context);

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
                children: [
                  // Logo menu on the left
                  LogoMenu(
                    onExportData: _handleExportData,
                    onImportData: _handleImportData,
                    onResetAllData: _handleResetAllData,
                    onFeatureFlags: _handleFeatureFlags,
                    onEndClinicalTrial: _isEnrolled
                        ? _handleEndClinicalTrial
                        : null,
                    onInstructionsAndFeedback: _handleInstructionsAndFeedback,
                    showDevTools: AppConfig.showDevTools,
                  ),
                  // Centered title - CUR-488 Phase 2: Use FittedBox to scale on small screens
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppLocalizations.of(context).appTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  // Profile menu on the right
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.person_outline),
                    tooltip: AppLocalizations.of(context).userMenu,
                    onSelected: (value) async {
                      if (value == 'login') {
                        await _handleLogin();
                      } else if (value == 'logout') {
                        await _handleLogout();
                      } else if (value == 'profile') {
                        await _handleShowProfile();
                      } else if (value == 'account') {
                        await _handleShowAccountProfile();
                      } else if (value == 'accessibility') {
                        await Navigator.push(
                          context,
                          AppPageRoute<void>(
                            builder: (context) => SettingsScreen(
                              preferencesService: widget.preferencesService,
                              onLanguageChanged: widget.onLocaleChanged,
                              onThemeModeChanged: widget.onThemeModeChanged,
                              onLargerTextChanged: widget.onLargerTextChanged,
                              onFontChanged: widget.onFontChanged,
                            ),
                          ),
                        );
                        // Reload preferences in case they changed
                        await _loadPreferences();
                      } else if (value == 'privacy') {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(context).privacyComingSoon,
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else if (value == 'enroll') {
                        await Navigator.push(
                          context,
                          AppPageRoute<void>(
                            builder: (context) => ClinicalTrialEnrollmentScreen(
                              enrollmentService: widget.enrollmentService,
                            ),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) {
                      final l10n = AppLocalizations.of(context);
                      return [
                        // REQ-CAL-p00076: Profile menu item at top
                        PopupMenuItem(
                          value: 'profile',
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 20),
                              const SizedBox(width: 12),
                              Text(l10n.profile),
                            ],
                          ),
                        ),
                        // Login option hidden - linking code is the auth mechanism
                        // Account/Logout only shown if enrolled (linked to patient)
                        if (_isEnrolled) ...[
                          PopupMenuItem(
                            value: 'account',
                            child: Row(
                              children: [
                                const Icon(Icons.account_circle, size: 20),
                                const SizedBox(width: 12),
                                Text(l10n.account),
                              ],
                            ),
                          ),
                        ],
                        PopupMenuItem(
                          value: 'accessibility',
                          child: Row(
                            children: [
                              const Icon(Icons.settings, size: 20),
                              const SizedBox(width: 12),
                              Text(l10n.accessibilityAndPreferences),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'privacy',
                          child: Row(
                            children: [
                              const Icon(Icons.privacy_tip, size: 20),
                              const SizedBox(width: 12),
                              Text(l10n.privacy),
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
                              Text(l10n.enrollInClinicalTrial),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),
            ),

            // Banners section
            if (!_isLoading) ...[
              // REQ-CAL-p00077: Disconnection banner (red) - highest priority
              if (_isDisconnected && !_disconnectionBannerDismissed)
                DisconnectionBanner(
                  onDismiss: _handleDismissDisconnectionBanner,
                  siteName: _siteName,
                  sitePhoneNumber: _sitePhoneNumber,
                ),

              // Incomplete records banner (orange)
              if (_incompleteRecords.isNotEmpty)
                Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return InkWell(
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
                                l10n.incompleteRecordCount(
                                  _incompleteRecords.length,
                                ),
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              l10n.tapToComplete,
                              style: TextStyle(
                                color: Colors.orange.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              // REQ-CAL-p00081: Task list (questionnaires, etc.)
              TaskListWidget(
                taskService: widget.taskService,
                onTaskTap: (task) {
                  // REQ-CAL-p00081-D: Navigate to relevant screen
                  Navigator.of(context).push(
                    AppPageRoute<void>(
                      builder: (context) =>
                          QuestionnairePlaceholderScreen(task: task),
                    ),
                  );
                },
              ),

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
                      child: Scrollbar(
                        thumbVisibility: true,
                        controller: _scrollController,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: groupedRecords.length,
                          itemBuilder: (context, index) {
                            final group = groupedRecords[index];
                            return _buildGroup(context, group);
                          },
                        ),
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

                  // Main record button - compact red button
                  SizedBox(
                    width: double.infinity,
                    height: 80,
                    child: FilledButton(
                      onPressed: _navigateToRecording,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: Colors.black.withValues(alpha: 0.3),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, size: 32),
                          const SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context).recordNosebleed,
                            style: const TextStyle(
                              fontSize: 18,
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
                          preferencesService: widget.preferencesService,
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
                  DateFormat(
                    'EEEE, MMMM d, y',
                    Localizations.localeOf(context).languageCode,
                  ).format(group.date!),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
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
              // CUR-489: Use GlobalKey for scroll-to-item functionality
              key: _getKeyForRecord(record.id),
              // CUR-464: Use smaller gap when compact view is enabled
              padding: EdgeInsets.only(bottom: _compactView ? 4 : 8),
              // CUR-464: Wrap with FlashHighlight to animate new records
              child: FlashHighlight(
                flash: record.id == _flashRecordId,
                enabled: _useAnimation,
                onFlashComplete: () {
                  if (mounted) {
                    setState(() {
                      _flashRecordId = null;
                    });
                  }
                },
                builder: (context, highlightColor) => EventListItem(
                  record: record,
                  onTap: () => _navigateToEditRecord(record),
                  hasOverlap: _hasOverlap(record),
                  highlightColor: highlightColor,
                ),
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
