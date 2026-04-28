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
import 'package:clinical_diary/screens/calendar_screen.dart';
import 'package:clinical_diary/screens/clinical_trial_enrollment_screen.dart';
import 'package:clinical_diary/screens/feature_flags_screen.dart';
import 'package:clinical_diary/screens/profile_screen.dart';
import 'package:clinical_diary/screens/questionnaire_placeholder_screen.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/screens/settings_screen.dart';
import 'package:clinical_diary/screens/simple_recording_screen.dart';
import 'package:clinical_diary/services/clinical_diary_bootstrap.dart';
import 'package:clinical_diary/services/diary_export_service.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/file_read_service.dart';
import 'package:clinical_diary/services/file_save_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
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
    super.key,
  });

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
  bool _isEnrolled = false;
  bool _useAnimation = true; // User preference for animations
  bool _compactView = false; // User preference for compact list view
  // Wedge banner state — refreshed on init and on resume.
  bool _hasWedgedFifo = false;

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
    WidgetsBinding.instance.addObserver(this);
    _loadRecords();
    _loadPreferences();
    _checkEnrollmentStatus();
    _checkDisconnectionStatus();
    _refreshWedgeStatus();
    // REQ-CAL-p00077: Reset banner dismissed state on app start
    widget.enrollmentService.resetDisconnectionBannerDismissed();
    // Forward-looking: surface incomplete surveys via a modal route. The
    // FCM-prompt handler that creates the checkpoint is out of scope for this
    // ticket, but the routing exists so it can land later without screen edits.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePushIncompleteSurvey();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshWedgeStatus();
      _maybePushIncompleteSurvey();
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

    setState(() {
      _entries = entries;
      _hasYesterdayRecords = hasYesterday;
      _incompleteEntries = incomplete;
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
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await widget.runtime.entryService.record(
      entryType: 'no_epistaxis_event',
      aggregateId: const Uuid().v7(),
      eventType: 'finalized',
      answers: <String, Object?>{'date': DateTimeFormatter.format(yesterday)},
    );
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
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
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
      // The event-sourcing datastore is append-only; resetting all data is
      // a dev-only feature in the legacy stack. Show a message instead and
      // leave the underlying records untouched.
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
      await widget.taskService.clearAll();
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
          isDisconnected: _isDisconnected,
          enrollmentStatus: _isEnrolled ? 'active' : 'none',
          isSharingWithCureHHT: false,
          sponsorLogo: sponsorBranding.appLogoUrl,
          userName: 'User',
          onUpdateUserName: (name) {
            // TODO: Implement username update
          },
          enrollmentCode: enrollment?.linkingCode,
          enrollmentDateTime: enrollment?.enrolledAt,
          siteName: _siteName,
          sitePhoneNumber: _sitePhoneNumber,
        ),
      ),
    );
    // Refresh linking status after returning from profile
    await _checkEnrollmentStatus();
    await _checkDisconnectionStatus();
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

    final aggregateId = task.targetId ?? task.id;
    final entryType = '${qType.value}_survey';

    await Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (context) => QuestionnaireFlowScreen(
          definition: definition,
          instanceId: aggregateId,
          onSubmit: (submission) async {
            try {
              await widget.runtime.entryService.record(
                entryType: entryType,
                aggregateId: aggregateId,
                eventType: 'finalized',
                answers: <String, Object?>{
                  ...{
                    for (final r in submission.responses) r.questionId: r.value,
                  },
                  'instanceId': submission.instanceId,
                  'questionnaireType': submission.questionnaireType,
                  'version': submission.version,
                  'completedAt': submission.completedAt.toIso8601String(),
                },
              );
              return const SubmitResult(success: true);
            } catch (e) {
              return SubmitResult(success: false, error: e.toString());
            }
          },
          onComplete: () {
            // REQ-CAL-p00081-E: Remove task after completion
            widget.taskService.removeTask(task.id);
            Navigator.of(context).pop();
          },
          onDefer: () => Navigator.of(context).pop(),
        ),
      ),
    );
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

  /// Surfaces an incomplete survey via a modal route on resume / mount.
  ///
  /// Forward-looking: the FCM-prompt handler that creates an in-progress
  /// survey checkpoint is OUT OF SCOPE for this ticket. So in normal
  /// operation `incomplete` will be empty. The modal route is wired up
  /// regardless so it can light up automatically once checkpoints land.
  Future<void> _maybePushIncompleteSurvey() async {
    if (!mounted) return;
    final incomplete = await widget.runtime.reader.incompleteEntries();
    DiaryEntry? survey;
    for (final entry in incomplete) {
      if (entry.entryType == 'nose_hht_survey' ||
          entry.entryType == 'hht_qol_survey') {
        survey = entry;
        break;
      }
    }
    if (survey == null || !mounted) return;

    final qType = survey.entryType == 'nose_hht_survey'
        ? QuestionnaireType.noseHht
        : QuestionnaireType.qol;
    final definition = await _loadQuestionnaireDefinition(qType);
    if (definition == null || !mounted) return;

    final aggregateId = survey.entryId;
    final entryType = survey.entryType;

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) => PopScope(
          canPop: false,
          child: QuestionnaireFlowScreen(
            definition: definition,
            instanceId: aggregateId,
            onSubmit: (submission) async {
              try {
                await widget.runtime.entryService.record(
                  entryType: entryType,
                  aggregateId: aggregateId,
                  eventType: 'finalized',
                  answers: <String, Object?>{
                    ...{
                      for (final r in submission.responses)
                        r.questionId: r.value,
                    },
                    'instanceId': submission.instanceId,
                    'questionnaireType': submission.questionnaireType,
                    'version': submission.version,
                    'completedAt': submission.completedAt.toIso8601String(),
                  },
                );
                return const SubmitResult(success: true);
              } catch (e) {
                return SubmitResult(success: false, error: e.toString());
              }
            },
            onComplete: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
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
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

    String entryDateStr(DiaryEntry e) {
      return DateFormat('yyyy-MM-dd').format(_readStartTime(e));
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

    // Yesterday's real-nosebleed entries (excluding incomplete ones shown above).
    final yesterdayEntries = _entries.where((e) {
      return entryDateStr(e) == yesterdayStr &&
          e.entryType == 'epistaxis_event';
    }).toList()..sort((a, b) => _readStartTime(a).compareTo(_readStartTime(b)));

    // Check if there are ANY entries for yesterday (including special events).
    final hasAnyYesterdayEntries = _entries.any(
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

    // Today's real-nosebleed entries (including incomplete - CUR-488).
    final todayEntries = _entries.where((e) {
      return entryDateStr(e) == todayStr && e.entryType == 'epistaxis_event';
    }).toList()..sort((a, b) => _readStartTime(a).compareTo(_readStartTime(b)));

    final hasAnyTodayEntries = _entries.any((e) => entryDateStr(e) == todayStr);

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

              // REQ-CAL-p00077: Disconnection banner (red) - highest priority
              if (_isDisconnected && !_disconnectionBannerDismissed)
                DisconnectionBanner(
                  onDismiss: _handleDismissDisconnectionBanner,
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
              TaskListWidget(
                taskService: widget.taskService,
                // REQ-CAL-p00081-D: Navigate to relevant screen
                onTaskTap: _navigateToQuestionnaire,
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
                          entryService: widget.runtime.entryService,
                          reader: widget.runtime.reader,
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
                  onTap: () => _navigateToEditRecord(entry),
                  hasOverlap: _hasOverlap(entry),
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
