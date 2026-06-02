import 'dart:async';

import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_overlap.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:clinical_diary/read/diary_view_builder.dart';
import 'package:clinical_diary/screens/calendar_screen.dart';
import 'package:clinical_diary/screens/clinical_trial_enrollment_screen.dart';
import 'package:clinical_diary/screens/day_disposition.dart';
import 'package:clinical_diary/screens/important_screen.dart';
import 'package:clinical_diary/screens/overlap_compare_screen.dart';
import 'package:clinical_diary/screens/profile_screen.dart';
import 'package:clinical_diary/screens/questionnaire_placeholder_screen.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/screens/settings_screen.dart';
import 'package:clinical_diary/services/clinical_diary_bootstrap.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/sponsor_branding_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/settings/app_preferences_scope.dart';
import 'package:clinical_diary/settings/clinical_rules_scope.dart';
import 'package:clinical_diary/settings/local_reset_policy.dart';
import 'package:clinical_diary/utils/app_page_route.dart';
import 'package:clinical_diary/widgets/disconnection_banner.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:clinical_diary/widgets/flash_highlight.dart';
import 'package:clinical_diary/widgets/logo_menu.dart';
import 'package:clinical_diary/widgets/task_list_widget.dart';
import 'package:clinical_diary/widgets/yesterday_banner.dart';
import 'package:diary_shared_model/diary_shared_model.dart'
    show EntryGate, entryGateForDate;
import 'package:eq/eq.dart';
import 'package:event_sourcing/event_sourcing.dart' show ActionSubmission;
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:trial_data_types/trial_data_types.dart';
import 'package:url_launcher/url_launcher.dart';

/// Main home screen showing recent events and recording button
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.runtime,
    required this.deviceId,
    required this.enrollmentService,
    required this.taskService,
    this.onEnrolled,
    this.onResetAllData,
    this.resetSettingAllowsReset = true,
    this.nativeFifoWedged,
    super.key,
  });

  /// Composed runtime — exposes [ClinicalDiaryRuntime.backend] for the wedge
  /// banner, [ClinicalDiaryRuntime.entryService] for writes, and
  /// [ClinicalDiaryRuntime.reader] for diary-shaped queries.
  final ClinicalDiaryRuntime runtime;

  /// Wedge check for the NEW event-sourcing store (`diary_es.db`), where the
  /// native `DiaryServerDestination`'s outbound FIFO lives. The legacy
  /// [runtime] backend's wedge check does not see that store, so this is OR-ed
  /// in by the wedge banner. Null in contexts without the new scope (the native
  /// check is then skipped). See DIARY-DEV-native-outbound-sync/B.
  final Future<bool> Function()? nativeFifoWedged;

  /// Persistent device install UUID. Stamped into the export payload so the
  /// downstream tooling can identify which device produced the JSON dump.
  final String deviceId;
  final EnrollmentService enrollmentService;
  // Task service for questionnaire task management
  final TaskService taskService;
  // Called after successful linking to register FCM token
  final VoidCallback? onEnrolled;

  /// Performs the real local factory reset (dispose → wipe → re-init), supplied
  /// by `AppRoot`. Null in contexts that don't wire a reset (the menu item is
  /// then inert). See DIARY-BASE-local-data-reset/A.
  final Future<void> Function()? onResetAllData;

  /// The sponsor-controllable layer of the reset gate, folded from the
  /// event-sourced settings projection (`allow_local_reset`, default true).
  /// The HARD participation safeguard is layered on top of this in-screen.
  final bool resetSettingAllowsReset;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isEnrolled = false;
  // Wedge banner state — refreshed on init and on resume.
  bool _hasWedgedFifo = false;
  // The yesterday+today block defaults to showing the newest events; jump it to
  // the bottom once after the first laid-out frame.
  bool _didScrollEventsToBottom = false;
  // Tracks whether the kept (non-diary) async checks have settled, so the
  // wedge / disconnection / task banners don't flash before their state loads.
  bool _isLoading = true;

  // Disconnection banner state.
  bool _isDisconnected = false;
  String? _siteName;
  String? _sitePhoneNumber;

  // Whether the local factory reset is currently permitted. Resolved from the
  // async enrollment state (the HARD participation safeguard) folded with the
  // sponsor-controllable allow_local_reset setting. Defaults false until the
  // async checks settle, so the destructive item is never momentarily enabled.
  bool _canResetData = false;

  // CUR-464: Track record to flash/highlight after save
  String? _flashRecordId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkEnrollmentStatus();
    _checkDisconnectionStatus();
    _checkNotParticipatingStatus();
    _refreshResetGate();
    _refreshWedgeStatus();
    // CUR-1164: React immediately when a background sync detects disconnection
    widget.enrollmentService.disconnectedNotifier.addListener(
      _onDisconnectionChanged,
    );
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
    final legacyWedged = await widget.runtime.backend.anyFifoWedged();
    // The native DiaryServerDestination's outbound FIFO lives in the new
    // event_sourcing store (diary_es.db), which runtime.backend does not see;
    // OR it in so a stuck native sync is visible to the participant.
    // See DIARY-DEV-native-outbound-sync/B.
    final nativeWedged =
        await (widget.nativeFifoWedged?.call() ?? Future<bool>.value(false));
    if (mounted) {
      setState(() {
        _hasWedgedFifo = legacyWedged || nativeWedged;
        // The wedge check is the last non-diary async to settle on init;
        // once it returns the kept banners can render their resolved state.
        _isLoading = false;
      });
    }
  }

  SponsorBrandingConfig sponsorBranding = SponsorBrandingConfig.fallback;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.enrollmentService.disconnectedNotifier.removeListener(
      _onDisconnectionChanged,
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
    // Enrollment changes flip the HARD participation safeguard; keep the
    // reset gate in sync whenever enrollment status is re-read.
    unawaited(_refreshResetGate());
  }

  /// REQ-CAL-p00077: Check if participant is disconnected from the study.
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
      // Clear cached tasks — disconnected participants have no valid questionnaires
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

  /// CUR-1165: Check if participant is marked as not participating (REQ-p01065-D).
  /// When true, sponsor-specific feature flags are reset to defaults so the
  /// app falls back to neutral behavior.
  Future<void> _checkNotParticipatingStatus() async {
    final isNotParticipating = await widget.enrollmentService
        .isNotParticipating();
    if (isNotParticipating) {
      FeatureFlagService.instance.resetToDefaults();
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The sponsor-controllable layer arrives via a widget rebuild when the
    // settings projection emits; re-fold the gate when it changes.
    if (oldWidget.resetSettingAllowsReset != widget.resetSettingAllowsReset) {
      _refreshResetGate();
    }
  }

  /// Re-fold the local-reset gate: the HARD participation safeguard
  /// (`isEnrolled && !isNotParticipating`) combined with the sponsor-
  /// controllable `allow_local_reset` setting. Reset is permitted only when not
  /// participating AND the setting allows it.
  // Implements: DIARY-BASE-local-data-reset/B+C
  Future<void> _refreshResetGate() async {
    final isEnrolled = await widget.enrollmentService.isEnrolled();
    final isNotParticipating = await widget.enrollmentService
        .isNotParticipating();
    final participating = isEnrolled && !isNotParticipating;
    final canReset = canResetLocalData(
      participating: participating,
      settingAllowsReset: widget.resetSettingAllowsReset,
    );
    if (mounted) {
      setState(() => _canResetData = canReset);
    }
  }

  Future<void> _navigateToRecording() async {
    // CUR-464: Result is now record ID (String) instead of bool. The diary list
    // refreshes reactively via DiaryViewBuilder; we only flash + scroll once the
    // new row has been spliced into the live view.
    final result = await Navigator.push<String?>(
      context,
      AppPageRoute(builder: (context) => const RecordingScreen()),
    );

    if (result != null && result.isNotEmpty && mounted) {
      _flashAndScrollTo(result);
    }
  }

  // CUR-489: Track GlobalKeys for each record to enable scroll-to-item
  final Map<String, GlobalKey> _recordKeys = {};

  /// Get or create a GlobalKey for a record
  GlobalKey _getKeyForRecord(String recordId) {
    return _recordKeys.putIfAbsent(recordId, GlobalKey.new);
  }

  /// Flag [recordId] for the flash highlight, then scroll it into view once the
  /// reactive list has rendered the new row.
  ///
  /// The diary list is driven by [DiaryViewBuilder], so the row may not be in
  /// the tree on the frame the recording screen pops. Setting [_flashRecordId]
  /// and deferring the scroll to a post-frame callback lets the next view
  /// emission splice the row in before we look up its [GlobalKey].
  void _flashAndScrollTo(String recordId) {
    setState(() => _flashRecordId = recordId);
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

  /// The `yyyy-MM-dd` local-date key for yesterday.
  static String _yesterdayKey() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return DateFormat('yyyy-MM-dd').format(yesterday);
  }

  /// Submit a whole-day marker (`record_no_epistaxis_day` /
  /// `record_unknown_day`) for [localDate] (`yyyy-MM-dd`) through the scope's
  /// action submitter. The diary list updates reactively, so there is no manual
  /// reload after the write.
  // Implements: DIARY-DEV-action-write-path/A
  Future<void> _submitDayMarker(String actionName, String localDate) async {
    await ReActionScope.of(context).actionSubmitter.submit(
      ActionSubmission(
        actionName: actionName,
        rawInput: <String, Object?>{'date': localDate},
      ),
    );
  }

  // Implements: DIARY-DEV-action-write-path/A
  Future<void> _handleYesterdayNoNosebleeds() async {
    await _submitDayMarker('record_no_epistaxis_day', _yesterdayKey());
  }

  Future<void> _handleYesterdayHadNosebleeds() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    // CUR-464: Result is now record ID (String) instead of bool. Flash + scroll
    // happen reactively once DiaryViewBuilder splices the new row in.
    final result = await Navigator.push<String?>(
      context,
      AppPageRoute(
        builder: (context) => RecordingScreen(initialDate: yesterday),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      _flashAndScrollTo(result);
    }
  }

  // Implements: DIARY-DEV-action-write-path/A
  Future<void> _handleYesterdayDontRemember() async {
    await _submitDayMarker('record_unknown_day', _yesterdayKey());
  }

  // Implements: DIARY-BASE-local-data-reset/D — the destructive reset requires
  //   explicit confirmation before the device is wiped.
  Future<void> _handleResetAllData() async {
    // Defense-in-depth: the menu item is already disabled when the gate is
    // closed, but never run the destructive wipe if the gate says no.
    if (!_canResetData) return;

    final reset = widget.onResetAllData;
    if (reset == null) return;

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
      // Full local factory reset: dispose runtimes → wipe device → re-init.
      // Driven by AppRoot; the app comes back up at first-launch state.
      await reset();
    }
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
      // _checkEnrollmentStatus re-folds the reset gate, re-opening it now that
      // the participant has ended participation.
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
              AppPageRoute<void>(builder: (context) => const SettingsScreen()),
            );
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

    final aggregateId = task.targetId ?? task.id;
    final entryType = '${qType.value}_survey';

    await Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (context) => QuestionnaireFlowScreen(
          definition: definition,
          instanceId: aggregateId,
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
          entry.entryType == 'qol_survey') {
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
                await _recordSurveySubmission(
                  entryType: entryType,
                  aggregateId: aggregateId,
                  submission: submission,
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

  // Implements: DIARY-DEV-reactive-read-path/A
  // Implements: DIARY-PRD-incomplete-entry-preservation/B
  Future<void> _handleIncompleteRecordsClick(DiaryView view) async {
    final incomplete = view.incompleteEntries;
    if (incomplete.isEmpty) return;

    // Navigate to edit (resume) the first incomplete entry. Only epistaxis
    // entries are editable in the recording screen.
    final firstIncomplete = incomplete.first;
    if (firstIncomplete is! EpistaxisEntryView) return;

    // The diary list refreshes reactively via DiaryViewBuilder; no manual
    // reload is needed after returning from the recording screen. The recording
    // screen pops its aggregate id (a String) on save, so the route result type
    // must be String?-compatible — a <bool> route throws on pop.
    await Navigator.push<String?>(
      context,
      AppPageRoute(
        builder: (context) => RecordingScreen(existing: firstIncomplete),
      ),
    );
  }

  /// Open the overlap-resolution flow for the first unresolved pair. The home
  /// surface re-derives reactively (DiaryViewBuilder), so after one pair is
  /// resolved the banner reflects the remaining count.
  // Implements: DIARY-GUI-entry-overlap-resolution/A
  Future<void> _handleResolveOverlaps(DiaryView view) async {
    final pairs = overlapPairs(view);
    if (pairs.isEmpty) return;
    final first = pairs.first;
    await Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (context) => OverlapCompareScreen(
          leftId: first.preExisting.aggregateId,
          rightId: first.justTouched.aggregateId,
        ),
      ),
    );
    // Nothing to do after the screen pops — the home surface re-derives the
    // banner reactively from the next DiaryView emission.
  }

  /// Re-disposition a tapped day-[marker]: open the same 3-choice picker the
  /// calendar uses, seeded with that marker so a "Record nosebleed" choice
  /// tombstones it on save (convert). Marker↔marker choices re-record on the
  /// day aggregate (latest-wins). A marker always carries a localDate.
  // Implements: DIARY-PRD-day-disposition/B
  Future<void> _redispositionMarker(DayMarkerView marker) async {
    final localDate = marker.localDate;
    if (localDate == null) return;
    final day = DateTime.parse(localDate);
    await showDayDispositionPicker(
      context,
      localDay: DateTime(day.year, day.month, day.day),
      localDate: localDate,
      marker: MarkerToReplace(
        aggregateId: marker.aggregateId,
        entryType: marker.entryType,
      ),
    );
  }

  Future<void> _navigateToEditRecord(EpistaxisEntryView entry) async {
    // CUR-464: Result is now record ID (String) instead of bool. Flash + scroll
    // happen reactively once DiaryViewBuilder splices the edited row back in.
    final result = await Navigator.push<String?>(
      context,
      AppPageRoute(builder: (context) => RecordingScreen(existing: entry)),
    );

    if (result != null && result.isNotEmpty && mounted) {
      _flashAndScrollTo(result);
    }
  }

  /// Whether [entry] overlaps any other epistaxis row in the live [view].
  /// CUR-443: Used to show a warning icon on overlapping events.
  // Implements: DIARY-DEV-reactive-read-path/A
  bool _hasOverlap(DiaryView view, EpistaxisEntryView entry) {
    final end = entry.endTime;
    if (end == null) return false;
    return overlappingEpistaxisEntries(
      view.finalizedRows,
      entry.startTime,
      end,
      excludeAggregateId: entry.aggregateId,
    ).isNotEmpty;
  }

  /// Group the live diary [view] into the "older incomplete", "yesterday", and
  /// "today" sections rendered by the list. Derives everything from [view] (the
  /// finalized canonical entries + the diary-local incomplete checkpoints).
  // Implements: DIARY-DEV-reactive-read-path/A
  List<_GroupedRecords> _groupRecordsByDay(
    BuildContext context,
    DiaryView view,
  ) {
    final l10n = AppLocalizations.of(context);
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

    int byStart(DiaryEntryView a, DiaryEntryView b) {
      final aStart = a is EpistaxisEntryView ? a.startTime : null;
      final bStart = b is EpistaxisEntryView ? b.startTime : null;
      if (aStart == null || bStart == null) return 0;
      return aStart.compareTo(bStart);
    }

    bool isEpistaxisOn(DiaryEntryView e, String dateStr) =>
        e is EpistaxisEntryView && e.localDate == dateStr;

    // The home block is yesterday + today only; everything older (including
    // older incomplete checkpoints, which the incomplete alert still surfaces)
    // is reached through the Calendar.
    final groups = <_GroupedRecords>[];

    // Yesterday's finalized nosebleed entries.
    final yesterdayEntries =
        view
            .entriesOn(yesterdayStr)
            .whereType<EpistaxisEntryView>()
            .cast<DiaryEntryView>()
            .toList()
          ..sort(byStart);

    // Any entry at all on yesterday (incl. day markers + incomplete checkpoints).
    final hasAnyYesterdayEntries =
        view.entriesOn(yesterdayStr).isNotEmpty ||
        view.incompleteEntries.any((e) => isEpistaxisOn(e, yesterdayStr));

    groups.add(
      _GroupedRecords(
        label: l10n.yesterday,
        date: yesterday,
        entries: yesterdayEntries,
        isEmpty: !hasAnyYesterdayEntries,
        isYesterday: true,
      ),
    );

    // Today's finalized nosebleed entries plus today's incomplete checkpoints
    // (CUR-488: in-progress entries surface in the today section).
    final todayEntries = <DiaryEntryView>[
      ...view.entriesOn(todayStr).whereType<EpistaxisEntryView>(),
      ...view.incompleteEntries.where((e) => isEpistaxisOn(e, todayStr)),
    ]..sort(byStart);

    final hasAnyTodayEntries =
        view.entriesOn(todayStr).isNotEmpty ||
        view.incompleteEntries.any((e) => isEpistaxisOn(e, todayStr));

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
    return DiaryViewBuilder(builder: _buildScaffold);
  }

  // Implements: DIARY-DEV-reactive-read-path/A
  Widget _buildScaffold(BuildContext context, DiaryView view) {
    // Top-to-bottom areas: header · alerts · notifications · yesterday+today ·
    // record. Each is a clearly-delimited region below.
    final incompleteCount = view.incompleteEntries.length;
    final overlapCount = overlapPairs(view).length;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // -- 1. HEADER --------------------------------------------------
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
                    sponsorLogo: sponsorBranding.appLogoUrl,
                    onResetAllData: _handleResetAllData,
                    resetEnabled: _canResetData,
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
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
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

            // -- 2 & 3. ALERTS + NOTIFICATIONS ------------------------------
            // The single most-urgent "important item" shows inline (top slot);
            // everything else collapses into one "N more important items" row
            // that opens the Important page. This keeps the home screen
            // uncluttered and bounded no matter how many alerts/tasks fire at
            // once. Priority: disconnection > sync-wedged > incomplete >
            // overlap > tasks.
            // Implements: DIARY-GUI-main-screen-layout-A+C
            // NOTE: the inline-top + collapse model is not yet in the
            // requirement's assertions (which still describe separate notice +
            // task zones); divergence to be reconciled in a later spec pass.
            if (!_isLoading)
              ListenableBuilder(
                listenable: widget.taskService,
                builder: (context, _) {
                  final alerts = _buildAlerts(
                    context,
                    view,
                    incompleteCount,
                    overlapCount,
                  );
                  // Tasks are hidden while disconnected (no valid
                  // questionnaires — CUR-1164).
                  final tasks = _isDisconnected
                      ? const <Task>[]
                      : widget.taskService.tasks;
                  final totalImportant = alerts.length + tasks.length;
                  // Top slot: the most-urgent alert, else the top task.
                  final topInline = alerts.isNotEmpty
                      ? alerts.first.banner
                      : (tasks.isNotEmpty
                            ? TaskListWidget(
                                taskService: widget.taskService,
                                onTaskTap: _navigateToQuestionnaire,
                                limit: 1,
                              )
                            : null);
                  final moreCount = topInline == null ? 0 : totalImportant - 1;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ?topInline,
                      if (moreCount > 0)
                        _buildMoreImportantRow(context, moreCount, alerts),
                    ],
                  );
                },
              ),

            // -- 4 & 5. YESTERDAY + TODAY ----------------------------------
            // One bounded block of real-estate. It scrolls internally when
            // yesterday + today overflow, pinned to the bottom (newest) by
            // default. Everything older is reached through the Calendar.
            Expanded(child: _buildEventsBlock(context, view)),

            // -- 6. RECORD -------------------------------------------------
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
                      // FittedBox (as the header title) scales the label down to
                      // fit rather than overflowing with a wide/large font.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
                  ),

                  const SizedBox(height: 16),

                  // Calendar button
                  OutlinedButton.icon(
                    onPressed: () async {
                      // The calendar reads/writes the same reactive diary store;
                      // the home list updates on its own when the dialog closes.
                      await showDialog<void>(
                        context: context,
                        builder: (context) => const CalendarScreen(),
                      );
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

  /// Builds the active alerts in priority order (most urgent first):
  /// disconnection > sync-wedged > incomplete > overlap. Each alert carries
  /// both its bespoke inline banner (shown when it wins the top slot) and the
  /// simple icon/title/onTap projection used by the Important page and the
  /// "N more important items" summary row.
  // Implements: DIARY-GUI-main-screen-layout-A
  List<_HomeAlert> _buildAlerts(
    BuildContext context,
    DiaryView view,
    int incompleteCount,
    int overlapCount,
  ) {
    final l10n = AppLocalizations.of(context);
    return [
      // Disconnection (red, persistent, non-dismissible per REQ-p05004).
      if (_isDisconnected)
        _HomeAlert(
          icon: Icons.warning_amber_rounded,
          color: Colors.red.shade700,
          // TODO(i18n): localize.
          title: 'Disconnected from Study',
          subtitle: 'Please contact your study site.',
          banner: DisconnectionBanner(
            siteName: _siteName,
            sitePhoneNumber: _sitePhoneNumber,
          ),
        ),
      // Sync wedged: a destination FIFO is wedged on an unknown event-type
      // bridge mismatch — participant should update the app to drain it.
      if (_hasWedgedFifo)
        _HomeAlert(
          icon: Icons.sync_problem,
          color: Colors.red.shade400,
          // TODO(i18n): localize.
          title: 'Some data is not syncing',
          subtitle: 'Please update the app.',
          banner: const _SyncWedgedBanner(),
        ),
      // Incomplete-entry reminder (preserves in-progress entries).
      // Implements: DIARY-PRD-incomplete-entry-preservation/B
      if (incompleteCount > 0)
        _HomeAlert(
          icon: Icons.warning_amber_rounded,
          color: Colors.orange.shade800,
          title: l10n.incompleteRecordCount(incompleteCount),
          onTap: () => _handleIncompleteRecordsClick(view),
          banner: _incompleteBanner(context, view, incompleteCount),
        ),
      // Unresolved overlaps (amber — distinct, lower-urgency than incomplete).
      // Implements: DIARY-PRD-entry-overlap-resolution/B
      if (overlapCount > 0)
        _HomeAlert(
          icon: Icons.merge_type,
          color: Colors.amber.shade900,
          // TODO(i18n): localize + pluralize.
          title: overlapCount == 1
              ? '1 overlapping record needs resolving'
              : '$overlapCount overlapping records need resolving',
          onTap: () => _handleResolveOverlaps(view),
          banner: _overlapBanner(context, view, overlapCount),
        ),
    ];
  }

  /// Orange incomplete-records banner (the bespoke inline form).
  Widget _incompleteBanner(
    BuildContext context,
    DiaryView view,
    int incompleteCount,
  ) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () => _handleIncompleteRecordsClick(view),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                l10n.incompleteRecordCount(incompleteCount),
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Tappable affordance (whole banner is an InkWell). A chevron —
            // rather than a second competing text label — keeps the count
            // readable on narrow screens and at large text scales.
            const SizedBox(width: 8),
            Tooltip(
              message: l10n.tapToComplete,
              child: Icon(Icons.chevron_right, color: Colors.orange.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /// Amber unresolved-overlap banner (the bespoke inline form).
  Widget _overlapBanner(
    BuildContext context,
    DiaryView view,
    int overlapCount,
  ) {
    return InkWell(
      onTap: () => _handleResolveOverlaps(view),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.merge_type, color: Colors.amber.shade900, size: 20),
            const SizedBox(width: 12),
            Expanded(
              // TODO(i18n): localize + pluralize.
              child: Text(
                overlapCount == 1
                    ? '1 overlapping record needs resolving'
                    : '$overlapCount overlapping records need resolving',
                style: TextStyle(
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // TODO(i18n): localize tooltip.
            Tooltip(
              message: 'Resolve',
              child: Icon(Icons.chevron_right, color: Colors.amber.shade700),
            ),
          ],
        ),
      ),
    );
  }

  /// The collapsed "N more important items" row that opens the Important page.
  Widget _buildMoreImportantRow(
    BuildContext context,
    int moreCount,
    List<_HomeAlert> alerts,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openImportant(context, alerts),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_none,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  // TODO(i18n): localize + pluralize.
                  child: Text(
                    moreCount == 1
                        ? '1 more important item'
                        : '$moreCount more important items',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the Important page: the full alert list (page-row projection) plus
  /// the full task list, in two sections.
  Future<void> _openImportant(
    BuildContext context,
    List<_HomeAlert> alerts,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImportantScreen(
          alerts: [
            for (final a in alerts)
              ImportantAlert(
                icon: a.icon,
                color: a.color,
                title: a.title,
                subtitle: a.subtitle,
                onTap: a.onTap,
              ),
          ],
          taskService: widget.taskService,
          onTaskTap: _navigateToQuestionnaire,
        ),
      ),
    );
  }

  /// The Yesterday + Today block (areas 4 & 5): a bounded, internally-scrolling
  /// list of the yesterday and today day-groups, auto-pinned to the bottom
  /// (newest) on first load. Wrapped in [Expanded] by the caller.
  // Implements: DIARY-DEV-reactive-read-path/A
  Widget _buildEventsBlock(BuildContext context, DiaryView view) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final groups = _groupRecordsByDay(context, view);
    // Default to the most recent events: jump to the bottom once, after the
    // first laid-out frame that has a scrollable extent.
    if (!_didScrollEventsToBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didScrollEventsToBottom) return;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          _didScrollEventsToBottom = true;
        }
      });
    }
    return RefreshIndicator(
      // The diary list itself is reactive (DiaryViewBuilder) and needs no
      // reload. CUR-1398: pull-to-refresh re-pulls /tasks so the patient has a
      // manual recovery path when FCM is slow or fails (questionnaires shown as
      // "Sent" in the portal but not yet surfaced on the home screen).
      onRefresh: () => widget.taskService.syncTasks(widget.enrollmentService),
      child: Scrollbar(
        thumbVisibility: true,
        controller: _scrollController,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: groups.length,
          itemBuilder: (context, index) =>
              _buildGroup(context, view, groups[index]),
        ),
      ),
    );
  }

  /// Empty-state content for a day group. The Yesterday section, when not
  /// locked, shows the No/Had/Don't-remember confirmation prompt instead of a
  /// bare empty state (the prompt lives in the Yesterday area, not a separate
  /// banner). Implements: DIARY-PRD-day-disposition/B
  Widget _emptyGroupContent(BuildContext context, _GroupedRecords group) {
    // Only prompt when yesterday has NO entry at all (incl. a day marker or an
    // incomplete checkpoint) — i.e. the participant hasn't answered yet.
    if (group.isYesterday && group.isEmpty) {
      // Defense-in-depth for the day-level lock: the prompt's quick actions
      // write markers / open recording for yesterday directly, so suppress it
      // when yesterday is past the lock threshold (only possible under a sub-day
      // lock); the calendar is the primary read-only gate.
      final yesterdayLocked =
          entryGateForDate(
            eventLocalMidnight: DateUtils.dateOnly(
              DateTime.now().subtract(const Duration(days: 1)),
            ),
            now: DateTime.now(),
            config: ClinicalRulesScope.of(context).gate,
          ) ==
          EntryGate.locked;
      if (!yesterdayLocked) {
        return YesterdayBanner(
          onNoNosebleeds: _handleYesterdayNoNosebleeds,
          onHadNosebleeds: _handleYesterdayHadNosebleeds,
          onDontRemember: _handleYesterdayDontRemember,
        );
      }
    }
    return Padding(
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
    );
  }

  // Implements: DIARY-GUI-epistaxis-record/A
  Widget _buildGroup(
    BuildContext context,
    DiaryView view,
    _GroupedRecords group,
  ) {
    final prefs = AppPreferencesScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day divider + label (Yesterday / Today) and the full date.
        if (group.date != null)
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
        if (group.entries.isEmpty)
          _emptyGroupContent(context, group)
        else
          ...group.entries.map(
            (entry) => Padding(
              // CUR-489: Use GlobalKey for scroll-to-item functionality
              key: _getKeyForRecord(entry.aggregateId),
              padding: const EdgeInsets.only(bottom: 8),
              // CUR-464: Wrap with FlashHighlight to animate new records
              child: FlashHighlight(
                flash: entry.aggregateId == _flashRecordId,
                enabled: prefs.useAnimation,
                onFlashComplete: () {
                  if (mounted) {
                    setState(() {
                      _flashRecordId = null;
                    });
                  }
                },
                builder: (context, highlightColor) => EventListItem(
                  view: entry,
                  // Epistaxis taps edit the record; day-marker taps re-disposition
                  // the day via the shared 3-choice picker.
                  // Implements: DIARY-PRD-day-disposition/B
                  onTap: switch (entry) {
                    EpistaxisEntryView() => () => _navigateToEditRecord(entry),
                    DayMarkerView() => () => _redispositionMarker(entry),
                  },
                  hasOverlap:
                      entry is EpistaxisEntryView && _hasOverlap(view, entry),
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
    this.isEmpty = false,
    this.isYesterday = false,
  });
  final String label;
  final DateTime? date;
  final List<DiaryEntryView> entries;
  final bool isEmpty;

  /// The "Yesterday" section. When empty (and not locked) it renders the
  /// yesterday confirmation prompt instead of a bare empty state.
  final bool isYesterday;
}

/// Banner shown when at least one destination FIFO is wedged on a
/// `unknown_event_type` bridge.  Surfaces the situation so the participant
/// updates the app; underlying scope is "visible state", not UX polish.
/// One active home alert: its bespoke inline [banner] (shown when it wins the
/// single top slot) plus the simple icon/title/[onTap] projection used by the
/// Important page rows and the collapsed summary count.
class _HomeAlert {
  const _HomeAlert({
    required this.icon,
    required this.color,
    required this.title,
    required this.banner,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;

  /// Action when the row/banner is tapped. Null for informational alerts
  /// (e.g. the non-dismissible disconnection notice).
  final VoidCallback? onTap;

  /// The rich, bespoke inline banner for the home top slot.
  final Widget banner;
}

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
