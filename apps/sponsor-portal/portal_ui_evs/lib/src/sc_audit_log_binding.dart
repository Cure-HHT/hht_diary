import 'dart:async';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:http/http.dart' as http;
import 'package:portal_screens/portal_screens.dart';
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'audit_format.dart';
import 'questionnaire_types.dart';
import 'site_visibility.dart';

/// Reactive wrapper for the Study Coordinator Audit Log View — the "Audit Log"
/// nav section when the active role is Study Coordinator. Fetches the
/// Coordinator's OWN participant/questionnaire activity from
/// `GET /audit?view=mine` (`view=mine` scopes to the caller's own actions
/// server-side, excluding automation/system events) and hands the whole
/// (own-actions, bounded) set to [ScAuditLogScreen], which filters
/// (Participant-ID search) and paginates locally.
///
/// Self-gates on `portal.audit.view` (the Coordinator holds it).
//
// Implements: DIARY-GUI-audit-log-study-coordinator/A+B
class ScAuditLogBinding extends StatefulWidget {
  const ScAuditLogBinding({
    super.key,
    required this.identityCredential,
    required this.serverUrl,
    this.httpClient,
  });

  /// Bare identity credential; the active-role claim is appended at fetch time.
  final String identityCredential;

  /// Portal server base URL, resolved at runtime by the app shell.
  final String serverUrl;

  /// Injection point for tests; production uses a real client.
  final http.Client? httpClient;

  /// Global audit permission gating this view.
  static const String viewAuditPermission = 'portal.audit.view';

  @override
  State<ScAuditLogBinding> createState() => _ScAuditLogBindingState();
}

class _ScAuditLogBindingState extends State<ScAuditLogBinding> {
  bool _started = false;
  bool _loading = false;
  String? _error;
  List<AuditEntryView> _entries = const <AuditEntryView>[];

  /// The viewer's effective authorization — the source of the site-scope
  /// assignments that narrow the "My Sites" strip to the Coordinator's sites.
  StreamSubscription<EffectiveAuthorization?>? _authSub;
  EffectiveAuthorization? _auth;

  http.Client? _ownedClient;
  http.Client get _http =>
      widget.httpClient ?? (_ownedClient ??= http.Client());

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    _ownedClient?.close();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_authSub == null) {
      final scope = ReActionScope.of(context);
      _auth = scope.permissionSource.current;
      _authSub = scope.permissionSource.stream.listen((auth) {
        if (!mounted) return;
        setState(() => _auth = auth);
      });
    }
    if (!_started) {
      _started = true;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = ReActionScope.of(context).authSession.current;
      if (status is! Authenticated || status.principal is! UserPrincipal) {
        if (!mounted) return;
        setState(() {
          _error = 'Not authenticated.';
          _loading = false;
        });
        return;
      }
      final p = status.principal as UserPrincipal;
      final cred = '${widget.identityCredential}|${p.activeRole}';
      // Fetch the whole (own-actions, bounded) set; the screen paginates
      // locally.
      final uri = Uri.parse('${widget.serverUrl}/audit').replace(
        queryParameters: <String, String>{
          'limit': '1000',
          'offset': '0',
          // The Coordinator's own actions only — excludes automation/system.
          'view': 'mine',
        },
      );
      final resp = await _http.get(
        uri,
        headers: <String, String>{'Authorization': 'Bearer $cred'},
      );
      if (!mounted) return;
      if (resp.statusCode != 200) {
        setState(() {
          _error = 'HTTP ${resp.statusCode}';
          _loading = false;
        });
        return;
      }
      final page = parseAuditPage(resp.body);
      setState(() {
        // Defensive client filter: only human-user–initiated rows render.
        // `view=mine` already excludes automation server-side; this guarantees
        // no system/automation row ever surfaces even if the server scope
        // widens. A row is included only when its `initiator` is a Map whose
        // `kind` is 'user' (a missing/non-Map/non-user initiator is skipped).
        // Implements: DIARY-GUI-audit-log-study-coordinator/A
        _entries = <AuditEntryView>[
          for (final row in page.rows)
            if (_isUserInitiated(row)) _toEntryView(row),
        ];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PermissionGate(
    permission: ScAuditLogBinding.viewAuditPermission,
    fallback: const Center(
      child: Text("You don't have permission to view the audit log."),
    ),
    // My Sites strip: separately gated on portal.site.view (like the
    // Participants screen). A viewer without it still gets the audit table,
    // just no My Sites bar.
    // Implements: DIARY-GUI-audit-log-study-coordinator/A
    child: PermissionGate(
      permission: _viewSitePermission,
      fallback: _screen(const <String>[]),
      child: ViewBuilder<SiteRowView>(
        viewName: 'sites_index',
        mapper: _siteFromRow,
        aggregateIdOf: (s) => s.id,
        builder: (context, siteState) {
          final sites = switch (siteState) {
            Loading<SiteRowView>() => const <SiteRowView>[],
            Ready<SiteRowView>(:final rows) => rows,
            Stale<SiteRowView>(:final lastRows) => lastRows,
          };
          // Narrow to the Coordinator's assigned sites (same rule as the
          // Sites page), formatted "001 - Memorial Hospital".
          final mySites = visibleSiteRows(
            sites: sites,
            scopeAssignments: _auth?.scopeAssignments ?? const [],
          );
          final chips = <String>[
            for (final s in [
              ...mySites,
            ]..sort((a, b) => a.number.compareTo(b.number)))
              '${s.number} - ${s.name}',
          ];
          return _screen(chips);
        },
      ),
    ),
  );

  Widget _screen(List<String> siteChips) => ScAuditLogScreen(
    entries: _entries,
    isLoading: _loading,
    errorMessage: _error,
    onRefresh: _fetch,
    siteChips: siteChips,
  );
}

/// Permission gating the "My Sites" strip (the Coordinator's assigned sites).
const String _viewSitePermission = 'portal.site.view';

/// True when the row was initiated by a human user (its `initiator` is a Map
/// whose `kind` is 'user'). Automation/system/anonymous rows return false.
bool _isUserInitiated(Map<String, Object?> row) {
  final initiator = row['initiator'];
  return initiator is Map && initiator['kind'] == 'user';
}

/// Maps a raw `sites_index` row to a [SiteRowView] (mirrors the Participants
/// binding's site mapper).
SiteRowView _siteFromRow(Map<String, Object?> r) => SiteRowView(
  id: (r['site_id'] as String?) ?? '?',
  name: (r['site_name'] as String?) ?? '?',
  number: (r['site_number'] as String?) ?? '?',
  active: (r['is_active'] as bool?) ?? true,
);

/// Maps a raw `/audit` row to the screen's [AuditEntryView].
AuditEntryView _toEntryView(Map<String, Object?> row) {
  final tsString = row['timestamp']?.toString() ?? '';
  final timestamp = DateTime.tryParse(tsString)?.toUtc() ?? DateTime.utc(1970);
  final initiator = row['initiator'];
  final initiatorMap = initiator is Map
      ? initiator.cast<String, Object?>()
      : null;
  final actorName = auditActorName(initiatorMap);
  final actorEmail = auditActorEmail(initiatorMap);
  final actorRole = actorName.isEmpty
      ? ''
      : (row['actor_role']?.toString() ?? '');
  return AuditEntryView(
    id: (row['event_id'] as String?) ?? (row['aggregateId'] as String?) ?? '?',
    timestamp: timestamp,
    actorName: actorName,
    actorRole: actorRole,
    actorEmail: actorEmail,
    // Questionnaire rows get a readable, type-named label; everything else
    // uses the shared humanizer.
    activityLabel: row['aggregate_type'] == 'questionnaire_instance'
        ? questionnaireActivityLabel(row)
        : auditActivityLabel(row),
    // Participant ID column; empty for rows with no participant association.
    // Implements: DIARY-GUI-audit-log-study-coordinator/A
    participantId: auditParticipantId(row),
    raw: row,
  );
}

/// Readable Action-column label for a questionnaire event, e.g.
/// "HHT-QoL questionnaire sent" or "NOSE HHT questionnaire approved — End of
/// Treatment". The type display name comes from the UI questionnaire catalog
/// ([kEnabledQuestionnaireTypes]); the verb from the entry type; the terminal
/// milestone from the finalize event's `end_event`.
// Implements: DIARY-GUI-audit-log-study-coordinator/A
String questionnaireActivityLabel(Map<String, Object?> row) {
  final code = row['questionnaire_type'] as String?;
  final display = _questionnaireDisplayName(code);
  final prefix = display.isEmpty ? 'Questionnaire' : '$display questionnaire';
  final entryType = (row['entry_type'] as String?) ?? '';
  final data = row['data'];
  final endEvent = data is Map ? data['end_event'] as String? : null;
  return switch (entryType) {
    'questionnaire_assigned' => '$prefix sent',
    'questionnaire_called_back' => '$prefix called back',
    'questionnaire_unlocked' => '$prefix unlocked',
    'questionnaire_submission_received' => '$prefix submitted',
    // CUR-1539: 'questionnaire_finalized' is the frozen legacy alias of
    // 'questionnaire_locked' (audit rows from pre-rename event logs).
    'questionnaire_locked' || 'questionnaire_finalized' => switch (endEvent) {
      'end_of_treatment' => '$prefix approved — End of Treatment',
      'end_of_study' => '$prefix approved — End of Study',
      _ => '$prefix approved',
    },
    _ => auditActivityLabel(row),
  };
}

/// Maps a questionnaire type code ("qol", "nose_hht") to its display name via
/// the UI catalog; falls back to a humanized form of the code.
String _questionnaireDisplayName(String? code) {
  if (code == null || code.isEmpty) return '';
  for (final t in kEnabledQuestionnaireTypes) {
    if (t.id == code) return t.displayName;
  }
  return code.replaceAll('_', ' ').toUpperCase();
}
