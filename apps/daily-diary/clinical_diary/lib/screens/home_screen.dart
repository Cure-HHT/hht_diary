// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-CAL-p00020: Patient Disconnection Workflow
//   REQ-CAL-p00077: Disconnection Notification
//   REQ-CAL-p00076: Participation Status Badge
//   REQ-CAL-p00080: Questionnaire Study Event Association (cycle label stamp)
//   REQ-CAL-p00081: Patient Task System
//   REQ-p01065:    Clinical Questionnaire System (D: deactivate sync; not-participating reset)

import 'dart:async';
import 'dart:convert';

import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/calendar_screen.dart';
import 'package:clinical_diary/screens/clinical_trial_enrollment_screen.dart';
import 'package:clinical_diary/screens/feature_flags_screen.dart';
import 'package:clinical_diary/screens/profile_screen.dart';
import 'package:clinical_diary/screens/questionnaire_placeholder_screen.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/screens/settings_screen.dart';
import 'package:clinical_diary/screens/simple_recording_screen.dart';
import 'package:clinical_diary/services/auth_service.dart';
import 'package:clinical_diary/services/clinical_diary_bootstrap.dart';
import 'package:clinical_diary/services/diary_export_service.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/file_read_service.dart';
import 'package:clinical_diary/services/file_save_service.dart';
import 'package:clinical_diary/services/notification_poll_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/services/reset_data_service.dart';
import 'package:clinical_diary/services/sponsor_branding_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/utils/app_page_route.dart';
import 'package:clinical_diary/utils/date_time_formatter.dart';
import 'package:clinical_diary/widgets/disconnection_banner.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:clinical_diary/widgets/flash_highlight.dart';
import 'package:clinical_diary/widgets/logo_menu.dart';
import 'package:clinical_diary/widgets/task_list_widget.dart';
import 'package:clinical_diary/widgets/yesterday_banner.dart';
import 'package:eq/eq.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:trial_data_types/trial_data_types.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

/// Main home screen showing recent events and recording button
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.runtime,
    required this.deviceId,
    required this.enrollmentService,
    required this.taskService,
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
    required this.onLargerTextChanged,
    required this.preferencesService,
    this.onFontChanged,
    this.onEnrolled,
    this.clock = DateTime.now,
    super.key,
  });

  /// Returns the current moment for time-relative writes (yesterday-banner
  /// handlers). Defaults to [DateTime.now]; tests inject a fixed clock so the
  /// stored `date` answer is verifiable.
  final DateTime Function() clock;

  /// Composed runtime — exposes [ClinicalDiaryRuntime.backend] for the wedge
  /// banner, [ClinicalDiaryRuntime.entryService] for writes, and
  /// [ClinicalDiaryRuntime.reader] for diary-shaped queries.
  final ClinicalDiaryRuntime runtime;

  /// Persistent device install UUID. Stamped into the export payload so the
  /// downstream tooling can identify which device produced the JSON dump.
  final String deviceId;
  final EnrollmentService enrollmentService;
  // REQ-CAL-p00081: Task service for questionnaire task management
  final TaskService taskService;
  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<bool> onThemeModeChanged;
  // CUR-488: Callback for larger text preference changes
  final ValueChanged<bool> onLargerTextChanged;
  // CUR-528: Callback for font selection changes
  final ValueChanged<String>? onFontChanged;
  final PreferencesService preferencesService;
  // REQ-CAL-p00082: Called after successful linking to register FCM token
  final VoidCallback? onEnrolled;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  /// Materialized nosebleed-related entries (epistaxis_event,
  /// no_epistaxis_event, unknown_day_event), tombstones excluded.
  List<DiaryEntry> _entries = [];
  bool _hasYesterdayRecords = false;
  bool _isLoading = true;

  /// Subset of [_entries] that are checkpointed but not finalized.
  List<DiaryEntry> _incompleteEntries = [];

  /// CUR-1292: aggregate ids of questionnaires the patient has started
  /// but not yet submitted, surfaced to [TaskListWidget] so the
  /// matching task card renders an "In progress" pill.
  Set<String> _wipQuestionnaireAggregateIds = const <String>{};

  /// CUR-1294: finalized, non-tombstoned questionnaire entries
  /// (entryType endsWith `_survey`). Surfaced in the yesterday section
  /// and used to derive the blue-dot indicator passed into the calendar
  /// overlay.
  List<DiaryEntry> _completedQuestionnaireEntries = [];
  bool _isEnrolled = false;
  bool _useAnimation = true; // User preference for animations
  bool _compactView = false; // User preference for compact list view
  // Wedge banner state — refreshed on init and on resume.
  bool _hasWedgedFifo = false;

  // REQ-CAL-p00077: Disconnection banner state
  bool _isDisconnected = false;
  String? _siteName;
  String? _sitePhoneNumber;

  // CUR-464: Track record to flash/highlight after save
  String? _flashRecordId;
  final ScrollController _scrollController = ScrollController();

  /// CUR-1292: Re-entrancy guard so a double-tap on the questionnaire
  /// task can't push two identical [QuestionnaireFlowScreen] modals.
  bool _questionnaireRouteActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRecords();
    _loadPreferences();
    _checkEnrollmentStatus();
    _checkDisconnectionStatus();
    _checkNotParticipatingStatus();
    _refreshWedgeStatus();
    // CUR-1164: React immediately when a background sync detects disconnection
    widget.enrollmentService.disconnectedNotifier.addListener(
      _onDisconnectionChanged,
    );
    // CUR-1311: React when a `mark_not_participating` / `reactivate` FCM
    // (or any background sync) flips not-participating state, so feature
    // flags reset without the patient having to navigate to profile.
    widget.enrollmentService.notParticipatingNotifier.addListener(
      _onNotParticipatingChanged,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshWedgeStatus();
    }
  }

  Future<void> _refreshWedgeStatus() async {
    final wedged = await widget.runtime.backend.anyFifoWedged();
    if (mounted) {
      setState(() => _hasWedgedFifo = wedged);
    }
  }

  SponsorBrandingConfig sponsorBranding = SponsorBrandingConfig.fallback;
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
    WidgetsBinding.instance.removeObserver(this);
    widget.enrollmentService.disconnectedNotifier.removeListener(
      _onDisconnectionChanged,
    );
    widget.enrollmentService.notParticipatingNotifier.removeListener(
      _onNotParticipatingChanged,
    );
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkEnrollmentStatus() async {
    final isEnrolled = await widget.enrollmentService.isEnrolled();
    final enrollment = await widget.enrollmentService.getEnrollment();
    try {
      if (enrollment?.sponsorId != null) {
        sponsorBranding = await SponsorBrandingService().fetchBranding(
          enrollment!.sponsorId!,
        );
      }
    } catch (e) {
      debugPrint('Sponsor branding unavailable, using fallback: $e');
    }
    if (mounted) {
      setState(() {
        _isEnrolled = isEnrolled;
      });
    }
  }

  /// REQ-CAL-p00077: Check if patient is disconnected from the study.
  /// Seeds [_isDisconnected] from SharedPreferences and syncs the notifier
  /// so the initial persisted state is reflected in the banner on startup.
  Future<void> _checkDisconnectionStatus() async {
    final isDisconnected = await widget.enrollmentService.isDisconnected();
    // Seed the notifier from the persisted value so it stays in sync
    widget.enrollmentService.disconnectedNotifier.value = isDisconnected;
    // REQ-CAL-p00065: Get site contact info for disconnection banner
    final enrollment = await widget.enrollmentService.getEnrollment();
    if (mounted) {
      setState(() {
        _isDisconnected = isDisconnected;
        _siteName = enrollment?.siteName;
        _sitePhoneNumber = enrollment?.sitePhoneNumber;
      });
    }
  }

  /// CUR-1164: Called immediately when background sync detects disconnection.
  /// Only reads from the notifier — does NOT call isDisconnected() or
  /// _checkDisconnectionStatus() to avoid a race with the in-flight
  /// SharedPreferences write inside setDisconnected().
  void _onDisconnectionChanged() {
    if (!mounted) return;
    final isDisconnected = widget.enrollmentService.disconnectedNotifier.value;
    setState(() => _isDisconnected = isDisconnected);
    if (isDisconnected) {
      // Clear cached tasks — disconnected patients have no valid questionnaires
      unawaited(widget.taskService.clearAll());
      // Refresh site name/phone for the banner contact details
      unawaited(_refreshSiteInfo());
    } else {
      // CUR-1164: On reconnect, kick the FIFO drain immediately so any events
      // recorded while the gate was closed ship without waiting up to 15
      // minutes for the next periodic tick.
      unawaited(widget.runtime.syncCycle());
    }
  }

  /// CUR-1311: Mirror of [_onDisconnectionChanged] for the
  /// not-participating notifier. When the patient flips into
  /// not-participating, sponsor-specific feature flags must reset to
  /// neutral defaults (REQ-p01065-D). On reactivation we leave flags
  /// alone — they re-hydrate from sponsor config on next launch.
  void _onNotParticipatingChanged() {
    if (!mounted) return;
    if (widget.enrollmentService.notParticipatingNotifier.value) {
      FeatureFlagService.instance.resetToDefaults();
    }
  }

  /// Refresh site name and phone number from stored enrollment data.
  Future<void> _refreshSiteInfo() async {
    final enrollment = await widget.enrollmentService.getEnrollment();
    if (mounted) {
      setState(() {
        _siteName = enrollment?.siteName;
        _sitePhoneNumber = enrollment?.sitePhoneNumber;
      });
    }
  }

  /// CUR-1165: Check if patient is marked as not participating (REQ-p01065-D).
  /// When true, sponsor-specific feature flags are reset to defaults so the
  /// app falls back to neutral behavior.
  Future<void> _checkNotParticipatingStatus() async {
    final isNotParticipating = await widget.enrollmentService
        .isNotParticipating();
    if (isNotParticipating) {
      FeatureFlagService.instance.resetToDefaults();
    }
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);

    // Wide range covers all real entries; the reader filters by local-day.
    final allEntries = await widget.runtime.reader.entriesForDateRange(
      DateTime.utc(1970, 1, 1),
      DateTime.utc(9999, 1, 1),
    );
    final entries =
        allEntries
            .where(
              (e) =>
                  !e.isDeleted &&
                  (e.entryType == 'epistaxis_event' ||
                      e.entryType == 'no_epistaxis_event' ||
                      e.entryType == 'unknown_day_event'),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final hasYesterday = await widget.runtime.reader.hasEntriesForYesterday();

    // Get incomplete real-nosebleed entries.
    final incomplete = entries
        .where((e) => !e.isComplete && e.entryType == 'epistaxis_event')
        .toList();

    // CUR-1292: aggregate ids of in-progress questionnaire surveys.
    // Surfaced to the task list so the matching task card shows the
    // "In progress" pill — patients see at a glance that tapping the
    // task will resume rather than restart. Derived from `allEntries`
    // (already loaded above with a 1970..9999 range) instead of a
    // separate `reader.incompleteEntries()` call to avoid a duplicate
    // backend query on every refresh.
    final wipQIds = <String>{
      for (final e in allEntries)
        if (!e.isComplete &&
            !e.isDeleted &&
            (e.entryType == 'nose_hht_survey' || e.entryType == 'qol_survey'))
          e.entryId,
    };

    // CUR-1294: finalized questionnaire submissions (any *_survey entry
    // type). The yesterday section surfaces yesterday's submissions;
    // the calendar overlay uses the union of dates to render a blue-dot
    // indicator.
    final questionnaires =
        allEntries
            .where(
              (e) =>
                  !e.isDeleted &&
                  e.isComplete &&
                  e.entryType.endsWith('_survey'),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    setState(() {
      _entries = entries;
      _hasYesterdayRecords = hasYesterday;
      _incompleteEntries = incomplete;
      _wipQuestionnaireAggregateIds = wipQIds;
      _completedQuestionnaireEntries = questionnaires;
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
                entryService: widget.runtime.entryService,
                enrollmentService: widget.enrollmentService,
                preferencesService: widget.preferencesService,
                allEntries: _entries,
              )
            : RecordingScreen(
                entryService: widget.runtime.entryService,
                enrollmentService: widget.enrollmentService,
                preferencesService: widget.preferencesService,
                allEntries: _entries,
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
    final yesterday = widget.clock().subtract(const Duration(days: 1));
    await widget.runtime.entryService.record(
      entryType: 'no_epistaxis_event',
      aggregateId: const Uuid().v7(),
      eventType: 'finalized',
      answers: <String, Object?>{'date': DateTimeFormatter.format(yesterday)},
    );
    unawaited(_loadRecords());
  }

  Future<void> _handleYesterdayHadNosebleeds() async {
    final yesterday = widget.clock().subtract(const Duration(days: 1));
    // CUR-464: Result is now record ID (String) instead of bool
    // CUR-508: Use feature flag to determine which recording screen to show
    final useOnePage = FeatureFlagService.instance.useOnePageRecordingScreen;
    final result = await Navigator.push<String?>(
      context,
      AppPageRoute(
        builder: (context) => useOnePage
            ? SimpleRecordingScreen(
                entryService: widget.runtime.entryService,
                enrollmentService: widget.enrollmentService,
                preferencesService: widget.preferencesService,
                initialStartDate: yesterday,
                allEntries: _entries,
              )
            : RecordingScreen(
                entryService: widget.runtime.entryService,
                enrollmentService: widget.enrollmentService,
                preferencesService: widget.preferencesService,
                diaryEntryDate: yesterday,
                allEntries: _entries,
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
    final yesterday = widget.clock().subtract(const Duration(days: 1));
    await widget.runtime.entryService.record(
      entryType: 'unknown_day_event',
      aggregateId: const Uuid().v7(),
      eventType: 'finalized',
      answers: <String, Object?>{'date': DateTimeFormatter.format(yesterday)},
    );
    unawaited(_loadRecords());
  }

  /// Export the local event log as JSON via [DiaryExportService] and hand the
  /// payload to the platform file-save dialog.
  ///
  /// Import is deferred to a follow-up ticket — re-importing the JSON would
  /// require translating legacy event shapes back to the new
  /// `EntryService.record` API, which would be a one-shot adapter. The button
  /// stays in the menu so the spec/UX surface is preserved; tapping it shows
  /// a "not implemented" message.
  Future<void> _handleExportData() async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final exportService = DiaryExportService(
        backend: widget.runtime.backend,
        deviceId: widget.deviceId,
      );

      final result = await exportService.exportAll();

      const encoder = JsonEncoder.withIndent('  ');
      final jsonData = encoder.convert(result.payload);

      final saved = await FileSaveService.saveFile(
        fileName: result.filename,
        data: jsonData,
        dialogTitle: l10n.exportData,
      );

      if (saved) {
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

  /// Round-trip companion to [_handleExportData]: pick a JSON export file,
  /// decode it, and feed every event back through `EventStore.ingestEvent`
  /// via [DiaryExportService.importAll]. The library handles idempotency,
  /// so re-importing the same export against the same backend is a no-op.
  ///
  /// On success we show a SnackBar carrying the imported / duplicate /
  /// skipped counts and refresh the home screen so any newly-ingested
  /// entries surface immediately.
  Future<void> _handleImportData() async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final pickResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        dialogTitle: l10n.importData,
      );

      if (pickResult == null || pickResult.files.isEmpty) {
        // User cancelled the picker — nothing to do.
        return;
      }

      final picked = pickResult.files.single;
      final path = picked.path;
      if (path == null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(l10n.importFailed('no path on selected file')),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      final raw = await FileReadService.readFile(path);
      if (raw == null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(l10n.importFailed('unable to read file')),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(l10n.importFailed('not a diary export object')),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      final importer = DiaryExportService(
        backend: widget.runtime.backend,
        deviceId: widget.deviceId,
        eventStore: widget.runtime.eventStore,
      );

      final result = await importer.importAll(decoded);

      // Refresh the home screen so any newly-ingested entries surface.
      await _loadRecords();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result.imported} events, '
            '${result.duplicates} duplicates, '
            '${result.skipped} skipped.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } on FormatException catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.importFailed(e.message)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e, stack) {
      debugPrint('Import error: $e\n$stack');
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
      final service = ResetDataService(
        // Option (b): construct a local AuthService instance here rather than
        // adding authService to the HomeScreen constructor — avoids touching
        // main.dart and multiple test call sites. AuthService is stateless
        // beyond its FlutterSecureStorage field, so a fresh instance is safe.
        authService: AuthService(),
        taskService: widget.taskService,
        runtime: widget.runtime,
      );
      try {
        await service.resetEverything();
      } catch (e, st) {
        debugPrint('[HomeScreen] Reset All Data failed: $e\n$st');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reset failed: $e'),
              duration: const Duration(seconds: 4),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
      // Datastore is now closed/deleted; do NOT call _loadRecords here.
      // Fire _checkEnrollmentStatus without awaiting (matches the
      // _handleEndClinicalTrial pattern) so the snackbar renders before
      // any navigation away from the home screen.
      unawaited(_checkEnrollmentStatus());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.allDataReset),
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
      await widget.taskService.clearAll();
      // CUR-1311 P1B.5 / REQ-d00169-K: Clear notification cursor on
      // lifecycle reset so the next enrollment starts with a fresh window.
      await NotificationPollService.clearCursor();
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

  /// REQ-CAL-p00076: Navigate to profile screen with participation status badge
  Future<void> _handleShowProfile() async {
    // Read all values fresh from the service to avoid stale cached state
    // (initState calls are async and may not have settled yet on first open).
    final enrollment = await widget.enrollmentService.getEnrollment();
    final isDisconnected = await widget.enrollmentService.isDisconnected();
    final isNotParticipating = await widget.enrollmentService
        .isNotParticipating();
    final notParticipatingAt = await widget.enrollmentService
        .getNotParticipatingAt();
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
            // CUR-1114: Re-open profile to show participation status badge after linking
            if (_isEnrolled && mounted) {
              await _handleShowProfile();
            }
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
          isDisconnected: isDisconnected,
          isNotParticipating: isNotParticipating,
          enrollmentStatus: _isEnrolled ? 'active' : 'none',
          isSharingWithCureHHT: false,
          sponsorLogo: sponsorBranding.appLogoUrl,
          userName: 'User',
          onUpdateUserName: (name) {
            // TODO: Implement username update
          },
          enrollmentCode: enrollment?.linkingCode,
          enrollmentDateTime: enrollment?.enrolledAt,
          enrollmentEndDateTime: notParticipatingAt,
          siteName: _siteName,
          sitePhoneNumber: _sitePhoneNumber,
        ),
      ),
    );
    // Refresh linking status after returning from profile
    await _checkEnrollmentStatus();
    await _checkDisconnectionStatus();
    await _checkNotParticipatingStatus();
  }

  // REQ-p01067, REQ-p01068, REQ-p01070, REQ-p01071: Navigate to questionnaire.
  //
  // The QuestionnaireDefinition is loaded from the bundled
  // packages/trial_data_types/assets/data/questionnaires.json asset (the same
  // source loadClinicalDiaryEntryTypes uses to build EntryTypeDefinitions).
  // Submission writes a finalized survey event via EntryService.record.
  Future<void> _navigateToQuestionnaire(Task task) async {
    final qType = task.questionnaireType;

    // Only NOSE HHT and QoL have full implementations
    if (qType == null ||
        (qType != QuestionnaireType.noseHht &&
            qType != QuestionnaireType.qol)) {
      // Fallback to placeholder for unsupported types (e.g., EQ)
      if (!mounted) return;
      await Navigator.of(context).push(
        AppPageRoute<void>(
          builder: (context) => QuestionnairePlaceholderScreen(task: task),
        ),
      );
      return;
    }

    final definition = await _loadQuestionnaireDefinition(qType);
    if (definition == null || !mounted) return;
    if (_questionnaireRouteActive) return;

    final aggregateId = task.targetId ?? task.id;
    final entryType = '${qType.value}_survey';
    // CUR-1292: when an in-progress (checkpointed-but-not-finalized) row
    // already exists for this aggregate, seed the flow with the prior
    // responses so tap-task and resume-on-launch land the patient in
    // the same place. Without this, tapping a task with prior state
    // would open a fresh flow whose first answer would overwrite the
    // saved responses (the materializer replaces the `responses` key
    // wholesale on every checkpoint).
    final initialResponses = await _readInitialResponses(
      entryType: entryType,
      aggregateId: aggregateId,
    );
    if (!mounted) return;

    _questionnaireRouteActive = true;
    try {
      await Navigator.of(context).push(
        AppPageRoute<void>(
          builder: (context) => QuestionnaireFlowScreen(
            definition: definition,
            instanceId: aggregateId,
            initialResponses: initialResponses,
            onSubmit: (submission) async {
              try {
                await _recordSurveySubmission(
                  entryType: entryType,
                  aggregateId: aggregateId,
                  submission: submission,
                  studyEvent: task.studyEvent,
                );
                return const SubmitResult(success: true);
              } catch (e) {
                return SubmitResult(success: false, error: e.toString());
              }
            },
            // CUR-1292: persist a checkpoint after every answer so the flow
            // can resume after the app is killed mid-questionnaire. The
            // study_event cycle label is stamped on every checkpoint of a
            // freshly-started survey; subsequent checkpoints (from the
            // resume modal) rely on the materializer's key-wise merge to
            // preserve it.
            onCheckpoint: (partial) {
              unawaited(
                widget.runtime.entryService.record(
                  entryType: entryType,
                  aggregateId: aggregateId,
                  eventType: 'checkpoint',
                  answers: <String, Object?>{
                    ...partial.toJson(),
                    'study_event': ?task.studyEvent,
                  },
                  checkpointReason: 'in-progress',
                ),
              );
            },
            onComplete: () {
              // CUR-1292: Don't remove the task on patient submit. The
              // sponsor's contract is that a patient-completed
              // questionnaire stays editable until the portal
              // coordinator clicks Finalize. While status is
              // 'ready_to_review' on the server, /tasks keeps returning
              // it; once the coordinator finalizes, server status flips
              // to 'finalized', /tasks drops it, and the next
              // task-sync removes it from the local list. Tombstones
              // from portalInboundPoll do the same thing through a
              // different path. Either way, the diary follows the
              // server, not the patient's submit.
              Navigator.of(context).pop();
            },
            onDefer: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } finally {
      _questionnaireRouteActive = false;
    }
    // CUR-1292: refresh the WIP set so the "In progress" pill appears
    // (or disappears) on the task card based on what landed during the
    // flow — the patient may have answered some questions and Home'd
    // out, or they may have fully submitted.
    if (mounted) {
      unawaited(_loadRecords());
    }
  }

  /// Cached questionnaire definitions, lazy-loaded once from the bundled asset.
  static List<QuestionnaireDefinition>? _cachedQuestionnaires;

  Future<QuestionnaireDefinition?> _loadQuestionnaireDefinition(
    QuestionnaireType type,
  ) async {
    final cached = _cachedQuestionnaires;
    final defs =
        cached ??
        QuestionnaireDefinition.loadAll(
          await rootBundle.loadString(
            'packages/trial_data_types/assets/data/questionnaires.json',
          ),
        );
    _cachedQuestionnaires = defs;
    return QuestionnaireDefinition.findById(defs, type.value);
  }

  /// Append the canonical "questionnaire finalized" event to the local
  /// log. The payload is `submission.toJson()` (snake_case keys: full
  /// `responses` list, `instance_id`, `questionnaire_type`, `version`,
  /// `completed_at`) plus an optional `study_event` cycle label
  /// (REQ-CAL-p00080). The ALCOA+ audit fact must be self-contained:
  /// the responses array carries `display_label` and `normalized_label`
  /// per entry so downstream consumers do not need to re-derive them
  /// from the questionnaire definition at read time.
  Future<void> _recordSurveySubmission({
    required String entryType,
    required String aggregateId,
    required QuestionnaireSubmission submission,
    String? studyEvent,
  }) async {
    await widget.runtime.entryService.record(
      entryType: entryType,
      aggregateId: aggregateId,
      eventType: 'finalized',
      answers: <String, Object?>{
        ...submission.toJson(),
        'study_event': ?studyEvent,
      },
    );
  }

  /// CUR-1292: handle a tap on a completed-questionnaire entry rendered
  /// in the today/yesterday list. If the matching task still exists
  /// (server status is in {sent, in_progress, ready_to_review}), route
  /// to the editable flow — the same path as tapping the task at the
  /// top of the screen. If no matching task exists, the portal has
  /// finalized the submission; open the flow in view-only mode so the
  /// patient can verify the answers but cannot edit or re-submit.
  Future<void> _onQuestionnaireEntryTapped(DiaryEntry entry) async {
    Task? matchingTask;
    for (final t in widget.taskService.tasks) {
      if ((t.targetId ?? t.id) == entry.entryId) {
        matchingTask = t;
        break;
      }
    }
    if (matchingTask != null) {
      await _navigateToQuestionnaire(matchingTask);
      return;
    }

    // Finalized path. Resolve the questionnaire definition from the
    // entry's currentAnswers; without a definition we have no labels
    // to render, so we silently bail.
    if (_questionnaireRouteActive) return;
    final qTypeStr = entry.currentAnswers['questionnaire_type'];
    QuestionnaireType? qType;
    if (qTypeStr is String) {
      try {
        qType = QuestionnaireType.fromValue(qTypeStr);
      } catch (_) {
        qType = null;
      }
    }
    if (qType == null) return;
    final definition = await _loadQuestionnaireDefinition(qType);
    if (definition == null || !mounted) return;
    final initialResponses = _parseSurveyResponses(entry.currentAnswers);
    if (initialResponses.isEmpty || !mounted) return;

    _questionnaireRouteActive = true;
    try {
      await Navigator.of(context).push(
        AppPageRoute<void>(
          builder: (context) => QuestionnaireFlowScreen(
            definition: definition,
            instanceId: entry.entryId,
            initialResponses: initialResponses,
            isReadOnly: true,
            // onSubmit / onCheckpoint are unreachable in read-only mode
            // (no Submit button, no answer taps), but the flow's API
            // requires non-null callbacks. Provide harmless no-ops.
            onSubmit: (_) async => const SubmitResult(success: true),
            onComplete: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } finally {
      _questionnaireRouteActive = false;
    }
  }

  /// Read prior responses for [aggregateId] from the materialized view,
  /// or `null` when no row exists yet. Used by
  /// [_navigateToQuestionnaire] to seed the flow on every re-tap.
  ///
  /// CUR-1292: seed regardless of `isComplete`. A questionnaire that
  /// the patient has already submitted (isComplete=true,
  /// server-side status='ready_to_review') stays editable until the
  /// portal coordinator clicks Finalize. Tombstoned rows
  /// (`isDeleted=true`) return null — the patient should never see
  /// stale post-tombstone state.
  Future<List<QuestionResponse>?> _readInitialResponses({
    required String entryType,
    required String aggregateId,
  }) async {
    final rows = await widget.runtime.backend.findEntries(entryType: entryType);
    for (final row in rows) {
      if (row.entryId == aggregateId && !row.isDeleted) {
        return _parseSurveyResponses(row.currentAnswers);
      }
    }
    return null;
  }

  /// Parse the `responses` list out of a survey's materialized answers map.
  ///
  /// The materializer merges every `partial.toJson()` payload into
  /// `current_answers`, which means the most recent checkpoint's full
  /// `responses` array (List of question_id/value/display_label/
  /// normalized_label maps) is the live truth for resume.
  static List<QuestionResponse> _parseSurveyResponses(
    Map<String, Object?> answers,
  ) {
    final raw = answers['responses'];
    if (raw is! List) return const <QuestionResponse>[];
    final result = <QuestionResponse>[];
    for (final entry in raw) {
      if (entry is Map) {
        result.add(QuestionResponse.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    return result;
  }

  Future<void> _handleIncompleteRecordsClick() async {
    if (_incompleteEntries.isEmpty) return;

    // Navigate to edit the first incomplete entry
    // CUR-508: Use feature flag to determine which recording screen to show
    final useOnePage = FeatureFlagService.instance.useOnePageRecordingScreen;
    final firstIncomplete = _incompleteEntries.first;
    final firstStart = _readStartTime(firstIncomplete);

    Future<void> tombstone(String reason) async {
      await widget.runtime.entryService.record(
        entryType: firstIncomplete.entryType,
        aggregateId: firstIncomplete.entryId,
        eventType: 'tombstone',
        answers: const <String, Object?>{},
        changeReason: reason,
      );
      unawaited(_loadRecords());
    }

    final result = await Navigator.push<bool>(
      context,
      AppPageRoute(
        builder: (context) => useOnePage
            ? SimpleRecordingScreen(
                entryService: widget.runtime.entryService,
                enrollmentService: widget.enrollmentService,
                preferencesService: widget.preferencesService,
                initialStartDate: firstStart,
                existingEntry: firstIncomplete,
                allEntries: _entries,
                onDelete: tombstone,
              )
            : RecordingScreen(
                entryService: widget.runtime.entryService,
                enrollmentService: widget.enrollmentService,
                preferencesService: widget.preferencesService,
                diaryEntryDate: firstStart,
                existingEntry: firstIncomplete,
                allEntries: _entries,
                onDelete: tombstone,
              ),
      ),
    );

    if (result ?? false) {
      unawaited(_loadRecords());
    }
  }

  Future<void> _navigateToEditRecord(DiaryEntry entry) async {
    // CUR-464: Result is now record ID (String) instead of bool
    // CUR-508: Use feature flag to determine which recording screen to show
    final useOnePage = FeatureFlagService.instance.useOnePageRecordingScreen;

    Future<void> tombstone(String reason) async {
      await widget.runtime.entryService.record(
        entryType: entry.entryType,
        aggregateId: entry.entryId,
        eventType: 'tombstone',
        answers: const <String, Object?>{},
        changeReason: reason,
      );
      unawaited(_loadRecords());
    }

    final result = await Navigator.push<String?>(
      context,
      AppPageRoute(
        builder: (context) => useOnePage
            ? SimpleRecordingScreen(
                entryService: widget.runtime.entryService,
                enrollmentService: widget.enrollmentService,
                preferencesService: widget.preferencesService,
                existingEntry: entry,
                allEntries: _entries,
                onDelete: tombstone,
              )
            : RecordingScreen(
                entryService: widget.runtime.entryService,
                enrollmentService: widget.enrollmentService,
                preferencesService: widget.preferencesService,
                existingEntry: entry,
                allEntries: _entries,
                onDelete: tombstone,
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

  /// Read the `startTime` answer from a [DiaryEntry], or fall back to its
  /// effective date / updated-at.
  static DateTime _readStartTime(DiaryEntry entry) {
    final raw = entry.currentAnswers['startTime'];
    if (raw is String) return DateTimeFormatter.parse(raw);
    return entry.effectiveDate ?? entry.updatedAt;
  }

  /// Read the `endTime` answer from a [DiaryEntry] (null when absent).
  static DateTime? _readEndTime(DiaryEntry entry) {
    final raw = entry.currentAnswers['endTime'];
    if (raw is String) return DateTimeFormatter.parse(raw);
    return null;
  }

  /// Check if an entry overlaps with any other entry in the list.
  /// CUR-443: Used to show warning icon on overlapping events
  bool _hasOverlap(DiaryEntry entry) {
    if (entry.entryType != 'epistaxis_event') return false;
    final start = _readStartTime(entry);
    final end = _readEndTime(entry);
    if (end == null) return false;

    for (final other in _entries) {
      if (other.entryId == entry.entryId) continue;
      if (other.entryType != 'epistaxis_event') continue;
      final otherEnd = _readEndTime(other);
      if (otherEnd == null) continue;
      final otherStart = _readStartTime(other);
      if (start.isBefore(otherEnd) && end.isAfter(otherStart)) {
        return true;
      }
    }
    return false;
  }

  List<_GroupedRecords> _groupRecordsByDay(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = widget.clock();
    final yesterday = today.subtract(const Duration(days: 1));

    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

    // Compare in local-calendar terms. Survey rows have no startTime
    // answer and fall back to effectiveDate / updatedAt, which are
    // recorded in UTC; without `.toLocal()` a 04:44Z event would format
    // to its UTC date and never match today's local date during the
    // evening of the same calendar day.
    String entryDateStr(DiaryEntry e) {
      return DateFormat('yyyy-MM-dd').format(_readStartTime(e).toLocal());
    }

    final groups = <_GroupedRecords>[];

    // Get incomplete real-nosebleed entries that are older than yesterday.
    final olderIncompleteEntries = _entries.where((e) {
      if (e.isComplete || e.entryType != 'epistaxis_event') return false;
      final dateStr = entryDateStr(e);
      return dateStr != todayStr && dateStr != yesterdayStr;
    }).toList()..sort((a, b) => _readStartTime(a).compareTo(_readStartTime(b)));

    if (olderIncompleteEntries.isNotEmpty) {
      groups.add(
        _GroupedRecords(
          label: l10n.incompleteRecords,
          entries: olderIncompleteEntries,
          isIncomplete: true,
        ),
      );
    }

    // Yesterday's nosebleed-related entries plus any completed
    // questionnaire submitted yesterday. Incomplete epistaxis entries land
    // here too (they're not strictly older than yesterday, so they're
    // excluded from `olderIncompleteEntries`).
    final yesterdayNosebleed = _entries.where((e) {
      return entryDateStr(e) == yesterdayStr &&
          e.entryType == 'epistaxis_event';
    });
    final yesterdayQuestionnaires = _completedQuestionnaireEntries.where(
      (e) => entryDateStr(e) == yesterdayStr,
    );
    final yesterdayEntries = [...yesterdayNosebleed, ...yesterdayQuestionnaires]
      ..sort((a, b) => _readStartTime(a).compareTo(_readStartTime(b)));

    // Check if there are ANY entries for yesterday (including special events
    // and completed questionnaires).
    final hasAnyYesterdayEntries =
        _entries.any((e) => entryDateStr(e) == yesterdayStr) ||
        _completedQuestionnaireEntries.any(
          (e) => entryDateStr(e) == yesterdayStr,
        );

    groups.add(
      _GroupedRecords(
        label: l10n.yesterday,
        date: yesterday,
        entries: yesterdayEntries,
        isEmpty: !hasAnyYesterdayEntries,
      ),
    );

    // Today's real-nosebleed entries (including incomplete - CUR-488),
    // plus any completed questionnaires submitted today (CUR-1292).
    final todayNosebleed = _entries.where((e) {
      return entryDateStr(e) == todayStr && e.entryType == 'epistaxis_event';
    });
    final todayQuestionnaires = _completedQuestionnaireEntries.where(
      (e) => entryDateStr(e) == todayStr,
    );
    final todayEntries = [...todayNosebleed, ...todayQuestionnaires]
      ..sort((a, b) => _readStartTime(a).compareTo(_readStartTime(b)));

    final hasAnyTodayEntries =
        _entries.any((e) => entryDateStr(e) == todayStr) ||
        _completedQuestionnaireEntries.any((e) => entryDateStr(e) == todayStr);

    groups.add(
      _GroupedRecords(
        label: l10n.today,
        date: today,
        entries: todayEntries,
        isEmpty: !hasAnyTodayEntries,
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
                    sponsorLogo: sponsorBranding.appLogoUrl,
                    onResetAllData: _handleResetAllData,
                    onFeatureFlags: _handleFeatureFlags,
                    isEnrolled: _isEnrolled,
                    onEndClinicalTrial: _isEnrolled
                        ? _handleEndClinicalTrial
                        : null,
                    onInstructionsAndFeedback: _handleInstructionsAndFeedback,
                    showDevTools: AppConfig.showDevTools,
                    showResetData: AppConfig.showResetData,
                  ),
                  // Centered title - CUR-488 Phase 2: Use FittedBox to scale on small screens.
                  // CUR-1292: tap the title to manually trigger a task-sync. This is
                  // the dev-mode fallback for environments without FCM (Linux desktop
                  // local-stack), where the patient otherwise has to wait up to the
                  // next periodic-trigger tick to discover a freshly-assigned
                  // questionnaire. Production keeps the same affordance — a manual
                  // pull is a reasonable patient gesture.
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        // CUR-1292: syncTasks must finish before
                        // _loadRecords so any tombstone events
                        // recorded for cancelled questionnaires have
                        // landed in the materialized view by the
                        // time the home screen re-reads it.
                        // Otherwise the timeline card for a
                        // just-cancelled questionnaire lingers until
                        // the next refresh.
                        await widget.taskService.syncTasks(
                          widget.enrollmentService,
                        );
                        if (!mounted) return;
                        unawaited(_loadRecords());
                        unawaited(_refreshWedgeStatus());
                      },
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppLocalizations.of(context).appTitle,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  // Profile menu on the right
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.person_outline),
                    tooltip: AppLocalizations.of(context).userMenu,
                    onSelected: (value) async {
                      if (value == 'profile') {
                        await _handleShowProfile();
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
                        final wasEnrolled = _isEnrolled;
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
                        // CUR-1114: Open profile only if enrollment state changed
                        if (!wasEnrolled && _isEnrolled && mounted) {
                          await _handleShowProfile();
                        }
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
                        // CUR-1055: Only show divider and enroll option when not yet enrolled
                        if (!_isEnrolled) ...[
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
                        ],
                      ];
                    },
                  ),
                ],
              ),
            ),

            // Banners section
            if (!_isLoading) ...[
              // Wedge banner: at least one destination FIFO is wedged on a
              // unknown event-type bridge mismatch — patient should update
              // the app to drain it.
              if (_hasWedgedFifo) const _SyncWedgedBanner(),

              // REQ-CAL-p00077: Disconnection banner (red, persistent, non-dismissible per REQ-p05004)
              if (_isDisconnected)
                DisconnectionBanner(
                  siteName: _siteName,
                  sitePhoneNumber: _sitePhoneNumber,
                ),

              // Incomplete records banner (orange)
              if (_incompleteEntries.isNotEmpty)
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
                                  _incompleteEntries.length,
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
              // CUR-1164: Hide while disconnected — no valid questionnaires.
              if (!_isDisconnected)
                TaskListWidget(
                  taskService: widget.taskService,
                  // REQ-CAL-p00081-D: Navigate to relevant screen.
                  // CUR-1292: cancelledQuestionnaire tasks dismiss on
                  // tap rather than navigating — they're passive
                  // notifications, not actionable items.
                  onTaskTap: (task) {
                    if (task.taskType == TaskType.cancelledQuestionnaire) {
                      widget.taskService.removeTask(task.id);
                      return;
                    }
                    _navigateToQuestionnaire(task);
                  },
                  // CUR-1292: render the "In progress" pill on tasks
                  // whose aggregate has a checkpointed-but-not-finalized
                  // row in the materialized view.
                  wipAggregateIds: _wipQuestionnaireAggregateIds,
                  // CUR-1292: hide the task entry once the patient has
                  // submitted (a `finalized` event landed locally) —
                  // it lives in the today/yesterday timeline from
                  // there until the portal Finalizes or tombstones.
                  submittedAggregateIds: <String>{
                    for (final e in _completedQuestionnaireEntries) e.entryId,
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
                      // CUR-1292: the dialog can return a *_survey
                      // DiaryEntry when the patient taps a completed
                      // questionnaire on the calendar's day-view; in
                      // that case we close the calendar and route the
                      // tap through the same handler used on the home
                      // timeline (editable vs read-only based on
                      // server status).
                      final result = await showDialog<DiaryEntry?>(
                        context: context,
                        builder: (context) => CalendarScreen(
                          entryService: widget.runtime.entryService,
                          reader: widget.runtime.reader,
                          enrollmentService: widget.enrollmentService,
                          preferencesService: widget.preferencesService,
                        ),
                      );
                      if (result != null &&
                          result.entryType.endsWith('_survey')) {
                        await _onQuestionnaireEntryTapped(result);
                      }
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
        if (group.entries.isEmpty && !group.isIncomplete)
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
          ...group.entries.map(
            (entry) => Padding(
              // CUR-489: Use GlobalKey for scroll-to-item functionality
              key: _getKeyForRecord(entry.entryId),
              // CUR-464: Use smaller gap when compact view is enabled
              padding: EdgeInsets.only(bottom: _compactView ? 4 : 8),
              // CUR-464: Wrap with FlashHighlight to animate new records
              child: FlashHighlight(
                flash: entry.entryId == _flashRecordId,
                enabled: _useAnimation,
                onFlashComplete: () {
                  if (mounted) {
                    setState(() {
                      _flashRecordId = null;
                    });
                  }
                },
                builder: (context, highlightColor) => EventListItem(
                  entry: entry,
                  onTap: entry.entryType.endsWith('_survey')
                      ? () => _onQuestionnaireEntryTapped(entry)
                      : () => _navigateToEditRecord(entry),
                  hasOverlap: _hasOverlap(entry),
                  highlightColor: highlightColor,
                  // CUR-1292: a questionnaire is "finalized" (locked)
                  // when its aggregate is no longer surfaced as a task.
                  // /tasks drops finalized rows server-side, and the
                  // next syncTasks removes the matching local task —
                  // so absence in TaskService is the correct test.
                  isFinalized:
                      entry.entryType.endsWith('_survey') &&
                      !widget.taskService.tasks.any(
                        (t) => (t.targetId ?? t.id) == entry.entryId,
                      ),
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
    required this.entries,
    this.date,
    this.isIncomplete = false,
    this.isEmpty = false,
  });
  final String label;
  final DateTime? date;
  final List<DiaryEntry> entries;
  final bool isIncomplete;
  final bool isEmpty;
}

/// Banner shown when at least one destination FIFO is wedged on a
/// `unknown_event_type` bridge.  Surfaces the situation so the patient
/// updates the app; underlying scope is "visible state", not UX polish.
class _SyncWedgedBanner extends StatelessWidget {
  const _SyncWedgedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_problem, color: Colors.red.shade800, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Some data is not syncing — please update the app.',
              style: TextStyle(
                color: Colors.red.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
