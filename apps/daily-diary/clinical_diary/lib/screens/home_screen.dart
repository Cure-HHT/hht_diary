import 'dart:async';

import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/destinations/diary_server_destination.dart';
import 'package:clinical_diary/diagnostics/health_context.dart';
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/notifications/session_expiry_notification_service.dart';
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_overlap.dart';
import 'package:clinical_diary/read/diary_read.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:clinical_diary/read/diary_view_builder.dart';
import 'package:clinical_diary/read/questionnaire_recall_projection.dart';
import 'package:clinical_diary/read/questionnaire_status_projection.dart';
import 'package:clinical_diary/scope/diary_participant_id.dart';
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:clinical_diary/scope/sponsor_ui_config_scope.dart';
import 'package:clinical_diary/screens/calendar_screen.dart';
import 'package:clinical_diary/screens/clinical_trial_enrollment_screen.dart';
import 'package:clinical_diary/screens/incomplete_records_screen.dart';
import 'package:clinical_diary/screens/overlap_compare_screen.dart';
import 'package:clinical_diary/screens/profile_screen.dart';
import 'package:clinical_diary/screens/questionnaire_placeholder_screen.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/screens/service_mode_screen.dart';
import 'package:clinical_diary/screens/settings_screen.dart';
import 'package:clinical_diary/services/branding_asset_cache.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/recall_acknowledger.dart';
import 'package:clinical_diary/services/sponsor_branding_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/settings/app_preferences_scope.dart';
import 'package:clinical_diary/settings/clinical_rules_scope.dart';
import 'package:clinical_diary/settings/local_reset_policy.dart';
import 'package:clinical_diary/utils/app_page_route.dart';
import 'package:clinical_diary/widgets/brand_header.dart';
import 'package:clinical_diary/widgets/branding_logo.dart';
import 'package:clinical_diary/widgets/disconnection_banner.dart';
import 'package:clinical_diary/widgets/event_list_item.dart';
import 'package:clinical_diary/widgets/flash_highlight.dart';
import 'package:clinical_diary/widgets/logo_menu.dart';
import 'package:clinical_diary/widgets/user_menu_button.dart';
import 'package:clinical_diary/widgets/yesterday_banner.dart';
import 'package:diary_design_system/diary_design_system.dart'
    hide EventListItem;
import 'package:diary_shared_model/diary_shared_model.dart'
    show EntryGate, diaryEntriesViewName, entryGateForDate;
import 'package:eq/eq.dart';
import 'package:event_sourcing/event_sourcing.dart'
    show ActionSubmission, Delta, EndOfReplay, Snapshot, Tombstone, Update;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:trial_data_types/trial_data_types.dart';
import 'package:url_launcher/url_launcher.dart';

/// Main home screen showing recent events and recording button
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.diaryScope,
    required this.deviceId,
    required this.enrollmentService,
    required this.taskService,
    this.onEnrolled,
    this.onResetAllData,
    this.resetSettingAllowsReset = true,
    this.nativeFifoWedged,
    this.sponsorBranding = SponsorBrandingConfig.fallback,
    this.brandingAssetCache,
    this.serviceModeContextBuilder,
    this.sessionExpiryNotifications,
    super.key,
  });

  /// The native `event_sourcing` diary scope (`diary_es.db`) — the reactive
  /// composition root. Exposes [DiaryScopeRuntime.syncCycle] for the reconnect
  /// drain and [DiaryScopeRuntime.bundle] for the destination registry
  /// (install-date back-nav) and event-store backend.
  final DiaryScopeRuntime diaryScope;

  /// Wedge check for the native event-sourcing store (`diary_es.db`), where the
  /// `DiaryServerDestination`'s outbound FIFO lives. Surfaced in the wedge
  /// banner. Null in contexts without the scope (the check is then skipped).
  /// See DIARY-DEV-native-outbound-sync/B.
  final Future<bool> Function()? nativeFifoWedged;

  /// Builds the on-demand Service Mode [HealthProbeContext]. When non-null the
  /// logo menu's tap-version-7x easter egg opens the diagnostic screen; null
  /// leaves it inert (e.g. before the event-sourcing scope has booted).
  final Future<HealthProbeContext> Function()? serviceModeContextBuilder;

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

  /// Sponsor branding derived from the diary's event-sourced settings
  /// projection (the `branding.*` keys delivered set-once-at-link). Supplied by
  /// the app root's reactive ViewBuilder, so it updates when the settings change.
  // Implements: DIARY-GUI-participation-status-badge/B
  final SponsorBrandingConfig sponsorBranding;

  /// Content-addressed cache the *Sponsor* logo bytes are served from / fetched
  /// into (JWT-gated fetch-once, verified by hash, retained after participation
  /// ends). Supplied by the app root from a stable on-device cache directory;
  /// when null the logo render sites fall back to the app default brand.
  // Implements: DIARY-DEV-sponsor-branding-assets/D
  final BrandingAssetCache? brandingAssetCache;

  /// CUR-1543: schedules / cancels the questionnaire session Timeout Warning
  /// and Session Expiry local notifications. Anchored on every checkpoint
  /// write and on resuming an unexpired draft; cancelled on submission and on
  /// expired-draft discard. Null (no-op) in contexts without notification
  /// wiring — web/local-stack use a no-op scheduler at the app root anyway.
  // Implements: DIARY-GUI-questionnaire-session-expiry/A+F
  final SessionExpiryNotificationService? sessionExpiryNotifications;

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

  // CUR-1523: instance ids the device has observed as portal-FINALIZED (the
  // `questionnaire_status` read-only set). A finalized questionnaire re-opens
  // read-only (workflow/S); until finalized a submitted questionnaire re-opens
  // to the editable Review Screen (workflow/R). Maintained by a LIVE subscription
  // to the native `questionnaire_status` view, so it reflects a just-minted
  // `questionnaire_finalized` the instant the post-sync reconcile records it —
  // a one-shot read would miss its own mint (the reconcile mints AFTER the sync
  // that triggers the read). It is the durable on-device source of truth, so the
  // read-only gate is correct offline (no dependency on a fresh /user/tasks sync).
  Set<String> _finalizedInstanceIds = const <String>{};
  StreamSubscription<Update<QuestionnaireStatusRow>>? _finalizedStatusSub;

  // CUR-1522: Live subscription to the device-local questionnaire_recall view.
  // A row appears when the poll reconcile records a portal recall notice; the
  // home screen shows an acknowledgement dialog and tombstones the row via
  // acknowledgeRecall. Instances already handled in this mount are tracked in
  // [_handledRecalls] so the dialog fires at most once per instance per mount.
  StreamSubscription<Update<QuestionnaireRecallRow>>? _recallSub;
  final Set<String> _handledRecalls = <String>{};

  // Recall rows that arrived during the initial replay phase (before
  // EndOfReplay). Surfaced sequentially on EndOfReplay so no dialog is missed
  // even when the row pre-existed at app launch.
  final List<QuestionnaireRecallRow> _pendingReplayRecalls =
      <QuestionnaireRecallRow>[];

  /// CUR-1522: when a questionnaire is open in the flow screen, set this to
  /// the open instance's id so the home screen's general recall subscription
  /// skips the recall dialog for that instance (the flow screen owns it via
  /// its recallSignal / onRecalled callback instead). Cleared when the
  /// flow route returns.
  String? _instanceOpenInFlow;

  /// CUR-1522: StreamController that drives the recallSignal passed to the
  /// currently-open QuestionnaireFlowScreen. Created when a flow is pushed;
  /// closed and nulled when the flow route returns. The home's recall
  /// subscription emits `true` on this controller when a recall row for the
  /// open instance arrives.
  StreamController<bool>? _recallSignalCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkEnrollmentStatus();
    _checkDisconnectionStatus();
    _refreshResetGate();
    _refreshWedgeStatus();
    _startFinalizedStatusSubscription();
    _startRecallSubscription();
    // CUR-1164: React immediately when a background sync detects disconnection
    widget.enrollmentService.disconnectedNotifier.addListener(
      _onDisconnectionChanged,
    );
    // React live when a reconcile detects the portal marked the participant
    // not-participating: it clears enrollment, so re-read enrollment to revert
    // the sponsor branding (gated on active enrollment) without a relaunch.
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
    // The DiaryServerDestination's outbound FIFO lives in the native
    // event_sourcing store (diary_es.db); surface a stuck native sync so it is
    // visible to the participant. See DIARY-DEV-native-outbound-sync/B.
    final nativeWedged =
        await (widget.nativeFifoWedged?.call() ?? Future<bool>.value(false));
    if (mounted) {
      setState(() {
        _hasWedgedFifo = nativeWedged;
        // The wedge check is the last non-diary async to settle on init;
        // once it returns the kept banners can render their resolved state.
        _isLoading = false;
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
    unawaited(_finalizedStatusSub?.cancel());
    unawaited(_recallSub?.cancel());
    unawaited(_recallSignalCtrl?.close());
    _scrollController.dispose();
    super.dispose();
  }

  /// Starts a LIVE subscription to the native `questionnaire_status` projection
  /// and keeps [_finalizedInstanceIds] in lock-step with it. Unlike a one-shot
  /// read, this reflects a `questionnaire_finalized` the instant it is recorded —
  /// crucially including the mint the post-sync reconcile appends AFTER the sync
  /// that would otherwise have driven (and already completed) a one-shot read.
  ///
  /// Each emission carries one row. Finalize is terminal for Callisto, but the
  /// unlock case is handled too (a row that is no longer finalized is dropped).
  /// The initial replay accumulates silently and publishes once at the
  /// [EndOfReplay] marker; subsequent live updates publish immediately.
  // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/S
  void _startFinalizedStatusSubscription() {
    final finalized = <String>{};
    var replaying = true;
    void publish() {
      if (mounted) setState(() => _finalizedInstanceIds = Set.of(finalized));
    }

    _finalizedStatusSub = widget.diaryScope.scope.viewSource
        .watch<QuestionnaireStatusRow>(
          viewName: questionnaireStatusViewName,
          mapper: QuestionnaireStatusRow.fromViewRow,
        )
        .listen(
          (update) {
            // Update<T> is sealed: Snapshot (replay rows), Delta/Tombstone (live
            // changes after EndOfReplay), EndOfReplay (replay-done marker). A
            // just-minted questionnaire_finalized arrives as a Delta — handling
            // ONLY Snapshot would silently drop every live finalize.
            switch (update) {
              case Snapshot<QuestionnaireStatusRow>(:final value):
                if (value == null) break;
                _applyFinalizedRow(finalized, value);
                if (!replaying) publish();
              case Delta<QuestionnaireStatusRow>(:final value):
                _applyFinalizedRow(finalized, value);
                publish();
              case Tombstone<QuestionnaireStatusRow>(:final aggregateId):
                finalized.remove(aggregateId);
                publish();
              case EndOfReplay<QuestionnaireStatusRow>():
                replaying = false;
                publish();
            }
          },
          onError: (Object e, StackTrace st) {
            // A read error leaves the last-known finalized set in place.
          },
        );
  }

  /// Folds one `questionnaire_status` row into [finalized]: a finalized instance
  /// is in the read-only set; an unfinalized one (future unlock) is dropped.
  void _applyFinalizedRow(Set<String> finalized, QuestionnaireStatusRow row) {
    if (row.isFinalized) {
      finalized.add(row.instanceId);
    } else {
      finalized.remove(row.instanceId);
    }
  }

  /// Starts a LIVE subscription to the native `questionnaire_recall` projection.
  /// Each row represents an instance that the portal has recalled and the device
  /// has not yet acknowledged. On each live row the home screen shows a one-button
  /// "Questionnaire recalled" acknowledgement dialog, then tombstones the row via
  /// [acknowledgeRecall] so it self-clears from the view.
  ///
  /// Rows that arrive during the initial replay phase (Snapshots before
  /// [EndOfReplay]) are COLLECTED into [_pendingReplayRecalls] and surfaced
  /// sequentially on [EndOfReplay]. This guarantees that an unacknowledged recall
  /// row already present at app launch — which arrives only as a replay Snapshot
  /// and never as a subsequent Delta — still prompts the participant. Live Deltas
  /// (recalls that arrive after replay) surface immediately. Rows for instances
  /// already handled in this mount ([_handledRecalls]) and for the instance
  /// currently open in the flow screen ([_instanceOpenInFlow]) are skipped.
  // Implements: DIARY-DEV-inbound-event-on-receipt/C
  void _startRecallSubscription() {
    _recallSub = widget.diaryScope.scope.viewSource
        .watch<QuestionnaireRecallRow>(
          viewName: questionnaireRecallViewName,
          mapper: QuestionnaireRecallRow.fromViewRow,
        )
        .listen((update) {
          switch (update) {
            case Snapshot<QuestionnaireRecallRow>(:final value):
              // Collect replay-phase rows; they will be surfaced on EndOfReplay.
              if (value != null) _pendingReplayRecalls.add(value);
            case Delta<QuestionnaireRecallRow>(:final value):
              _maybeShowRecall(value);
            case EndOfReplay<QuestionnaireRecallRow>():
              // Drain replay-phase rows sequentially so dialogs don't stack.
              final pending = List<QuestionnaireRecallRow>.of(
                _pendingReplayRecalls,
              );
              _pendingReplayRecalls.clear();
              Future<void>(() async {
                for (final row in pending) {
                  await _maybeShowRecall(row);
                }
              });
            case Tombstone<QuestionnaireRecallRow>():
              break;
          }
        });
  }

  /// Shows the recall acknowledgement dialog for [row] unless the instance has
  /// already been handled in this mount or is currently open in the flow screen
  /// (in which case the flow's onRecalled callback handles it instead).
  ///
  /// After the participant dismisses the dialog, tombstones the recall row via
  /// [acknowledgeRecall] so the `questionnaire_recall` view self-clears and the
  /// subscription no longer delivers it.
  ///
  /// When a recall arrives for the instance that is currently open in the flow
  /// (_instanceOpenInFlow matches), it is forwarded via _recallSignalCtrl
  /// so the flow screen can react mid-cycle via its recallSignal param.
  ///
  /// If the participant never received or engaged with this questionnaire on
  /// this device (no device-local survey row exists), the dialog is suppressed
  /// and the recall is silently acknowledged. Showing a "recalled" message for
  /// a questionnaire the participant never saw is confusing; the portal recall
  /// row still self-cleans via the silent ack.
  // Implements: DIARY-DEV-inbound-event-on-receipt/C
  Future<void> _maybeShowRecall(QuestionnaireRecallRow row) async {
    if (!mounted) return;
    if (_handledRecalls.contains(row.instanceId)) return;
    if (row.instanceId == _instanceOpenInFlow) {
      // The flow screen owns this instance's recall dialog via its callback.
      // Forward the signal so the flow can interrupt itself mid-cycle.
      _recallSignalCtrl?.add(true);
      return;
    }
    _handledRecalls.add(row.instanceId);
    // Branch on whether the participant ever engaged with this questionnaire
    // on this device. A device-local survey row exists iff the participant
    // opened and submitted the questionnaire; if no row exists the
    // questionnaire was recalled before it was ever delivered / opened here.
    // Query the native event store directly (not the reactive DiaryView) so
    // the check is authoritative regardless of when in the build cycle this
    // recall fires (e.g. replay-phase drain before DiaryViewBuilder delivers
    // its first emission).
    final localSurveyExists = await _hasLocalSurveyRow(row.instanceId);
    if (localSurveyExists) {
      // Participant engaged: show the dialog so they are informed.
      await _showRecallDialogAndAck(row.instanceId);
    } else {
      // Never delivered / never engaged: silently ack — no participant dialog.
      await acknowledgeRecall(widget.diaryScope, row.instanceId);
    }
  }

  /// Returns true iff the native `diary_entries` view holds a local survey row
  /// for [instanceId] — meaning the participant submitted the questionnaire on
  /// this device before the recall arrived. Survey rows have aggregateId ==
  /// instanceId and an entryType of the form `<type>_survey`.
  ///
  /// Queries the StorageBackend directly (not the reactive DiaryView) so the
  /// check is authoritative before DiaryViewBuilder delivers its first emission.
  // Implements: DIARY-DEV-inbound-event-on-receipt/C
  Future<bool> _hasLocalSurveyRow(String instanceId) async {
    final rows = await widget.diaryScope.bundle.eventStore.backend.findViewRows(
      diaryEntriesViewName,
    );
    return rows.any(
      (row) =>
          row['aggregateId'] == instanceId &&
          ((row['entryType'] as String?) ?? '').endsWith('_survey'),
    );
  }

  /// Core recall dialog + ack: shows the one-button acknowledgement dialog and
  /// then tombstones the recall row. Factored out so both the general
  /// subscription path (_maybeShowRecall) and the flow's onRecalled
  /// callback (_openQuestionnaireFlow) can share it.
  // Implements: DIARY-DEV-inbound-event-on-receipt/C
  Future<void> _showRecallDialogAndAck(String instanceId) async {
    if (!mounted) return;
    await AppDialog.acknowledgment(
      context: context,
      title: 'Questionnaire recalled',
      message: 'This questionnaire has been recalled by your study team',
    );
    await acknowledgeRecall(widget.diaryScope, instanceId);
  }

  Future<void> _checkEnrollmentStatus() async {
    final isEnrolled = await widget.enrollmentService.isEnrolled();
    // Branding is derived from the diary's own event-sourced settings
    // projection (set-once-at-link) by the app root and passed in via
    // widget.sponsorBranding.
    if (mounted) {
      setState(() {
        _isEnrolled = isEnrolled;
      });
    }
    // Enrollment changes flip the HARD participation safeguard; keep the
    // reset gate in sync whenever enrollment status is re-read.
    unawaited(_refreshResetGate());
  }

  /// Check if participant is disconnected from the study.
  /// Seeds [_isDisconnected] from SharedPreferences and syncs the notifier
  /// so the initial persisted state is reflected in the banner on startup.
  // Implements: DIARY-PRD-notification-disconnection
  // Implements: DIARY-PRD-participant-reactivate
  Future<void> _checkDisconnectionStatus() async {
    final isDisconnected = await widget.enrollmentService.isDisconnected();
    // Seed the notifier from the persisted value so it stays in sync
    widget.enrollmentService.disconnectedNotifier.value = isDisconnected;
    // Get site contact info for disconnection banner
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
  /// A portal-driven not-participating transition (detected by a scope
  /// reconcile) clears enrollment. Re-read enrollment so the sponsor branding,
  /// which is gated on active enrollment, reverts to the app default live.
  void _onNotParticipatingChanged() {
    if (!mounted) return;
    // Rebuild now so the branding gate re-reads the notifier this frame (the
    // gate reads the notifier directly, so it reverts without a page change);
    // also refresh _isEnrolled for the rest of the screen.
    setState(() {});
    unawaited(_checkEnrollmentStatus());
  }

  void _onDisconnectionChanged() {
    if (!mounted) return;
    final isDisconnected = widget.enrollmentService.disconnectedNotifier.value;
    setState(() => _isDisconnected = isDisconnected);
    // Disconnect does NOT clear enrollment — it only means "can't sync". Branding
    // therefore stays put (it reverts only on not-participating). Re-read keeps
    // _isEnrolled and the reset gate fresh; it intentionally does NOT drive any
    // branding revert.
    unawaited(_checkEnrollmentStatus());
    if (isDisconnected) {
      // Clear cached tasks — disconnected participants have no valid questionnaires
      unawaited(widget.taskService.clearAll());
      // Refresh site name/phone for the banner contact details
      unawaited(_refreshSiteInfo());
    } else {
      // CUR-1164: On reconnect, kick the native FIFO drain immediately so any
      // events recorded while the gate was closed ship without waiting up to 15
      // minutes for the next periodic tick.
      final syncCycle = widget.diaryScope.syncCycle;
      if (syncCycle != null) unawaited(syncCycle.call());
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
        rawInput: <String, Object?>{
          'date': localDate,
          'participantId': diaryParticipantId(context),
        },
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

  /// Opens the diagnostic ("Service Mode") screen. Wired to the logo menu's
  /// tap-version-7x easter egg; only reachable when
  /// [HomeScreen.serviceModeContextBuilder] is non-null.
  // Implements: DIARY-GUI-service-mode-entry/A — navigation target for the
  //   seven-tap reveal.
  void _openServiceMode() {
    final builder = widget.serviceModeContextBuilder;
    if (builder == null) return;
    Navigator.push<void>(
      context,
      AppPageRoute(builder: (_) => ServiceModeScreen(contextBuilder: builder)),
    );
  }

  /// Navigate to profile screen with participation status badge.
  // Implements: DIARY-GUI-participation-status-badge
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
                  // From the profile-launched flow the user came from
                  // profile, so popping enrollment + reopening profile
                  // returns them where they started.
                  onShowProfile: () {
                    Navigator.of(context).pop();
                    _handleShowProfile();
                  },
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
          isEnrolledInTrial: _isEnrolled,
          isDisconnected: isDisconnected,
          isNotParticipating: isNotParticipating,
          enrollmentStatus: _isEnrolled ? 'active' : 'none',
          sponsorLogoBuilder: _brandingLogoBuilder,
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
  }

  // Navigate to questionnaire.
  //
  // The QuestionnaireDefinition is loaded from the bundled
  // packages/trial_data_types/assets/data/questionnaires.json asset (the same
  // source loadClinicalDiaryEntryTypes uses to build EntryTypeDefinitions).
  // Submission writes a finalized survey event via EntryService.record.
  //
  // CUR-1523: the destination depends on the questionnaire's lifecycle state.
  // [view] supplies the device-local finalized `<id>_survey` rows (the SUBMITTED
  // set + the prior answers for prefill); [_finalizedInstanceIds] is the
  // portal-finalized read-only set. A finalized instance opens read-only
  // (workflow/S); a submitted-but-not-finalized instance opens the editable
  // Review Screen seeded with prior answers (workflow/R + task-list/K); a
  // never-submitted instance opens the fresh flow.
  // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/R+S
  // Implements: DIARY-GUI-participant-task-list/K
  // Implements: DIARY-PRD-questionnaire-nose-hht
  // Implements: DIARY-PRD-questionnaire-hht-qol
  Future<void> _navigateToQuestionnaire(Task task, DiaryView view) async {
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

    final aggregateId = task.targetId ?? task.id;

    // The device-local finalized `<id>_survey` row for this instance, if the
    // participant has already submitted it; carries the prior answers used to
    // seed the Review Screen / read-only view.
    final surveyView = _submittedSurveyFor(view, aggregateId);

    await _openQuestionnaireFlow(
      qType: qType,
      aggregateId: aggregateId,
      // Read-only iff the device has observed + recorded the portal's
      // finalization in the durable `questionnaire_status` projection
      // ([_finalizedInstanceIds], kept live). The projection is the on-device
      // source of truth, so the gate is correct offline — no dependency on a
      // fresh /user/tasks sync.
      isReadOnly: _finalizedInstanceIds.contains(aggregateId),
      submittedSurvey: surveyView,
    );
  }

  /// Pushes the [QuestionnaireFlowScreen] for an instance. The single
  /// flow-construction path shared by opening from a Task
  /// ([_navigateToQuestionnaire]) and from a record ([_openSurveyRecord]): the
  /// two callers differ only in how they derive [aggregateId], [qType],
  /// [isReadOnly], and the prior-answers [submittedSurvey] from their input.
  ///
  /// [isReadOnly] true → view-only finalized questionnaire (workflow/S);
  /// false → editable Review Screen seeded from [submittedSurvey] (workflow/R),
  /// or the fresh flow when [submittedSurvey] is null (never submitted).
  // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/R+S
  Future<void> _openQuestionnaireFlow({
    required QuestionnaireType qType,
    required String aggregateId,
    required bool isReadOnly,
    required SurveyEntryView? submittedSurvey,
  }) async {
    final definition = await _loadQuestionnaireDefinition(qType);
    if (definition == null || !mounted) return;

    // CUR-1543: a resumable `checkpoint` draft is only honoured while its
    // Session has not expired. An expired draft (now - last checkpoint >=
    // sessionTimeoutMinutes) is discarded in the event log FIRST (the answers
    // are gone whatever the participant chooses next), then the Session Expiry
    // Dialog offers Start Again (fresh flow from the Preamble) or Not Now
    // (stay on the home screen). Finalized submissions (`seed.isComplete`)
    // never expire — post-submission editing has no time limit (rules/N).
    // Implements: DIARY-GUI-questionnaire-session-expiry/B+D+E
    // Implements: DIARY-PRD-questionnaire-session-timeout/C+D
    var seed = submittedSurvey;
    if (!isReadOnly &&
        seed != null &&
        !seed.isComplete &&
        _isSessionExpired(definition, seed.completedAt)) {
      await _discardExpiredDraft(
        instanceId: aggregateId,
        questionnaireType: definition.id,
      );
      // The session is over — its pending warning/expiry notifications (if
      // any survived; the expiry one has typically already fired) are stale.
      // Implements: DIARY-GUI-questionnaire-session-expiry/A+F
      unawaited(widget.sessionExpiryNotifications?.cancelSession(aggregateId));
      final startAgain = await _showSessionExpiryDialog();
      if (!startAgain) return; // Not Now → home screen (expiry/E)
      seed = null; // Start Again → fresh flow from the Preamble (expiry/D)
    }
    if (!mounted) return;

    // The (unexpired) `checkpoint` draft seeding this open, or null when the
    // seed is a finalized submission / absent.
    final draftSeed = seed != null && !seed.isComplete ? seed : null;

    // Whether a diary-local `checkpoint` draft exists for this instance (a
    // draft seeded this open, or one written by onCheckpoint below). Gates the
    // in-flow expiry discard so no draft_discarded is minted for an instance
    // that never had a draft.
    var draftPersisted = draftSeed != null;

    // Resuming an unexpired draft: re-assert the session's warning/expiry
    // notifications anchored at the draft's last checkpoint. Idempotent —
    // re-scheduling the same stable per-instance ids replaces any pending
    // pair from the session that wrote the checkpoint.
    // Implements: DIARY-GUI-questionnaire-session-expiry/A+F
    // Implements: DIARY-PRD-questionnaire-session-timeout/E+F
    if (draftSeed != null) {
      unawaited(
        widget.sessionExpiryNotifications?.scheduleSession(
          instanceId: aggregateId,
          questionnaireName: definition.name,
          sessionTimeoutMinutes:
              definition.sessionConfig?.sessionTimeoutMinutes,
          warningMinutes: definition.sessionConfig?.timeoutWarningMinutes,
          lastInteraction: draftSeed.completedAt,
        ),
      );
    }

    // CUR-1522: Suppress the home screen's general recall dialog for this
    // instance while the flow is open. The flow screen owns the recall
    // notification for its open instance via recallSignal + onRecalled.
    // Implements: DIARY-DEV-inbound-event-on-receipt/C
    _instanceOpenInFlow = aggregateId;
    final recallCtrl = StreamController<bool>();
    _recallSignalCtrl = recallCtrl;

    try {
      await Navigator.of(context).push(
        AppPageRoute<void>(
          builder: (context) => QuestionnaireFlowScreen(
            definition: definition,
            instanceId: aggregateId,
            // Prior answers seed the Review Screen (review/edit) or the read-only
            // view; null for a never-submitted instance (fresh flow).
            initialResponses: seed?.prefillResponses,
            isReadOnly: isReadOnly,
            onSubmit: (submission) async {
              try {
                await _recordSurveySubmission(submission: submission);
                // The session ended normally — cancel the pending
                // warning/expiry notifications.
                // Implements: DIARY-GUI-questionnaire-session-expiry/A+F
                unawaited(
                  widget.sessionExpiryNotifications?.cancelSession(aggregateId),
                );
                return const SubmitResult(success: true);
              } catch (e) {
                return SubmitResult(success: false, error: e.toString());
              }
            },
            // CUR-1522: persist a diary-local draft after every answer so
            // progress survives leaving the flow / killing the app. Stays local
            // (a `checkpoint` event, never synced) until the eventual submission.
            // Implements: DIARY-PRD-questionnaire-portal-sent-rules/H
            onCheckpoint: (partial) {
              draftPersisted = true;
              unawaited(_checkpointSurvey(submission: partial));
              // Each checkpoint IS the most recent interaction: re-anchor the
              // session's warning/expiry notifications at it (CUR-1543).
              // Implements: DIARY-GUI-questionnaire-session-expiry/A+F
              // Implements: DIARY-PRD-questionnaire-session-timeout/A+E+F
              unawaited(
                widget.sessionExpiryNotifications?.scheduleSession(
                  instanceId: aggregateId,
                  questionnaireName: definition.name,
                  sessionTimeoutMinutes:
                      definition.sessionConfig?.sessionTimeoutMinutes,
                  warningMinutes:
                      definition.sessionConfig?.timeoutWarningMinutes,
                  lastInteraction: partial.completedAt,
                ),
              );
            },
            // CUR-1543: in-flow expiry (the flow screen was OPEN as the
            // inactivity timer crossed the threshold). The flow has already
            // discarded its in-memory answers and reset to the start; here the
            // host discards the persisted draft exactly like the on-open path
            // above, then presents the same Session Expiry Dialog. `true`
            // (Start Again) reveals the reset flow; `false` (Not Now) makes
            // the flow call onComplete, popping back to the home screen.
            // Implements: DIARY-GUI-questionnaire-session-expiry/B+D+E
            // Implements: DIARY-PRD-questionnaire-session-timeout/C+D
            onSessionExpired: () async {
              if (draftPersisted) {
                draftPersisted = false;
                await _discardExpiredDraft(
                  instanceId: aggregateId,
                  questionnaireType: definition.id,
                );
              }
              // Implements: DIARY-GUI-questionnaire-session-expiry/A+F
              unawaited(
                widget.sessionExpiryNotifications?.cancelSession(aggregateId),
              );
              return _showSessionExpiryDialog();
            },
            // CUR-1523: do NOT remove the task on completion. A submitted task
            // stays in the list (leaving "Needs your attention" via
            // categorization) and is removed only when `/user/tasks` drops it on
            // finalization (task-list/I).
            onComplete: () => Navigator.of(context).pop(),
            onDefer: () => Navigator.of(context).pop(),
            // CUR-1522: per-instance recall signal + host-side ack handler.
            // When the recall view delivers a row for this instance while the
            // flow is open, _maybeShowRecall emits true on recallCtrl; the flow
            // then awaits onRecalled (dialog + ack) and calls onComplete to exit.
            // The home's general subscription is suppressed for this instance via
            // _instanceOpenInFlow so no double-dialog occurs.
            // Implements: DIARY-DEV-inbound-event-on-receipt/C
            recallSignal: recallCtrl.stream,
            onRecalled: () async {
              // Mark handled so that if the tombstone arrives before the flow
              // pops the home subscription doesn't re-prompt.
              _handledRecalls.add(aggregateId);
              await _showRecallDialogAndAck(aggregateId);
            },
          ),
        ),
      );
    } finally {
      // Clear the per-instance suppression and close the signal stream whether
      // the route returns normally or throws. Without this, a thrown route
      // would permanently suppress recalls for this instance and leak the
      // StreamController.
      _instanceOpenInFlow = null;
      _recallSignalCtrl = null;
      unawaited(recallCtrl.close());
    }
  }

  /// Opens the questionnaire for a submitted survey [SurveyEntryView] from a
  /// record (the home "Your Records" today/yesterday list or the Calendar
  /// day-view).
  ///
  /// The open reflects the instance's STATE, not where it was opened from —
  /// exactly as opening it from its Task does: a finalized instance
  /// ([_finalizedInstanceIds]) opens read-only (workflow/S); a submitted but
  /// not-yet-finalized instance opens the editable Review Screen seeded with the
  /// prior answers, re-submittable until finalization (workflow/R + rules/N).
  // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/R+S
  // Implements: DIARY-GUI-participant-task-list/H
  Future<void> _openSurveyRecord(SurveyEntryView survey) async {
    final qTypeString = survey.questionnaireType;
    QuestionnaireType? qType;
    try {
      qType = QuestionnaireType.fromValue(qTypeString);
    } catch (_) {
      qType = null;
    }

    if (qType == null ||
        (qType != QuestionnaireType.noseHht &&
            qType != QuestionnaireType.qol)) {
      // Unsupported type — no flow available; do nothing.
      return;
    }

    // A finalized instance is view-only (workflow/S); a submitted but
    // not-yet-finalized instance opens the editable Review (workflow/R). The
    // live `questionnaire_status` projection is the durable, offline-correct
    // finalize signal — identical to opening from the Task.
    await _openQuestionnaireFlow(
      qType: qType,
      aggregateId: survey.aggregateId,
      isReadOnly: _finalizedInstanceIds.contains(survey.aggregateId),
      submittedSurvey: survey,
    );
  }

  /// The device-local `<id>_survey` [SurveyEntryView] for [aggregateId] whose
  /// answers seed the flow on re-open, or null when none exists. Prefers a
  /// finalized submission (from the canonical view); falls back to an
  /// in-progress `checkpoint` draft (from the diary-local incomplete view) so a
  /// partially-answered questionnaire resumes where the participant left off
  /// (CUR-1522). prefillResponses works for either — a checkpoint carries the
  /// same QuestionnaireSubmissionPayload shape, just incomplete.
  // Implements: DIARY-GUI-participant-task-list/K
  // Implements: DIARY-GUI-questionnaire-session-expiry/G
  SurveyEntryView? _submittedSurveyFor(DiaryView view, String aggregateId) {
    for (final entry in view.entries.whereType<SurveyEntryView>()) {
      if (entry.aggregateId == aggregateId) return entry;
    }
    for (final entry in view.incompleteEntries.whereType<SurveyEntryView>()) {
      if (entry.aggregateId == aggregateId) return entry;
    }
    return null;
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

  /// Finalize a questionnaire through the NATIVE `submit_questionnaire` action,
  /// so the resulting `<id>_survey` / `finalized` event lands in the native
  /// event-sourcing store and ships through the same `DiaryServerDestination`
  /// (→ `POST /api/v1/ingest/batch`) as nosebleed records.
  ///
  /// The action parses a `QuestionnaireSubmissionPayload` (snake_case keys,
  /// `responses` as a `question_id -> {value, display_label, normalized_label}`
  /// MAP). The flow's [QuestionnaireSubmission] carries `responses` as a LIST
  /// and a single `version` string, so this maps both into the payload shape:
  /// the list is keyed by `question_id`, and the single definition version is
  /// stamped onto all three version refs (schema/content/gui), which today come
  /// from the one `QuestionnaireDefinition.version` field
  /// (DIARY-PRD-questionnaire-versioning/J+K+L).
  ///
  /// The cycle label (`study_event`) is deliberately NOT carried on the
  /// finalized survey event: the `QuestionnaireSubmissionPayload` cross-wire
  /// contract (decision 1d / surface D6) is frozen and excludes it. The portal
  /// owns the cycle mapping via its own `questionnaire_assigned` event, keyed by
  /// the same `instance_id` that this event carries — so the cycle is recoverable
  /// without duplicating it here.
  ///
  /// The ALCOA+ audit fact is self-contained: each response carries
  /// `display_label` and `normalized_label` so downstream consumers do not need
  /// to re-derive them from the questionnaire definition at read time.
  // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/N
  // Implements: DIARY-DEV-action-write-path/A
  Future<void> _recordSurveySubmission({
    required QuestionnaireSubmission submission,
  }) async {
    final responses = <String, Object?>{
      for (final r in submission.responses)
        r.questionId: <String, Object?>{
          'value': r.value,
          'display_label': r.displayLabel,
          'normalized_label': r.normalizedLabel,
        },
    };
    await ReActionScope.of(context).actionSubmitter.submit(
      ActionSubmission(
        actionName: 'submit_questionnaire',
        rawInput: <String, Object?>{
          'instance_id': submission.instanceId,
          'questionnaire_type': submission.questionnaireType,
          // One definition version stamped onto all three version refs.
          'schema_version': submission.version,
          'content_version': submission.version,
          'gui_version': submission.version,
          'completed_at': submission.completedAt.toIso8601String(),
          'responses': responses,
        },
      ),
    );
  }

  /// Persists an in-progress questionnaire as a diary-LOCAL `checkpoint`
  /// `<id>_survey` event via the `checkpoint_questionnaire` action, so answers
  /// survive leaving the flow / killing the app and resume on re-open. Mirrors
  /// [_recordSurveySubmission] but emits a `checkpoint` (never synced to the
  /// portal) instead of a `finalized` submission. Dispatched after every answer
  /// via [QuestionnaireFlowScreen.onCheckpoint].
  // Implements: DIARY-PRD-questionnaire-portal-sent-rules/H
  // Implements: DIARY-DEV-action-write-path/A
  Future<void> _checkpointSurvey({
    required QuestionnaireSubmission submission,
  }) async {
    final responses = <String, Object?>{
      for (final r in submission.responses)
        r.questionId: <String, Object?>{
          'value': r.value,
          'display_label': r.displayLabel,
          'normalized_label': r.normalizedLabel,
        },
    };
    await ReActionScope.of(context).actionSubmitter.submit(
      ActionSubmission(
        actionName: 'checkpoint_questionnaire',
        rawInput: <String, Object?>{
          'instance_id': submission.instanceId,
          'questionnaire_type': submission.questionnaireType,
          'schema_version': submission.version,
          'content_version': submission.version,
          'gui_version': submission.version,
          'completed_at': submission.completedAt.toIso8601String(),
          'responses': responses,
        },
      ),
    );
  }

  /// Whether a questionnaire Session anchored at [lastInteraction] (the last
  /// checkpoint's `completedAt`, refreshed on every answer) has reached
  /// Session Expiry per [definition]'s `sessionTimeoutMinutes`.
  ///
  /// Conservative default: a definition without a `sessionConfig` has no
  /// timeout, so its drafts never expire and resume is always allowed
  /// (DIARY-PRD-questionnaire-session-timeout/G).
  // Implements: DIARY-GUI-questionnaire-session-expiry/B+G
  // Implements: DIARY-PRD-questionnaire-session-timeout/A+C+G+H+I
  bool _isSessionExpired(
    QuestionnaireDefinition definition,
    DateTime lastInteraction,
  ) {
    final timeoutMinutes = definition.sessionConfig?.sessionTimeoutMinutes;
    if (timeoutMinutes == null) return false;
    return DateTime.now().difference(lastInteraction) >=
        Duration(minutes: timeoutMinutes);
  }

  /// Discards the diary-local `checkpoint` draft for [instanceId] by
  /// dispatching `discard_questionnaire_draft`, which mints a diary-local
  /// `draft_discarded` event on the `<id>_survey` aggregate — the
  /// `diary_incomplete` projection removes the draft row so it can never be
  /// resumed. Deliberately NOT a `tombstone`: checkpoints never reach the
  /// portal, so their discard must not ship either (see
  /// DiscardQuestionnaireDraftAction).
  // Implements: DIARY-GUI-questionnaire-session-expiry/B
  // Implements: DIARY-PRD-questionnaire-session-timeout/C
  // Implements: DIARY-DEV-action-write-path/A
  Future<void> _discardExpiredDraft({
    required String instanceId,
    required String questionnaireType,
  }) async {
    await ReActionScope.of(context).actionSubmitter.submit(
      ActionSubmission(
        actionName: 'discard_questionnaire_draft',
        rawInput: <String, Object?>{
          'instance_id': instanceId,
          'questionnaire_type': questionnaireType,
          'reason': 'session-expired',
        },
      ),
    );
  }

  /// The Session Expiry Dialog: tells the participant their Session expired
  /// and their previous answers were not saved, offering Start Again (returns
  /// `true` → the caller opens the flow fresh from the Preamble) and Not Now
  /// (returns `false` → the caller leaves the participant on / returns them
  /// to the home screen).
  // Implements: DIARY-GUI-questionnaire-session-expiry/B+C+D+E
  Future<bool> _showSessionExpiryDialog() async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    return AppDialog.confirmation(
      context: context,
      title: l10n.sessionExpiredTitle,
      message: l10n.sessionExpiredMessage,
      confirmLabel: l10n.startAgain,
      cancelLabel: l10n.notNow,
    );
  }

  // An in-progress questionnaire draft is NOT force-surfaced via a modal. Per
  // DIARY-PRD-questionnaire-portal-sent-rules/K the participant may exit a
  // questionnaire freely; the unfinished instance stays an actionable task in
  // the Task List, and re-opening that task resumes the draft (seeded via
  // [_submittedSurveyFor], DIARY-GUI-questionnaire-session-expiry/G). A forced
  // non-dismissible resume modal would contradict the exit-freely rule.

  // Implements: DIARY-DEV-reactive-read-path/A
  // Implements: DIARY-PRD-incomplete-entry-preservation/B
  Future<void> _handleIncompleteRecordsClick(DiaryView view) async {
    final incomplete = view.incompleteEntries
        .whereType<EpistaxisEntryView>()
        .toList();
    if (incomplete.isEmpty) return;

    // Single incomplete record → jump straight to the recording-screen edit
    // path. More than one → open the dedicated list so the participant picks
    // which to resume. Only epistaxis entries are editable today.
    //
    // The diary list refreshes reactively via DiaryViewBuilder, so no manual
    // reload is needed after returning. The recording screen pops its
    // aggregate id (a String) on save, so the route result type must be
    // String?-compatible — a <bool> route throws on pop.
    if (incomplete.length == 1) {
      await Navigator.push<String?>(
        context,
        AppPageRoute(
          builder: (context) => RecordingScreen(existing: incomplete.first),
        ),
      );
      return;
    }

    await Navigator.push<void>(
      context,
      AppPageRoute(
        // Same hamburger menu as Home — home owns the enrollment service,
        // so it supplies the row callbacks (mirrors Profile / Enrollment).
        builder: (context) => IncompleteRecordsScreen(
          onShowProfile: _handleShowProfile,
          onJoinStudy: _isEnrolled ? null : _handleEnrollFromMenu,
          onShowHelpCenter: _handleShowHelpCenter,
        ),
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
    // The screen pops with an OverlapResolutionResult (consumed by the
    // recording-flow caller); the home surface ignores it and re-derives the
    // banner reactively from the next DiaryView emission. The route is typed to
    // match the pop result so popping a non-null result stays type-safe.
    await Navigator.of(context).push(
      AppPageRoute<OverlapResolutionResult>(
        builder: (context) => OverlapCompareScreen(
          leftId: first.preExisting.aggregateId,
          rightId: first.justTouched.aggregateId,
        ),
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

    // Chronological key for a today/yesterday entry: an epistaxis row sorts by
    // its start, a completed survey by its completion time. Other views (day
    // markers) have no time and yield null, which sorts as 0 (stable).
    DateTime? timeOf(DiaryEntryView e) => switch (e) {
      EpistaxisEntryView(:final startTime) => startTime,
      SurveyEntryView(:final completedAt) => completedAt,
      _ => null,
    };

    int byStart(DiaryEntryView a, DiaryEntryView b) {
      final aStart = timeOf(a);
      final bStart = timeOf(b);
      if (aStart == null || bStart == null) return 0;
      return aStart.compareTo(bStart);
    }

    bool isEpistaxisOn(DiaryEntryView e, String dateStr) =>
        e is EpistaxisEntryView && e.localDate == dateStr;

    // The home block is yesterday + today only; everything older (including
    // older incomplete checkpoints, which the incomplete alert still surfaces)
    // is reached through the Calendar.
    final groups = <_GroupedRecords>[];

    // Yesterday's finalized nosebleed entries plus any completed surveys
    // (DIARY-PRD-questionnaire-system/B: a finalized survey surfaces alongside
    // the day's clinical entries) plus any whole-day marker (no-nosebleed /
    // don't-remember). CUR-1491: the marker MUST surface as its own row so a
    // recorded "Don't remember" (or "No nosebleeds") renders its distinct
    // status instead of falling through to the bare "No records" empty state —
    // "nothing recorded" and "acknowledged uncertainty" are different clinical
    // states (cf. DIARY-PRD-day-disposition/A).
    final yesterdayEntries = <DiaryEntryView>[
      ...view.entriesOn(yesterdayStr).whereType<EpistaxisEntryView>(),
      ...view.entriesOn(yesterdayStr).whereType<SurveyEntryView>(),
      ...view.entriesOn(yesterdayStr).whereType<DayMarkerView>(),
    ]..sort(byStart);

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

    // Today's finalized nosebleed entries plus today's completed surveys
    // (DIARY-PRD-questionnaire-system/B) plus today's incomplete checkpoints
    // (CUR-488: in-progress entries surface in the today section).
    final todayEntries = <DiaryEntryView>[
      ...view.entriesOn(todayStr).whereType<EpistaxisEntryView>(),
      ...view.entriesOn(todayStr).whereType<SurveyEntryView>(),
      // CUR-1491: today's whole-day marker surfaces as its own row too (same
      // reasoning as the yesterday group above).
      ...view.entriesOn(todayStr).whereType<DayMarkerView>(),
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

  /// Builds the cache-backed sponsor logo for a render site, or null when no
  /// logo is configured / no cache is wired. The returned [BrandingLogo] reads
  /// the current patient session JWT from the enrollment service, serves the
  /// bytes from the content-addressed cache, and fetches once per content hash.
  // Implements: DIARY-DEV-sponsor-branding-assets/D
  BrandingLogoBuilder? get _brandingLogoBuilder {
    final cache = widget.brandingAssetCache;
    if (cache == null || !widget.sponsorBranding.hasLogo) return null;
    return ({required width, required height, required fallback}) =>
        BrandingLogo(
          branding: widget.sponsorBranding,
          cache: cache,
          jwtProvider: widget.enrollmentService.getJwtToken,
          fallback: fallback,
          width: width,
          height: height,
        );
  }

  @override
  Widget build(BuildContext context) {
    return DiaryViewBuilder(builder: _buildScaffold);
  }

  // Implements: DIARY-DEV-reactive-read-path/A
  Widget _buildScaffold(BuildContext context, DiaryView view) {
    // Only unfinished CLINICAL (epistaxis) records count toward the
    // "incomplete records" reminder. Questionnaire `checkpoint` drafts share the
    // diary_incomplete projection but resume via the Task List, not here — and
    // _handleIncompleteRecordsClick edits epistaxis only, so counting a survey
    // draft would show a reminder whose click does nothing (CUR-1522).
    final incompleteCount = view.incompleteEntries
        .whereType<EpistaxisEntryView>()
        .length;
    final overlapCount = overlapPairs(view).length;
    // Sponsor branding is displayed only while ACTIVELY participating: on
    // not-participating the app stops applying this sponsor-specific rule.
    // Implements: DIARY-PRD-participant-mark-not-participating/D
    // Gate on the live not-participating notifier rather than a re-read of
    // enrollment: that notifier fires from the reconcile BEFORE its
    // clearEnrollment() completes, so re-reading `isEnrolled()` would race and
    // leave stale branding until a page change.
    final brandingActive =
        _isEnrolled && !widget.enrollmentService.notParticipatingNotifier.value;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, brandingActive),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: _buildBody(context, view, incompleteCount, overlapCount),
              ),
            _buildBottomActions(context),
          ],
        ),
      ),
    );
  }

  /// Header row — sponsor logo (left) + hamburger user menu (right). Matches
  /// the Figma Sponsor Portal UI Pack home layout (no centered title). Layout
  /// is delegated to [BrandHeader] so sub-screens that show the same bar can
  /// reuse the structure.
  Widget _buildHeader(BuildContext context, bool brandingActive) {
    return BrandHeader(
      leading: LogoMenu(
        sponsorLogoBuilder: brandingActive ? _brandingLogoBuilder : null,
        onResetAllData: _handleResetAllData,
        resetEnabled: _canResetData,
        isEnrolled: _isEnrolled,
        onEndClinicalTrial: _isEnrolled ? _handleEndClinicalTrial : null,
        onInstructionsAndFeedback: _handleInstructionsAndFeedback,
        showDevTools: AppConfig.showDevTools,
        onOpenServiceMode: widget.serviceModeContextBuilder == null
            ? null
            : _openServiceMode,
      ),
      trailing: UserMenuButton(
        onShowProfile: _handleShowProfile,
        onJoinStudy: _isEnrolled ? null : _handleEnrollFromMenu,
        onShowHelpCenter: _handleShowHelpCenter,
      ),
    );
  }

  // CUR-1493: the home user-menu Help Center is not built yet — show the
  // generic "Coming soon" notice, not the unrelated "Privacy settings coming
  // soon" toast.
  void _handleShowHelpCenter() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).comingSoon),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleEnrollFromMenu() async {
    final wasEnrolled = _isEnrolled;
    await Navigator.push(
      context,
      AppPageRoute<void>(
        builder: (context) => ClinicalTrialEnrollmentScreen(
          enrollmentService: widget.enrollmentService,
          // Pop enrollment first, then open profile — home owns the route
          // and has the cached enrollment / disconnection state profile needs.
          onShowProfile: () {
            Navigator.of(context).pop();
            _handleShowProfile();
          },
        ),
      ),
    );
    await _checkEnrollmentStatus();
    if (_isEnrolled) widget.onEnrolled?.call();
    await _checkDisconnectionStatus();
    // CUR-1114: Open profile only if enrollment state changed.
    if (!wasEnrolled && _isEnrolled && mounted) {
      await _handleShowProfile();
    }
  }

  /// Scrollable body — banners, Task List section (expansion tile), and the
  /// "Your Records" day-card stack. Pull-to-refresh re-syncs tasks so the
  /// patient has a manual recovery path when FCM is slow (CUR-1398).
  Widget _buildBody(
    BuildContext context,
    DiaryView view,
    int incompleteCount,
    int overlapCount,
  ) {
    final groups = _groupRecordsByDay(context, view);
    // Default to the most recent events: jump the Today card's internal list
    // to the bottom once after the first laid-out frame.
    if (!_didScrollEventsToBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didScrollEventsToBottom) return;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          _didScrollEventsToBottom = true;
        }
      });
    }

    // Fixed page layout (no top-level scroll). Banners, the Task List
    // section, and the "Your Records" header sit at their natural heights;
    // the two day cards split the remaining vertical space via `Expanded`
    // and scroll their own entry list when the entries exceed that share.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._buildTopBanners(context),
          // Implements: DIARY-GUI-main-screen-layout/A.
          // Capped to ~38% of the available height so a busy "Needs your
          // attention" tile (many alerts/tasks) can't starve the events
          // area below — its inner scroll handles the overflow.
          ListenableBuilder(
            listenable: widget.taskService,
            builder: (context, _) => _buildTaskListSection(
              context,
              view,
              incompleteCount,
              overlapCount,
            ),
          ),
          const SizedBox(height: 16),
          AppSectionHeader(title: AppLocalizations.of(context).yourRecords),
          const SizedBox(height: 12),
          // Events area: Yesterday grows with its content up to half of the
          // available height (capped via a ConstrainedBox so its inner list
          // starts scrolling once it would exceed that share); Today claims
          // whatever Yesterday leaves behind via [Expanded]. Both still hug
          // their content when empty.
          // Events area. Yesterday hugs its content up to a hard cap at
          // half the available height (see the [ConstrainedBox] inside
          // [_dayCardSlot]); Today claims the remaining vertical space via
          // [Expanded] regardless of Yesterday's size.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final yesterdayMaxHeight = (constraints.maxHeight - 12) / 2;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < groups.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _dayCardSlot(
                        context,
                        view,
                        groups[i],
                        isToday: i == groups.length - 1,
                        yesterdayMaxHeight: yesterdayMaxHeight,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Inline banners that appear above the Task List section: disconnection
  /// (preserves the expand-to-show-contact behaviour via DisconnectionBanner),
  /// not-participating notice, and the sync-wedged warning.
  // Implements: DIARY-PRD-notification-disconnection
  List<Widget> _buildTopBanners(BuildContext context) {
    final banners = <Widget>[];
    // Disconnection (red, persistent, non-dismissible).
    if (_isDisconnected) {
      banners.add(
        DisconnectionBanner(
          siteName: _siteName,
          sitePhoneNumber: _sitePhoneNumber,
        ),
      );
    }
    // Not-participating: gentle informational notice. Mutually exclusive with
    // disconnection (latest lifecycle event).
    // Implements: DIARY-BASE-not-participating-notice/A+C
    if (widget.enrollmentService.notParticipatingNotifier.value) {
      banners.add(
        AppBanner(
          severity: AppBannerSeverity.info,
          message: _notParticipatingMessage(context),
        ),
      );
    }
    // Sync wedged — destination FIFO is wedged on an unknown event-type bridge.
    if (_hasWedgedFifo) {
      banners.add(
        // TODO(i18n): localize.
        const AppBanner(
          severity: AppBannerSeverity.error,
          title: 'Some data is not syncing',
          message: 'Please update the app.',
        ),
      );
    }
    return [
      for (final b in banners) ...[b, const SizedBox(height: 12)],
    ];
  }

  /// "Task List" section header + the "Needs your attention" expansion tile.
  ///
  /// All actionable items — incomplete records, unresolved overlaps, and
  /// outstanding tasks (questionnaires, reminders) — render as
  /// [AppAlertRow]s inside the tile. Tasks are hidden while disconnected
  /// (CUR-1164: no valid questionnaires until reconnection).
  ///
  /// When there is nothing requiring attention (count == 0) the whole
  /// section — heading and tile — collapses to nothing rather than showing
  /// an empty "Needs your attention (0)" tile (CUR-1519).
  // Implements: DIARY-GUI-main-screen-layout/A — the Task List zone renders
  //   only when tasks are active; with zero items the zone is absent.
  Widget _buildTaskListSection(
    BuildContext context,
    DiaryView view,
    int incompleteCount,
    int overlapCount,
  ) {
    final l10n = AppLocalizations.of(context);
    // A recalled questionnaire is surfaced to the participant via the recall
    // dialog (or silently acknowledged when never delivered) — it is NOT an
    // actionable task. Exclude status:recalled from the Task List so it never
    // renders as a tappable "Needs your attention" item during the window
    // before the device acknowledges, the portal self-cleans, and the next
    // /user/tasks poll drops it.
    // Implements: DIARY-DEV-inbound-event-on-receipt/C
    final tasks = _isDisconnected
        ? const <Task>[]
        : widget.taskService.tasks
              .where((t) => t.status != 'recalled')
              .toList();

    // CUR-1523: categorize questionnaire tasks by lifecycle:
    //
    //  FINALIZED (task-list/I): Portal has finalized the submission. The task
    //    MUST be removed from the Task List entirely (neither attention nor
    //    completed row). Read-only access lives on the survey RECORD in "Your
    //    Records" / Calendar day-view. Finalized is detected via EITHER the
    //    durable on-device `questionnaire_status` projection
    //    ([_finalizedInstanceIds]) OR the freshly-synced portal status on the
    //    task (task.status == 'finalized') — whichever signal arrives first.
    //
    //  SUBMITTED but NOT finalized (task-list/J): A device-local
    //    `<id>_survey` row exists for this instance. The task STAYS in the list
    //    as a completed-state row ("— submitted"), giving the participant access
    //    to review/edit until the portal finalizes it.
    //
    //  PENDING (actionable): Neither submitted nor finalized. Surfaces in
    //    "Needs your attention".
    final submittedInstanceIds = view.entries
        .whereType<SurveyEntryView>()
        .map((s) => s.aggregateId)
        .toSet();
    // Implements: DIARY-GUI-participant-task-list/I
    bool isFinalizedQuestionnaire(Task t) =>
        _finalizedInstanceIds.contains(t.targetId ?? t.id) ||
        t.status == 'finalized';
    // Submitted (has local survey row) AND not yet finalized — the "awaiting
    // review" completed-state category (task-list/J).
    // Implements: DIARY-GUI-participant-task-list/J
    bool isSubmittedNotFinalizedQuestionnaire(Task t) =>
        t.taskType == TaskType.questionnaire &&
        submittedInstanceIds.contains(t.id) &&
        !isFinalizedQuestionnaire(t);

    // Actionable items in the "Needs your attention" tile: alerts + tasks that
    // are neither submitted nor finalized. Submitted and finalized questionnaire
    // tasks are both excluded here (CUR-1519).
    final attentionRows = <Widget>[
      if (incompleteCount > 0)
        AppAlertRow.incompleteRecord(
          count: incompleteCount,
          onTap: () => _handleIncompleteRecordsClick(view),
        ),
      if (overlapCount > 0)
        AppAlertRow(
          tone: AppAlertRowTone.warning,
          icon: Icons.merge_type,
          // TODO(i18n): localize + pluralize.
          label: overlapCount == 1
              ? '1 overlapping record needs resolving'
              : '$overlapCount overlapping records need resolving',
          onTap: () => _handleResolveOverlaps(view),
        ),
      for (final task in tasks)
        if (task.taskType != TaskType.questionnaire ||
            (!isSubmittedNotFinalizedQuestionnaire(task) &&
                !isFinalizedQuestionnaire(task)))
          AppAlertRow(
            tone: _toneForTaskType(task.taskType),
            icon: _iconForTaskType(task.taskType),
            label: task.title,
            onTap: () => _navigateToQuestionnaire(task, view),
          ),
    ];

    // Completed (submitted, awaiting portal review) questionnaire tasks — a
    // distinct success-tone row outside the attention tile, selectable so the
    // participant can review/edit (task-list/K).
    // FINALIZED tasks are NOT rendered here — they are removed from the Task
    // List entirely (task-list/I); read-only access is via the survey record.
    // Implements: DIARY-GUI-participant-task-list/I+J
    final completedRows = <Widget>[
      for (final task in tasks)
        if (isSubmittedNotFinalizedQuestionnaire(task))
          AppAlertRow(
            key: Key('completed-task-${task.id}'),
            tone: AppAlertRowTone.success,
            icon: Icons.check_circle_outline,
            // TODO(i18n): localize.
            label: '${task.title} — submitted',
            onTap: () => _navigateToQuestionnaire(task, view),
          ),
    ];

    final attentionCount = attentionRows.length;
    // Nothing to surface at all (no attention items AND no completed tasks):
    // hide the entire section rather than showing an empty tile (CUR-1519).
    if (attentionCount == 0 && completedRows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(title: l10n.taskList),
        const SizedBox(height: 12),
        // The "Needs your attention" tile renders only when there is at least
        // one actionable item; with only completed tasks left it is absent so
        // it never shows a "(0)" count (CUR-1519).
        if (attentionCount > 0) ...[
          AppExpansionTile(
            title: l10n.needsYourAttention,
            count: attentionCount,
            initiallyExpanded: true,
            children: attentionRows,
          ),
          if (completedRows.isNotEmpty) const SizedBox(height: 12),
        ],
        ...completedRows,
      ],
    );
  }

  /// Bottom action area — primary "Record Nosebleed" + tertiary "View
  /// Calendar". Pinned outside the scrollable so they're always reachable.
  Widget _buildBottomActions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            variant: AppButtonVariant.destructive,
            size: AppButtonSize.large,
            label: l10n.recordNosebleed,
            leadingIcon: Icons.add,
            fullWidth: true,
            onPressed: _navigateToRecording,
          ),
          const SizedBox(height: 8),
          AppButton(
            variant: AppButtonVariant.tertiary,
            size: AppButtonSize.large,
            label: l10n.viewCalendar,
            fullWidth: true,
            leadingIcon: Icons.calendar_today_outlined,
            onPressed: () async {
              // CUR-1494: bound calendar back-navigation to 365 days before
              // the diary's start day (DIARY-PRD-diary-start-day/D). The start
              // day is the native DiaryServerDestination's start date — the
              // trial-start watermark stamped once the portal reports Trial
              // Start; null until then (and on a lookup failure), which the
              // calendar treats as a now-relative floor.
              DateTime? installDate;
              try {
                final schedule = await widget.diaryScope.bundle.destinations
                    .scheduleOf(DiaryServerDestination.destinationId);
                installDate = schedule.startDate;
              } catch (_) {
                installDate = null;
              }
              if (!context.mounted) return;
              await showDialog<void>(
                context: context,
                builder: (context) => CalendarScreen(
                  installDate: installDate,
                  onOpenSurvey: _openSurveyRecord,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---- Task → alert-row helpers ---------------------------------------------

  AppAlertRowTone _toneForTaskType(TaskType type) {
    switch (type) {
      case TaskType.questionnaire:
        return AppAlertRowTone.primary;
      case TaskType.incompleteRecord:
      case TaskType.yesterdayReminder:
        return AppAlertRowTone.warning;
      case TaskType.missingDays:
        return AppAlertRowTone.primary;
    }
  }

  IconData _iconForTaskType(TaskType type) {
    switch (type) {
      case TaskType.questionnaire:
        return Icons.assignment_turned_in_outlined;
      case TaskType.incompleteRecord:
        return Icons.info_outlined;
      case TaskType.yesterdayReminder:
        return Icons.today_outlined;
      case TaskType.missingDays:
        return Icons.calendar_today_outlined;
    }
  }

  /// Resolved not-participating notice text: sponsor-configured value if set,
  /// else the diary's localized default.
  // Implements: DIARY-BASE-not-participating-notice/B
  String _notParticipatingMessage(BuildContext context) =>
      SponsorUiConfigScope.of(context).notParticipatingMessage ??
      AppLocalizations.of(context).leftClinicalTrial;

  /// Slot wrapper for a day card.
  ///
  /// - **Empty (Yesterday or Today)** → hugs its placeholder so the
  ///   sibling can stretch into the leftover space.
  /// - **Yesterday populated** → wrapped in [ConstrainedBox] capped at
  ///   [yesterdayMaxHeight] (≈ half the events area). Hugs content while
  ///   under the cap; scrolls internally once entries would exceed it.
  /// - **Today populated** → wrapped in [Flexible(loose)] so it hugs its
  ///   own content but can grow up to whatever vertical space Yesterday
  ///   leaves behind. With 1 entry it stays ~one row tall; with many
  ///   entries it grows until it fills the remaining space, then scrolls.
  ///
  /// Today owns the live [_scrollController] (jump-to-bottom + flash) and
  /// [RefreshIndicator] re-syncing /tasks.
  Widget _dayCardSlot(
    BuildContext context,
    DiaryView view,
    _GroupedRecords group, {
    required bool isToday,
    required double yesterdayMaxHeight,
  }) {
    final isEmpty = group.entries.isEmpty;
    if (isEmpty) {
      return _buildDayCard(context, view, group, sizeToContent: true);
    }
    if (isToday) {
      final card = _buildDayCard(
        context,
        view,
        group,
        scrollController: _scrollController,
        refreshOnPull: true,
        sizeToContent: true,
      );
      // Flexible(loose) with the only flex sibling in the column gets the
      // full remaining space as its `maxHeight`; the inner shrink-wrap
      // ListView hugs content up to that max and scrolls past it.
      return Flexible(fit: FlexFit.loose, child: card);
    }
    final card = _buildDayCard(context, view, group, sizeToContent: true);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: yesterdayMaxHeight),
      child: card,
    );
  }

  /// A single day-group card — "Yesterday | Thursday, May 21, 2026" header
  /// followed by either entries, the yesterday-confirmation prompt, or a
  /// muted "no records" empty row.
  ///
  /// [sizeToContent] true → the card hugs its body (used for empty groups
  /// so the sibling card can claim the rest of the column). False → the
  /// card fills its parent's vertical share via the inner [Expanded] and
  /// the entry list scrolls internally on overflow.
  // Implements: DIARY-DEV-reactive-read-path/A
  Widget _buildDayCard(
    BuildContext context,
    DiaryView view,
    _GroupedRecords group, {
    ScrollController? scrollController,
    bool refreshOnPull = false,
    bool sizeToContent = false,
  }) {
    final theme = Theme.of(context);
    final prefs = AppPreferencesScope.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    final header = group.date == null
        ? null
        : Row(
            children: [
              Text(
                group.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '|',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DateFormat('EEEE, MMMM d, y', locale).format(group.date!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    Widget body;
    if (group.entries.isEmpty) {
      // Empty cards hug their content — no Align/expansion, so the card
      // shrinks to the height of the "No records" pill or the yesterday
      // confirmation prompt.
      body = _emptyGroupContent(context, group);
    } else {
      body = ListView.builder(
        controller: scrollController,
        // shrinkWrap when the card is sized to its content (under a
        // [ConstrainedBox] cap); fill the bound when the card takes the
        // rest of the events column (under [Expanded]) so the list
        // occupies the full available height with empty space inside if
        // entries don't fill it.
        shrinkWrap: sizeToContent,
        // Always scrollable so the RefreshIndicator gesture works even when
        // the list is shorter than its container.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: group.entries.length,
        itemBuilder: (context, i) {
          final entry = group.entries[i];
          return Padding(
            // CUR-489: GlobalKey for the flash-to-newest-record affordance.
            key: _getKeyForRecord(entry.aggregateId),
            padding: const EdgeInsets.only(bottom: 8),
            // CUR-464: FlashHighlight animates newly-recorded entries.
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
                // Epistaxis taps edit. CUR-1491: day markers in the home
                // yesterday/today list are display-only — a recorded
                // "Don't remember" / "No nosebleeds" status is not a tappable
                // affordance (re-disposition stays available from the
                // calendar's date-records screen).
                // Implements: DIARY-GUI-participant-task-list/H
                onTap: switch (entry) {
                  EpistaxisEntryView() => () => _navigateToEditRecord(entry),
                  DayMarkerView() => null,
                  SurveyEntryView() => () => _openSurveyRecord(entry),
                },
                hasOverlap:
                    entry is EpistaxisEntryView && _hasOverlap(view, entry),
                highlightColor: highlightColor,
              ),
            ),
          );
        },
      );
      if (refreshOnPull) {
        body = RefreshIndicator(
          onRefresh: () =>
              widget.taskService.syncTasks(widget.enrollmentService),
          child: body,
        );
      }
    }

    // [sizeToContent] picks how the card sizes itself:
    // - true: Column(min) hugs to content, body wrapped in
    //   `Flexible(loose)` so the parent ConstrainedBox cap reaches the
    //   ListView and it scrolls once entries would exceed the cap.
    // - false: Column(max) fills its parent (typically [Expanded]) and
    //   body is wrapped in `Expanded` so the non-shrinkwrap ListView is
    //   bounded by the card's height and scrolls when entries overflow.
    final isEmpty = group.entries.isEmpty;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: sizeToContent ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (header != null) ...[header, const SizedBox(height: 12)],
          if (isEmpty)
            body
          else if (sizeToContent)
            // Flexible(loose) forwards the parent ConstrainedBox's
            // maxHeight to the shrink-wrap ListView so the cap reaches it
            // and the list scrolls once entries would exceed the cap.
            Flexible(fit: FlexFit.loose, child: body)
          else
            // Card fills its [Expanded] slot; the ListView (no shrinkWrap)
            // needs Expanded to bound its height so it scrolls on overflow.
            Expanded(child: body),
        ],
      ),
    );
  }

  /// Empty-state content for a day group. The Yesterday section, when not
  /// locked, shows the No/Had/Don't-remember confirmation prompt instead of a
  /// bare empty state. Implements: DIARY-PRD-day-disposition/B
  Widget _emptyGroupContent(BuildContext context, _GroupedRecords group) {
    if (group.isYesterday && group.isEmpty) {
      // Defense-in-depth for the day-level lock: the prompt's quick actions
      // write markers / open recording for yesterday directly, so suppress it
      // when yesterday is past the lock threshold.
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
    return EventListItem.empty(AppLocalizations.of(context).noRecords);
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
